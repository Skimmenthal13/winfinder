import SwiftUI
import AppKit
import CoreServices

// MARK: - FileItem

struct FileItem: Identifiable {
    var id: URL { url }   // stable across reloads — same file = same id
    let url: URL
    let name: String
    let modificationDate: Date
    let size: Int64
    let isDirectory: Bool
    var relativePath: String? = nil   // set during recursive search; nil = direct child

    var displayName: String { name.replacingOccurrences(of: ":", with: "/") }

    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }

    var sizeFormatted: String {
        guard !isDirectory else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - Custom action model

enum WFActionContext: String {
    case file, folder, background
}

struct WFAction {
    let name: String
    let icon: NSImage?
    let extensions: [String]
    let contexts: Set<WFActionContext>
    let content: WFActionContent

    func matches(ext: String, context: WFActionContext) -> Bool {
        guard contexts.contains(context) else { return false }
        return extensions.contains("*") || extensions.contains(ext.lowercased())
    }

    func matchesContext(_ context: WFActionContext) -> Bool {
        contexts.contains(context)
    }
}

indirect enum WFActionContent {
    case command(String)
    case submenu([WFMenuItem])
}

indirect enum WFMenuItem {
    case action(name: String, icon: NSImage?, content: WFActionContent)
    case separator
}

struct WFActionEntryInfo: Identifiable {
    let id = UUID()
    let displayName: String
    let icon: NSImage?
    let url: URL
    let isFolder: Bool
    let isEnabled: Bool
}

extension WFAction {
    static func loadAll(from dir: URL) -> [WFAction] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        var sources: [(jsonURL: URL, siblingIconURL: URL?)] = []

        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                guard !entry.lastPathComponent.hasSuffix(".disabled") else { continue }
                let jsonURL = entry.appendingPathComponent("action.json")
                guard FileManager.default.fileExists(atPath: jsonURL.path) else { continue }
                let iconURL = entry.appendingPathComponent("icon.png")
                let sibling = FileManager.default.fileExists(atPath: iconURL.path) ? iconURL : nil
                sources.append((jsonURL, sibling))
            } else if entry.pathExtension.lowercased() == "json" {
                sources.append((entry, nil))
            }
        }

        return sources.compactMap { parse(from: $0.jsonURL, siblingIconURL: $0.siblingIconURL) }
    }

    private static func parse(from url: URL, siblingIconURL: URL? = nil) -> WFAction? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String,
              let exts = json["extensions"] as? [String] else { return nil }

        let ico = icon(from: json["icon"] as? String)
            ?? siblingIconURL.flatMap { url in NSImage(contentsOf: url).map { resize($0) } }

        let contexts: Set<WFActionContext>
        if let ctxArr = json["context"] as? [String] {
            contexts = Set(ctxArr.compactMap { WFActionContext(rawValue: $0) })
        } else {
            contexts = [.file, .folder]
        }
        if let cmd = json["command"] as? String {
            return WFAction(name: name, icon: ico, extensions: exts,
                            contexts: contexts, content: .command(cmd))
        }
        if let sub = json["submenu"] as? [[String: Any]] {
            return WFAction(name: name, icon: ico, extensions: exts,
                            contexts: contexts, content: .submenu(parseMenuItems(sub)))
        }
        return nil
    }

    static func parseMenuItems(_ raw: [[String: Any]]) -> [WFMenuItem] {
        raw.compactMap { item in
            if item["separator"] as? Bool == true { return .separator }
            guard let name = item["name"] as? String else { return nil }
            let ico = icon(from: item["icon"] as? String)
            if let cmd = item["command"] as? String {
                return .action(name: name, icon: ico, content: .command(cmd))
            }
            if let sub = item["submenu"] as? [[String: Any]] {
                return .action(name: name, icon: ico, content: .submenu(parseMenuItems(sub)))
            }
            return nil
        }
    }

    private static func resize(_ image: NSImage, to size: NSSize = NSSize(width: 16, height: 16)) -> NSImage {
        guard image.size.width > 0, image.size.height > 0 else { return image }
        let result = NSImage(size: size)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy, fraction: 1.0)
        result.unlockFocus()
        return result
    }

    private static func icon(from path: String?) -> NSImage? {
        guard let p = path, FileManager.default.fileExists(atPath: p) else { return nil }
        guard let img = NSImage(contentsOfFile: p) else { return nil }
        return resize(img)
    }
}

