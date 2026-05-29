import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Custom UTType

extension UTType {
    /// Private type used to bundle multiple file paths in a single drag item.
    /// Both ends (source and target) are the same app, so no Info.plist declaration needed.
    static let winfinderFiles = UTType(exportedAs: "com.winfinder.file-list")
}

// MARK: - Transferable drag payload (multi-file)

struct FileGroupTransferable: Transferable {
    let urls: [URL]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .winfinderFiles) { item in
            item.urls.map(\.path).joined(separator: "\n").data(using: .utf8)!
        } importing: { data in
            let paths = (String(data: data, encoding: .utf8) ?? "")
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { URL(fileURLWithPath: String($0)) }
            return FileGroupTransferable(urls: paths)
        }
        // Single-file representation so Finder can accept the drop
        FileRepresentation(exportedContentType: .fileURL) { item in
            guard let url = item.urls.first else { throw CancellationError() }
            return SentTransferredFile(url)
        } importing: { received in
            FileGroupTransferable(urls: [received.file])
        }
    }
}

// MARK: - URL extraction from drop providers

/// Decodes file URLs from an array of NSItemProvider (WinFinder internal type + public.file-url).
func loadDroppedURLs(
    from providers: [NSItemProvider],
    completion: @escaping ([URL]) -> Void
) {
    guard !providers.isEmpty else { completion([]); return }

    let group  = DispatchGroup()
    let serial = DispatchQueue(label: "winfinder.drop")
    var result: [URL] = []

    for provider in providers {
        group.enter()
        if provider.hasItemConformingToTypeIdentifier(UTType.winfinderFiles.identifier) {
            // WinFinder internal: newline-separated absolute paths
            provider.loadDataRepresentation(
                forTypeIdentifier: UTType.winfinderFiles.identifier
            ) { data, _ in
                defer { group.leave() }
                guard let data, let str = String(data: data, encoding: .utf8) else { return }
                let urls = str.split(separator: "\n", omittingEmptySubsequences: true)
                              .map { URL(fileURLWithPath: String($0)) }
                serial.sync { result.append(contentsOf: urls) }
            }
        } else {
            // Standard file URL (Finder, other apps)
            provider.loadObject(ofClass: URL.self) { url, _ in
                defer { group.leave() }
                guard let url else { return }
                serial.sync { result.append(url) }
            }
        }
    }

    group.notify(queue: .main) { completion(result) }
}
