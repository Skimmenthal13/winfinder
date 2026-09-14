import Foundation

nonisolated struct FileTransferResult: Sendable {
    var destinations: [URL: URL] = [:]
    var movedSources: Set<URL> = []
    var errors: [String] = []
}

nonisolated enum FileTransferWorker {
    // Serialize transfers across windows so our own jobs don't race for names.
    static let queue = DispatchQueue(label: "winfinder.transfers", qos: .userInitiated)

    static func run(_ sources: [URL], destination: URL, moving: Set<URL>,
                    progress: @Sendable (Int) -> Void) -> FileTransferResult {
        let fm = FileManager()
        var result = FileTransferResult()
        for (index, source) in sources.enumerated() {
            do {
                let resolvedSource = source.resolvingSymlinksInPath().standardizedFileURL
                let resolvedDestination = destination.resolvingSymlinksInPath().standardizedFileURL
                let resource = try source.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                if resource.isDirectory == true && resource.isSymbolicLink != true {
                    let prefix = resolvedSource.path == "/" ? "/" : resolvedSource.path + "/"
                    guard resolvedDestination != resolvedSource,
                          !resolvedDestination.path.hasPrefix(prefix) else {
                        throw NSError(domain: "WinFinder", code: 1, userInfo: [
                            NSLocalizedDescriptionKey: String(localized: "Cannot transfer a folder into itself.")
                        ])
                    }
                }
                if moving.contains(source),
                   source.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL == resolvedDestination {
                    result.destinations[source] = source
                    result.movedSources.insert(source)
                } else {
                    let target = uniqueDestination(source, in: destination, fileManager: fm)
                    if moving.contains(source) {
                        try fm.moveItem(at: source, to: target)
                        result.movedSources.insert(source)
                    } else {
                        // Keep incomplete copies out of the visible destination.
                        let staging = destination.appendingPathComponent(".winfinder-copy-" + UUID().uuidString)
                        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
                        defer { try? fm.removeItem(at: staging) }
                        let temporary = staging.appendingPathComponent("item")
                        try fm.copyItem(at: source, to: temporary)
                        try fm.moveItem(at: temporary, to: target)
                    }
                    result.destinations[source] = target
                }
            } catch {
                result.errors.append("\(source.path): \(error.localizedDescription)")
            }
            progress(index + 1)
        }
        return result
    }

    private static func uniqueDestination(_ source: URL, in directory: URL, fileManager: FileManager) -> URL {
        let ext = source.pathExtension
        let stem = source.deletingPathExtension().lastPathComponent
        var target = directory.appendingPathComponent(source.lastPathComponent)
        var suffix = 1
        // resourceValues also detects dangling symlinks, unlike fileExists.
        while fileManager.fileExists(atPath: target.path)
            || (try? target.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
            let name = ext.isEmpty ? "\(stem) \(suffix)" : "\(stem) \(suffix).\(ext)"
            target = directory.appendingPathComponent(name)
            suffix += 1
        }
        return target
    }
}
