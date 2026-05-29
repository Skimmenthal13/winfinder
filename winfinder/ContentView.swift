import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @State private var model = FileExplorerModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(model: model)
                .navigationSplitViewColumnWidth(min: 140, ideal: 180, max: 320)
        } detail: {
            FileListView(model: model)
        }
        .frame(minWidth: 800, minHeight: 450)
    }
}

// MARK: - FileListView

struct FileListView: View {
    let model: FileExplorerModel
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
    }

    // MARK: - Path bar

    private var pathBar: some View {
        GeometryReader { geo in
            let fieldsWidth = geo.size.width - 52
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

    // MARK: - File icon

    private func fileIcon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf":                                                      return "doc.richtext.fill"
        case "png", "jpg", "jpeg", "gif", "heic", "tiff", "webp",
             "bmp", "svg":                                               return "photo.fill"
        case "mp4", "mov", "avi", "mkv", "m4v":                         return "film.fill"
        case "mp3", "aac", "flac", "m4a", "wav":                        return "music.note"
        case "zip", "tar", "gz", "bz2", "7z", "rar":                    return "archivebox.fill"
        case "swift", "py", "js", "ts", "go", "rs",
             "cpp", "c", "h", "java", "rb", "kt":                       return "doc.text.fill"
        case "app":                                                      return "app.fill"
        case "dmg":                                                      return "externaldrive.fill"
        case "pkg", "mpkg":                                              return "shippingbox.fill"
        default:                                                         return "doc.fill"
        }
    }
}

#Preview {
    ContentView()
}
