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
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
        item.isDirectory ? navigate(to: item.url.path) : NSWorkspace.shared.open(item.url)
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
}
