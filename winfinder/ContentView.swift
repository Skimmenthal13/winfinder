import SwiftUI

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

@Observable
final class FileExplorerModel {
    var currentPath: String
    var searchText = ""
    var items: [FileItem] = []

    private let fm = FileManager.default

    init(startPath: String = FileManager.default.homeDirectoryForCurrentUser.path) {
        currentPath = startPath
        reload()
    }

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

    func navigate(to path: String) {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return }
        currentPath = path
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
}

struct ContentView: View {
    @State private var model = FileExplorerModel()
    @State private var pathInput = FileManager.default.homeDirectoryForCurrentUser.path
    @State private var sortOrder = [KeyPathComparator<FileItem>]()
    @State private var selection: FileItem.ID? = nil

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            pathBar
            Divider()
            fileTable
            Divider()
            statusBar
        }
        .frame(minWidth: 700, minHeight: 450)
    }

    // MARK: - Path bar

    private var pathBar: some View {
        GeometryReader { geo in
            let fieldsWidth = geo.size.width - 52  // 10+10 padding + 24 button + 8 spacing
            HStack(spacing: 8) {
                Button(action: model.navigateUp) {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                .frame(width: 24)

                TextField("Path", text: $pathInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: max(0, fieldsWidth * 0.8 - 4))
                    .onSubmit {
                        model.navigate(to: pathInput)
                        pathInput = model.currentPath
                    }
                    .onChange(of: model.currentPath) { _, new in pathInput = new }

                TextField(
                    "",
                    text: $model.searchText,
                    prompt: Text("\(Image(systemName: "magnifyingglass")) Cerca")
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: max(0, fieldsWidth * 0.2))
            }
            .padding(.horizontal, 10)
            .frame(height: geo.size.height, alignment: .center)
        }
        .frame(height: 38)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - File table

    private var fileTable: some View {
        Table(model.displayed, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Nome", value: \.name) { item in
                HStack(spacing: 6) {
                    Image(systemName: item.isDirectory ? "folder.fill" : fileIcon(for: item.url))
                        .foregroundStyle(item.isDirectory ? Color.accentColor : Color.secondary)
                        .frame(width: 16, alignment: .center)
                    Text(item.name)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { model.open(item) }
            }

            TableColumn("Data modifica", value: \.modificationDate) { item in
                Text(Self.dateFmt.string(from: item.modificationDate))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { model.open(item) }
            }
            .width(160)

            TableColumn("Dimensione", value: \.size) { item in
                Text(item.sizeFormatted)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { model.open(item) }
            }
            .width(90)
        }
        .onChange(of: sortOrder) { _, order in
            model.sort(using: order)
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack {
            Text("\(model.displayed.count) elementi")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Helpers

    private func fileIcon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf":                                          return "doc.richtext.fill"
        case "png", "jpg", "jpeg", "gif", "heic", "tiff",
             "webp", "bmp", "svg":                          return "photo.fill"
        case "mp4", "mov", "avi", "mkv", "m4v":             return "film.fill"
        case "mp3", "aac", "flac", "m4a", "wav":            return "music.note"
        case "zip", "tar", "gz", "bz2", "7z", "rar":        return "archivebox.fill"
        case "swift", "py", "js", "ts", "go", "rs",
             "cpp", "c", "h", "java", "rb", "kt":           return "doc.text.fill"
        case "app":                                          return "app.fill"
        case "dmg":                                          return "externaldrive.fill"
        case "pkg", "mpkg":                                  return "shippingbox.fill"
        default:                                             return "doc.fill"
        }
    }
}

#Preview {
    ContentView()
}
