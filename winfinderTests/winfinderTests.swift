import Foundation
import Testing
@testable import Win_Finder

@MainActor
struct FileExplorerTests {
    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func write(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url)
    }

    private func finishCompression(_ model: FileExplorerModel) async throws {
        for _ in 0..<500 {
            if !model.isCompressing { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("Compression did not finish within 10 seconds")
    }

    private func unzip(_ archive: URL, member: String) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", archive.path, member]
        process.standardOutput = output
        try process.run()
        let bytes = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        return String(decoding: bytes, as: UTF8.self)
    }

    @Test func reloadRemovesDeletedSelection() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("test.txt")
        try write("original", to: file)
        let model = FileExplorerModel(startPath: root.path, enableIntegration: false)
        model.selection = [file]
        try FileManager.default.removeItem(at: file)
        model.reload()
        #expect(model.selection.isEmpty)
        #expect(model.displayed.isEmpty)
    }

    @Test func sortingSurvivesReloadAndKeepsFoldersFirst() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("a", to: root.appendingPathComponent("small.txt"))
        try write("abcdef", to: root.appendingPathComponent("large.txt"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("folder"), withIntermediateDirectories: false)
        let model = FileExplorerModel(startPath: root.path, enableIntegration: false)
        model.sort(using: [KeyPathComparator(\FileItem.size, order: .reverse)])
        model.reload()
        #expect(model.displayed.map(\.name) == ["folder", "large.txt", "small.txt"])
        // Search results use the same ordering, regardless of arrival order.
        model.searchText = "zz"
        model.searchResults = model.items.reversed()
        #expect(model.displayed.map(\.name) == ["folder", "large.txt", "small.txt"])
        model.searchText = ""
    }

    @Test func renameCollisionPreservesBothFilesAndReportsError() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("first", to: root.appendingPathComponent("a.txt"))
        try write("second", to: root.appendingPathComponent("b.txt"))
        let model = FileExplorerModel(startPath: root.path, enableIntegration: false)
        let item = try #require(model.items.first { $0.name == "a.txt" })
        model.rename(item, to: "b.txt")
        #expect(model.operationError != nil)
        #expect(try String(contentsOf: root.appendingPathComponent("a.txt"), encoding: .utf8) == "first")
        #expect(try String(contentsOf: root.appendingPathComponent("b.txt"), encoding: .utf8) == "second")
    }

    @Test func newFileDoesNotOverwriteExistingContent() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("keep", to: root.appendingPathComponent("note.txt"))
        let model = FileExplorerModel(startPath: root.path, enableIntegration: false)
        model.createFileNamed("note.txt")
        #expect(try String(contentsOf: root.appendingPathComponent("note.txt"), encoding: .utf8) == "keep")
        #expect(model.items.count == 2)
        #expect(model.pendingSelectURL != root.appendingPathComponent("note.txt"))
    }

    @Test func compressionPreservesNestedNamesAndReturnsImmediately() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        for folder in ["one", "two"] {
            let dir = root.appendingPathComponent(folder)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
            try write(folder, to: dir.appendingPathComponent("same.txt"))
        }
        // A root-level namesake must not be accidentally archived.
        try write("wrong", to: root.appendingPathComponent("same.txt"))
        let model = FileExplorerModel(startPath: root.path, enableIntegration: false)
        let nested = ["one", "two"].map { folder in
            FileItem(url: root.appendingPathComponent(folder + "/same.txt"), name: "same.txt",
                     modificationDate: .now, size: 3, isDirectory: false)
        }
        model.compress(nested)
        #expect(model.isCompressing)
        try await finishCompression(model)
        #expect(model.operationError == nil)
        let zip = try #require(model.pendingSelectURL)
        #expect(try unzip(zip, member: "one/same.txt") == "one")
        #expect(try unzip(zip, member: "two/same.txt") == "two")
    }

    @Test func compressionFailureDoesNotPublishPartialArchive() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = FileExplorerModel(startPath: root.path, enableIntegration: false)
        let missing = FileItem(url: root.appendingPathComponent("missing.txt"), name: "missing.txt",
                               modificationDate: .now, size: 0, isDirectory: false)
        model.compress([missing])
        try await finishCompression(model)
        #expect(model.operationError != nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test func compressionDoesNotReplaceExistingZIP() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("original ZIP", to: root.appendingPathComponent("note.zip"))
        try write("new content", to: root.appendingPathComponent("note.txt"))
        let model = FileExplorerModel(startPath: root.path, enableIntegration: false)
        let item = try #require(model.items.first { $0.name == "note.txt" })
        model.compress([item])
        try await finishCompression(model)
        #expect(model.operationError == nil)
        #expect(try String(contentsOf: root.appendingPathComponent("note.zip"), encoding: .utf8) == "original ZIP")
        let output = try #require(model.pendingSelectURL)
        #expect(output.lastPathComponent != "note.zip")
        #expect(try unzip(output, member: "note.txt") == "new content")
    }
    @Test(arguments: ["-options.txt", "O'Brien notes.txt", "$(echo hello).txt"])
    func compressionAcceptsLiteralFilenames(_ filename: String) async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("literal content", to: root.appendingPathComponent(filename))
        let model = FileExplorerModel(startPath: root.path, enableIntegration: false)
        let item = try #require(model.items.first)
        model.compress([item])
        try await finishCompression(model)
        #expect(model.operationError == nil)
        let output = try #require(model.pendingSelectURL)
        #expect(try unzip(output, member: filename) == "literal content")
    }

}
