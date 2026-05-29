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
    @State private var sortKey = "name"
    @State private var sortAscending = true
    @State private var isDropTargeted = false
    @FocusState private var fileListFocused: Bool
    @State private var typeSelectBuffer = ""
    @State private var typeSelectTask: DispatchWorkItem? = nil

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    private let dateColumnWidth: CGFloat = 160
    private let sizeColumnWidth: CGFloat = 90

    var body: some View {
        VStack(spacing: 0) {
            pathBar
            Divider()
            columnHeader
            Divider()
            fileList
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
            let fieldsWidth = geo.size.width - 84
            HStack(spacing: 8) {
                Button(action: model.navigateUp) {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                .frame(width: 24)

                Button(action: model.reload) {
                    Image(systemName: "arrow.clockwise")
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

    // MARK: - Column header

    private var columnHeader: some View {
        HStack(spacing: 0) {
            headerButton("Nome", key: "name")
            Divider().frame(height: 14)
            headerButton("Data modifica", key: "date")
                .frame(width: dateColumnWidth)
            Divider().frame(height: 14)
            headerButton("Dimensione", key: "size")
                .frame(width: sizeColumnWidth)
        }
        .frame(height: 26)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func headerButton(_ title: String, key: String) -> some View {
        Button {
            if sortKey == key {
                sortAscending.toggle()
            } else {
                sortKey = key
                sortAscending = true
            }
            applySort()
        } label: {
            HStack(spacing: 3) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                if sortKey == key {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: key == "name" ? .infinity : nil, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func applySort() {
        let order: SortOrder = sortAscending ? .forward : .reverse
        switch sortKey {
        case "name": model.sort(using: [KeyPathComparator(\.name, order: order)])
        case "date": model.sort(using: [KeyPathComparator(\.modificationDate, order: order)])
        case "size": model.sort(using: [KeyPathComparator(\.size, order: order)])
        default: break
        }
    }

    // MARK: - File list

    private var fileList: some View {
        List(model.displayed, id: \.id, selection: $model.selection) { item in
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: item.isDirectory ? "folder.fill" : fileIcon(for: item.url))
                        .foregroundStyle(item.isDirectory ? Color.accentColor : Color.secondary)
                        .frame(width: 16, alignment: .center)
                    Text(item.name)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(Self.dateFmt.string(from: item.modificationDate))
                    .foregroundStyle(.secondary)
                    .frame(width: dateColumnWidth, alignment: .leading)

                Text(item.sizeFormatted)
                    .foregroundStyle(.secondary)
                    .frame(width: sizeColumnWidth, alignment: .trailing)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                fileListFocused = true
                if NSEvent.modifierFlags.contains(.command) {
                    if model.selection.contains(item.url) {
                        model.selection.remove(item.url)
                    } else {
                        model.selection.insert(item.url)
                    }
                } else {
                    model.selection = [item.url]
                }
            }
            .simultaneousGesture(TapGesture(count: 2).onEnded { model.open(item) })
            .onDrag { makeDragProvider(for: item) }
            .contextMenu { rowContextMenu(for: item) }
        }
        .listStyle(.plain)
        .focused($fileListFocused)
        .onKeyPress(characters: .letters.union(.decimalDigits), phases: .down) { press in
            handleTypeToSelect(press.characters)
            return .handled
        }
        .onCopyCommand {
            let items = model.displayed.filter { model.selection.contains($0.url) }
            guard !items.isEmpty else { return [] }
            model.copy(items)
            return items.map { NSItemProvider(object: $0.url as NSURL) }
        }
        .onCutCommand {
            let items = model.displayed.filter { model.selection.contains($0.url) }
            guard !items.isEmpty else { return [] }
            model.cut(items)
            return items.map { NSItemProvider(object: $0.url as NSURL) }
        }
        .onPasteCommand(of: [UTType.fileURL]) { _ in
            model.paste()
        }
        .onKeyPress(.delete, phases: .down) { press in
            let selected = model.displayed.filter { model.selection.contains($0.url) }
            guard !selected.isEmpty else { return .ignored }
            if press.modifiers.contains(.shift) {
                confirmPermanentDelete(selected)
            } else {
                model.delete(selected)
            }
            return .handled
        }
        .contextMenu {
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
        }
    }

    // MARK: - Type-to-select

    private func handleTypeToSelect(_ character: String) {
        typeSelectTask?.cancel()
        let lower = character.lowercased()

        if typeSelectBuffer == lower {
            // Same letter within timeout: cycle through all files starting with it
            let matches = model.displayed.filter { $0.name.lowercased().hasPrefix(lower) }
            if !matches.isEmpty {
                let nextURL: URL
                if let cur = model.selection.first,
                   let idx = matches.firstIndex(where: { $0.url == cur }) {
                    nextURL = matches[(idx + 1) % matches.count].url
                } else {
                    nextURL = matches[0].url
                }
                model.selection = [nextURL]
            }
        } else {
            // Different or extended prefix: append and jump to first match
            typeSelectBuffer += lower
            let buf = typeSelectBuffer
            if let match = model.displayed.first(where: { $0.name.lowercased().hasPrefix(buf) }) {
                model.selection = [match.url]
            }
        }

        let task = DispatchWorkItem { self.typeSelectBuffer = "" }
        typeSelectTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }

    // MARK: - Drag provider

    private func makeDragProvider(for item: FileItem) -> NSItemProvider {
        let urlsToDrag: [URL]
        if model.selection.contains(item.url) && model.selection.count > 1 {
            urlsToDrag = model.displayed
                .filter { model.selection.contains($0.url) }
                .map(\.url)
        } else {
            urlsToDrag = [item.url]
        }

        if urlsToDrag.count == 1 {
            return NSItemProvider(object: urlsToDrag[0] as NSURL)
        }

        // Multi-file: encode all paths in the custom type for internal drops,
        // plus register the first URL so Finder can accept at least one file.
        let provider = NSItemProvider()
        let payload = urlsToDrag.map(\.path).joined(separator: "\n")
        if let data = payload.data(using: .utf8) {
            provider.registerDataRepresentation(
                forTypeIdentifier: UTType.winfinderFiles.identifier,
                visibility: .all
            ) { completion in
                completion(data, nil)
                return nil
            }
        }
        provider.registerObject(urlsToDrag[0] as NSURL, visibility: .all)
        return provider
    }

    // MARK: - Row context menu

    @ViewBuilder
    private func rowContextMenu(for item: FileItem) -> some View {
        let selectedItems: [FileItem] = model.selection.contains(item.url)
            ? model.displayed.filter { model.selection.contains($0.url) }
            : [item]
        let first = selectedItems.first ?? item

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

        Button { model.copy(selectedItems) } label: {
            Label("Copia", systemImage: "doc.on.doc")
        }
        Button { model.cut(selectedItems) } label: {
            Label("Taglia", systemImage: "scissors")
        }
        if model.canPaste() {
            Button { model.paste() } label: {
                Label("Incolla", systemImage: "doc.on.clipboard")
            }
        }

        Divider()

        if selectedItems.count == 1 {
            Button { promptRename(first) } label: {
                Label("Rinomina", systemImage: "pencil")
            }
        }
        Button { model.compress(selectedItems) } label: {
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

        Button(role: .destructive) { confirmDelete(selectedItems) } label: {
            Label("Elimina", systemImage: "trash")
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack {
            Text("\(model.displayed.count) elementi")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !model.selection.isEmpty {
                Text("\(model.selection.count) selezionati")
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

    private func confirmPermanentDelete(_ items: [FileItem]) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let alert = NSAlert()
            let label = items.count == 1
                ? "\"\(items[0].name)\""
                : "\(items.count) elementi"
            alert.messageText = "Eliminare definitivamente \(label)?"
            alert.informativeText = "Questa operazione non può essere annullata."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Elimina")
            alert.addButton(withTitle: "Annulla")
            if alert.runModal() == .alertFirstButtonReturn {
                model.deletePermanently(items)
            }
        }
    }

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
