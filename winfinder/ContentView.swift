import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
    @Bindable var model: FileExplorerModel
    @State private var pathInput = FileManager.default.homeDirectoryForCurrentUser.path
    @State private var sortOrder = [KeyPathComparator<FileItem>]()
    @State private var selection = Set<FileItem.ID>()
    @State private var isDropTargeted = false

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
        .onDrop(
            of: [UTType.winfinderFiles, UTType.fileURL],
            isTargeted: $isDropTargeted
        ) { providers in
            let shouldCopy = NSEvent.modifierFlags.contains(.command)
            loadDroppedURLs(from: providers) { urls in
                guard !urls.isEmpty else { return }
                model.moveFiles(urls, to: model.currentPath, copy: shouldCopy)
            }
            return true
        }
        .overlay(
            isDropTargeted
                ? RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .allowsHitTesting(false)
                : nil
        )
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
                .onDrag { dragProvider(for: item) }
            }

            TableColumn("Data modifica", value: \.modificationDate) { item in
                Text(Self.dateFmt.string(from: item.modificationDate))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onDrag { dragProvider(for: item) }
            }
            .width(160)

            TableColumn("Dimensione", value: \.size) { item in
                Text(item.sizeFormatted)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .onDrag { dragProvider(for: item) }
            }
            .width(90)
        }
        .onChange(of: sortOrder) { _, order in
            model.sort(using: order)
        }
        .contextMenu(forSelectionType: FileItem.ID.self, menu: { ids in
            let items = model.displayed.filter { ids.contains($0.id) }

            if items.isEmpty {
                // ── Click su area vuota ──────────────────────────────────
                Button { promptNewFolder() } label: {
                    Label("Nuova cartella", systemImage: "folder.badge.plus")
                }
                Button { promptNewFile() } label: {
                    Label("Nuovo file", systemImage: "doc.badge.plus")
                }
                if model.canPaste() {
                    Divider()
                    Button { model.paste() } label: {
                        Label("Incolla", systemImage: "doc.on.clipboard")
                    }
                }
            } else {
                // ── Click su un file / cartella ──────────────────────────
                let first = items.first!

                Button { model.open(first) } label: {
                    Label("Apri", systemImage: "arrow.right.circle")
                }

                let apps = model.openWithApps(for: first)
                if !apps.isEmpty {
                    Menu {
                        ForEach(apps, id: \.self) { appURL in
                            Button(appDisplayName(appURL)) {
                                model.open(first, with: appURL)
                            }
                        }
                    } label: {
                        Label("Apri con\u{2026}", systemImage: "ellipsis.circle")
                    }
                }

                Divider()

                Button { model.copy(items) } label: {
                    Label("Copia", systemImage: "doc.on.doc")
                }
                Button { model.cut(items) } label: {
                    Label("Taglia", systemImage: "scissors")
                }
                if model.canPaste() {
                    Button { model.paste() } label: {
                        Label("Incolla", systemImage: "doc.on.clipboard")
                    }
                }

                Divider()

                if items.count == 1 {
                    Button { promptRename(first) } label: {
                        Label("Rinomina", systemImage: "pencil")
                    }
                }
                Button { model.compress(items) } label: {
                    Label("Comprimi in ZIP", systemImage: "archivebox")
                }

                Divider()

                Button { promptNewFolder() } label: {
                    Label("Nuova cartella", systemImage: "folder.badge.plus")
                }
                Button { promptNewFile() } label: {
                    Label("Nuovo file", systemImage: "doc.badge.plus")
                }

                Divider()

                Button(role: .destructive) { confirmDelete(items) } label: {
                    Label("Elimina", systemImage: "trash")
                }
            }
        }, primaryAction: { ids in
            for id in ids {
                if let item = model.displayed.first(where: { $0.id == id }) {
                    model.open(item)
                }
            }
        })
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack {
            Text("\(model.displayed.count) elementi")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !selection.isEmpty {
                Text("\(selection.count) selezionati")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Context menu helpers

    private func promptRename(_ item: FileItem) {
        nsPrompt(
            title: "Rinomina",
            message: "Nuovo nome per \"\(item.name)\":",
            defaultValue: item.name,
            confirmLabel: "Rinomina"
        ) { newName in
            if newName != item.name { model.rename(item, to: newName) }
        }
    }

    private func promptNewFolder() {
        nsPrompt(
            title: "Nuova cartella",
            message: "Nome della cartella:",
            defaultValue: "Nuova cartella",
            confirmLabel: "Crea"
        ) { model.createFolder(named: $0) }
    }

    private func promptNewFile() {
        nsPrompt(
            title: "Nuovo file",
            message: "Nome del file:",
            defaultValue: "Senza titolo.txt",
            confirmLabel: "Crea"
        ) { model.createFile(named: $0) }
    }

    private func confirmDelete(_ items: [FileItem]) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let alert = NSAlert()
            let label = items.count == 1
                ? "\"\(items[0].name)\""
                : "\(items.count) elementi"
            alert.messageText = "Sposta \(label) nel cestino?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Sposta nel cestino")
            alert.addButton(withTitle: "Annulla")
            if alert.runModal() == .alertFirstButtonReturn {
                model.delete(items)
            }
        }
    }

    /// Shows a native NSAlert with a text-field accessory.
    private func nsPrompt(
        title: String,
        message: String,
        defaultValue: String,
        confirmLabel: String,
        action: @escaping (String) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: confirmLabel)
            alert.addButton(withTitle: "Annulla")
            let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            tf.stringValue = defaultValue
            tf.selectText(nil)
            alert.accessoryView = tf
            alert.window.initialFirstResponder = tf
            if alert.runModal() == .alertFirstButtonReturn {
                let value = tf.stringValue.trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { action(value) }
            }
        }
    }

    // MARK: - Drag support

    private func dragProvider(for item: FileItem) -> NSItemProvider {
        let selectedItems = selection.contains(item.id)
            ? model.displayed.filter { selection.contains($0.id) }
            : [item]
        let paths = selectedItems.map { $0.url.path }.joined(separator: "\n")
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.winfinderFiles.identifier,
            visibility: .all
        ) { completion in
            completion(paths.data(using: .utf8), nil)
            return nil
        }
        // Also register standard file URL so Finder can accept the drop
        if selectedItems.count == 1, let url = selectedItems.first?.url {
            provider.registerObject(url as NSURL, visibility: .all)
        }
        return provider
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

    private func appDisplayName(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }
}

#Preview {
    ContentView()
}