// MARK: - SearchCancelToken

private final class SearchCancelToken {
    private(set) var isCancelled = false
    func cancel() { isCancelled = true }
}

// MARK: - FileExplorerModel

@Observable
final class FileExplorerModel {
    var currentPath: String
    var searchText = "" { didSet { scheduleSearch() } }
    var items: [FileItem] = []
    var searchResults: [FileItem] = []
    var isSearching = false
    var selection: Set<URL> = []
    var pendingSelectURL: URL? = nil
    var recentPaths: [String] = []
    var mountedVolumes: [URL] = []
    var customActions: [WFAction] = []

    private let fm = FileManager.default
    private let recentsKey = "winfinder.recentPaths"
    @ObservationIgnored private var volumeObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var cutURLs: Set<URL> = []
    @ObservationIgnored private var eventStream: FSEventStreamRef?
    @ObservationIgnored private var searchToken = SearchCancelToken()
    @ObservationIgnored private let searchQueue =
        DispatchQueue(label: "winfinder.search", qos: .userInitiated)

    init(startPath: String = FileManager.default.homeDirectoryForCurrentUser.path) {
        currentPath = startPath
        recentPaths = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
        loadVolumes()
        reload()
        startWatching(currentPath)
        setupVolumeObservers()
        loadCustomActions()
    }

    deinit {
        stopWatching()
        volumeObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    // MARK: - Directory

    func reload() {
        let url = URL(fileURLWithPath: currentPath)
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            items = []
            return
        }
        items = contents.compactMap { fileURL -> FileItem? in
            guard let rv = try? fileURL.resourceValues(forKeys: [
                .contentModificationDateKey, .fileSizeKey, .isDirectoryKey
            ]) else { return nil }
            return FileItem(
                url: fileURL,
                name: fileURL.lastPathComponent,
                modificationDate: rv.contentModificationDate ?? .distantPast,
                size: Int64(rv.fileSize ?? 0),
                isDirectory: rv.isDirectory ?? false
            )
        }.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var displayed: [FileItem] {
        let pattern = searchText.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty else { return items }
        if pattern.count < 2 {
            return items.filter { matchesSearch($0.name, pattern: pattern) }
        }
        return searchResults
    }

    private func scheduleSearch() {
        let pattern = searchText.trimmingCharacters(in: .whitespaces)
        searchToken.cancel()

        guard !pattern.isEmpty, pattern.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        let token = SearchCancelToken()
        searchToken = token
        isSearching = true
        searchResults = []
        let basePath = currentPath

        searchQueue.async { [weak self] in
            guard let self else { return }
            let results = self.performRecursiveSearch(
                pattern: pattern,
                basePath: basePath,
                isCancelled: { token.isCancelled }
            )
            DispatchQueue.main.async { [weak self] in
                guard let self, !token.isCancelled else { return }
                self.searchResults = results
                self.isSearching = false
            }
        }
    }

    private func performRecursiveSearch(
        pattern: String,
        basePath: String,
        isCancelled: () -> Bool
    ) -> [FileItem] {
        let baseURL = URL(fileURLWithPath: basePath)
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey]
        guard let enumerator = FileManager().enumerator(
            at: baseURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let maxResults = 500
        var results: [FileItem] = []
        for case let fileURL as URL in enumerator {
            if isCancelled() { return [] }
            if results.count >= maxResults { break }

            let name = fileURL.lastPathComponent
            guard matchesSearch(name, pattern: pattern) else { continue }
            guard let rv = try? fileURL.resourceValues(forKeys: keys) else { continue }

            let parentPath = fileURL.deletingLastPathComponent().path
            let relativePath: String?
            if parentPath == baseURL.path {
                relativePath = nil
            } else if parentPath.hasPrefix(baseURL.path + "/") {
                let rel = String(parentPath.dropFirst(baseURL.path.count + 1))
                relativePath = rel.isEmpty ? nil : rel + "/"
            } else {
                relativePath = nil
            }

            results.append(FileItem(
                url: fileURL,
                name: name,
                modificationDate: rv.contentModificationDate ?? .distantPast,
                size: Int64(rv.fileSize ?? 0),
                isDirectory: rv.isDirectory ?? false,
                relativePath: relativePath
            ))
        }
        return results.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func matchesSearch(_ name: String, pattern: String) -> Bool {
        // ".pdf"  → extension == pdf
        // "."     → any file that has an extension
        if pattern.hasPrefix("."), !pattern.contains("*"), !pattern.contains("?") {
            let ext    = String(pattern.dropFirst()).lowercased()
            let nameExt = URL(fileURLWithPath: name).pathExtension.lowercased()
            return ext.isEmpty ? !nameExt.isEmpty : nameExt == ext
        }
        // "doc*", "*.pdf", "*report*" → NSPredicate LIKE (supports * and ?)
        if pattern.contains("*") || pattern.contains("?") {
            return NSPredicate(format: "SELF LIKE[c] %@", pattern).evaluate(with: name)
        }
        // Plain text → substring match
        return name.localizedCaseInsensitiveContains(pattern)
    }

    // MARK: - Navigation

    func navigate(to path: String) {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return }
        currentPath = path
        addToRecents(path)
        reload()
        startWatching(path)
        scheduleSearch()
    }

    func navigateUp() {
        let parent = URL(fileURLWithPath: currentPath).deletingLastPathComponent()
        guard parent.path != currentPath else { return }
        navigate(to: parent.path)
    }

    func open(_ item: FileItem) {
        if item.isDirectory {
            navigate(to: item.url.path)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func sort(using order: [KeyPathComparator<FileItem>]) {
        items.sort(using: order)
    }

    // MARK: - Recents

    private func addToRecents(_ path: String) {
        recentPaths.removeAll { $0 == path }
        recentPaths.insert(path, at: 0)
        if recentPaths.count > 10 { recentPaths = Array(recentPaths.prefix(10)) }
        UserDefaults.standard.set(recentPaths, forKey: recentsKey)
    }

    var validRecentPaths: [String] {
        recentPaths.filter {
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: $0, isDirectory: &isDir) && isDir.boolValue
        }
    }

    // MARK: - Volumes

    func loadVolumes() {
        mountedVolumes = fm.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey, .volumeIsRemovableKey, .volumeIsInternalKey],
            options: [.skipHiddenVolumes]
        ) ?? []
    }

