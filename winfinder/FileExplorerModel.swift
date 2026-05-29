import SwiftUI
import AppKit

// MARK: - FileItem

struct FileItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let modificationDate: Date
    let size: Int64
    let isDirectory: Bool

    var sizeFormatted: String {
        guard !isDirectory else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - FileExplorerModel

@Observable
final class FileExplorerModel {
    var currentPath: String
    var searchText = ""
    var items: [FileItem] = []
    var recentPaths: [String] = []
    var mountedVolumes: [URL] = []

    private let fm = FileManager.default
    private let recentsKey = "winfinder.recentPaths"
    @ObservationIgnored private var volumeObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var cutURLs: Set<URL> = []

    init(startPath: String = FileManager.default.homeDirectoryForCurrentUser.path) {
        currentPath = startPath
        recentPaths = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
        loadVolumes()
        reload()
        setupVolumeObservers()
    }

    deinit {
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
        return items.filter { matchesSearch($0.name, pattern: pattern) }
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