    private func setupVolumeObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        let handler: (Notification) -> Void = { [weak self] _ in
            DispatchQueue.main.async { self?.loadVolumes() }
        }
        volumeObservers = [
            nc.addObserver(forName: NSWorkspace.didMountNotification,   object: nil, queue: nil, using: handler),
            nc.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: nil, using: handler),
        ]
    }

    // MARK: - Filesystem watching

    private func startWatching(_ path: String) {
        stopWatching()

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let model = Unmanaged<FileExplorerModel>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async { model.reload() }
        }

        var ctx = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &ctx,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes)
        ) else { return }

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        eventStream = stream
    }

    private func stopWatching() {
        guard let stream = eventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
    }

    // MARK: - Clipboard

    func copy(_ items: [FileItem]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(items.map { $0.url as NSURL })
        cutURLs = []
    }

    func cut(_ items: [FileItem]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(items.map { $0.url as NSURL })
        cutURLs = Set(items.map { $0.url })
    }

    func paste() {
        let pb = NSPasteboard.general
        guard let urls = pb.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] else { return }
        let destDir = URL(fileURLWithPath: currentPath)
        for src in urls {
            let dest = uniqueDestURL(for: src, in: destDir)
            do {
                if cutURLs.contains(src) {
                    try fm.moveItem(at: src, to: dest)
                } else {
                    try fm.copyItem(at: src, to: dest)
                }
            } catch {}
        }
        cutURLs = []
        reload()
    }

    func canPaste() -> Bool {
        NSPasteboard.general.canReadObject(
            forClasses: [NSURL.self],
            options: [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly: true]
        )
    }

    private func uniqueDestURL(for src: URL, in dir: URL) -> URL {
        let base = src.deletingPathExtension().lastPathComponent
        let ext  = src.pathExtension
        var dest = dir.appendingPathComponent(src.lastPathComponent)
        var n = 1
        while fm.fileExists(atPath: dest.path) {
            let name = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            dest = dir.appendingPathComponent(name)
            n += 1
        }
        return dest
    }

    // MARK: - File operations

    func delete(_ items: [FileItem]) {
        items.forEach { try? fm.trashItem(at: $0.url, resultingItemURL: nil) }
        reload()
    }

    func deletePermanently(_ items: [FileItem]) {
        items.forEach { try? fm.removeItem(at: $0.url) }
        reload()
    }

    func rename(_ item: FileItem, to newName: String) {
        let dest = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        try? fm.moveItem(at: item.url, to: dest)
        reload()
    }

    func createFolder(named name: String) {
        let url = URL(fileURLWithPath: currentPath).appendingPathComponent(name)
        try? fm.createDirectory(at: url, withIntermediateDirectories: false)
        reload()
    }

    func createFile(named name: String) {
        let url = URL(fileURLWithPath: currentPath).appendingPathComponent(name)
        fm.createFile(atPath: url.path, contents: nil)
        reload()
    }

    func compress(_ items: [FileItem]) {
        guard !items.isEmpty else { return }
        let baseName = items.count == 1
            ? items[0].url.deletingPathExtension().lastPathComponent
            : "Archivio"
        let destDir = URL(fileURLWithPath: currentPath)
        var zipURL  = destDir.appendingPathComponent("\(baseName).zip")
        var n = 1
        while fm.fileExists(atPath: zipURL.path) {
            zipURL = destDir.appendingPathComponent("\(baseName) \(n).zip")
            n += 1
        }
        let process = Process()
        process.currentDirectoryURL = destDir
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipURL.lastPathComponent] + items.map { $0.url.lastPathComponent }
        try? process.run()
        process.waitUntilExit()
        reload()
    }

    // MARK: - Custom actions

    var actionsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/winfinder/actions")
    }

    func loadCustomActions() {
        try? FileManager.default.createDirectory(at: actionsDir, withIntermediateDirectories: true)
        customActions = WFAction.loadAll(from: actionsDir)
    }

    func loadAllEntries() -> [WFActionEntryInfo] {
        let dir = actionsDir
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return [] }
        return contents
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { entry in
                let name = entry.lastPathComponent
                let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDir {
                    let isEnabled = !name.hasSuffix(".disabled")
                    let displayName = isEnabled ? name : String(name.dropLast(".disabled".count))
                    guard FileManager.default.fileExists(atPath: entry.appendingPathComponent("action.json").path)
                    else { return nil }
                    let iconURL = entry.appendingPathComponent("icon.png")
                    let icon = FileManager.default.fileExists(atPath: iconURL.path)
                        ? NSImage(contentsOf: iconURL) : nil
                    return WFActionEntryInfo(displayName: displayName, icon: icon,
                                            url: entry, isFolder: true, isEnabled: isEnabled)
                } else if name.hasSuffix(".json.disabled") {
                    return WFActionEntryInfo(displayName: String(name.dropLast(".json.disabled".count)),
                                            icon: nil, url: entry, isFolder: false, isEnabled: false)
                } else if name.hasSuffix(".json") {
                    return WFActionEntryInfo(displayName: String(name.dropLast(".json".count)),
                                            icon: nil, url: entry, isFolder: false, isEnabled: true)
                }
                return nil
            }
    }

    func toggleEntry(_ entry: WFActionEntryInfo) {
        let name = entry.url.lastPathComponent
        let newName = entry.isEnabled ? name + ".disabled" : String(name.dropLast(".disabled".count))
        let dest = entry.url.deletingLastPathComponent().appendingPathComponent(newName)
        try? fm.moveItem(at: entry.url, to: dest)
        loadCustomActions()
    }

    func deleteEntry(_ entry: WFActionEntryInfo) {
        try? fm.removeItem(at: entry.url)
        loadCustomActions()
    }

    func createAction(name: String, extensions: [String], contexts: Set<WFActionContext>,
                      command: String? = nil, submenuItems: [[String: Any]]? = nil,
                      iconSourceURL: URL?) throws {
        guard command != nil || submenuItems != nil else {
            throw NSError(domain: "winfinder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: String(localized: "Enter a command or at least one submenu item.")])
        }
        let rawSlug = name.lowercased().replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        let slug = rawSlug.isEmpty ? "action" : rawSlug
        var folderURL = actionsDir.appendingPathComponent(slug)
        var n = 1
        while fm.fileExists(atPath: folderURL.path) {
            folderURL = actionsDir.appendingPathComponent("\(slug)-\(n)")
            n += 1
        }
        try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        var json: [String: Any] = [
            "name": name,
            "extensions": extensions,
            "context": contexts.map { $0.rawValue }.sorted()
        ]
        if let cmd = command { json["command"] = cmd }
        else if let sub = submenuItems { json["submenu"] = sub }
        let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        try data.write(to: folderURL.appendingPathComponent("action.json"))
        if let src = iconSourceURL {
            try? fm.copyItem(at: src, to: folderURL.appendingPathComponent("icon.png"))
        }
        loadCustomActions()
    }

    func updateAction(entry: WFActionEntryInfo, name: String, extensions: [String],
                      contexts: Set<WFActionContext>, command: String? = nil,
                      submenuItems: [[String: Any]]? = nil, newIconURL: URL?) throws {
        guard command != nil || submenuItems != nil else {
            throw NSError(domain: "winfinder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: String(localized: "Enter a command or at least one submenu item.")])
        }
        var json: [String: Any] = [
            "name": name,
            "extensions": extensions,
            "context": contexts.map { $0.rawValue }.sorted()
        ]
        if let cmd = command { json["command"] = cmd }
        else if let sub = submenuItems { json["submenu"] = sub }
        let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)

        let rawSlug = name.lowercased().replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        let slug = rawSlug.isEmpty ? "action" : rawSlug
        let parentDir = entry.url.deletingLastPathComponent()

        if entry.isFolder {
            let iconDest = entry.url.appendingPathComponent("icon.png")
            if newIconURL != iconDest {
                try? fm.removeItem(at: iconDest)
                if let src = newIconURL { try? fm.copyItem(at: src, to: iconDest) }
            }
            try data.write(to: entry.url.appendingPathComponent("action.json"))
            let suffix = entry.isEnabled ? "" : ".disabled"
            let desiredName = slug + suffix
            if desiredName != entry.url.lastPathComponent {
                var newURL = parentDir.appendingPathComponent(desiredName)
                var n = 1
                while fm.fileExists(atPath: newURL.path) {
                    newURL = parentDir.appendingPathComponent("\(slug)-\(n)\(suffix)")
                    n += 1
                }
                try fm.moveItem(at: entry.url, to: newURL)
            }
        } else {
            try data.write(to: entry.url)
            let suffix = entry.isEnabled ? ".json" : ".json.disabled"
            let desiredName = slug + suffix
            if desiredName != entry.url.lastPathComponent {
                var newURL = parentDir.appendingPathComponent(desiredName)
                var n = 1
                while fm.fileExists(atPath: newURL.path) {
                    newURL = parentDir.appendingPathComponent("\(slug)-\(n)\(suffix)")
                    n += 1
                }
                try fm.moveItem(at: entry.url, to: newURL)
            }
        }
        loadCustomActions()
    }

    // MARK: - Drag and drop

    func moveFiles(_ urls: [URL], to destPath: String, copy: Bool) {
        let destDir = URL(fileURLWithPath: destPath)
        for src in urls {
            let dest = uniqueDestURL(for: src, in: destDir)
            do {
                if copy {
                    try fm.copyItem(at: src, to: dest)
                } else {
                    try fm.moveItem(at: src, to: dest)
                }
            } catch {}
        }
        reload()
    }

    // MARK: - Open with

    func openWithApps(for item: FileItem) -> [URL] {
        Array(NSWorkspace.shared.urlsForApplications(toOpen: item.url).prefix(15))
    }

    func open(_ item: FileItem, with appURL: URL) {
        NSWorkspace.shared.open(
            [item.url],
            withApplicationAt: appURL,
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
    }
}
