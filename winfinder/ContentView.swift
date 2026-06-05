import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - ContentView

struct ContentView: View {
    @State private var model = FileExplorerModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showExtensionsManager = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(model: model)
                .navigationSplitViewColumnWidth(min: 140, ideal: 180, max: 320)
        } detail: {
            FileListView(model: model)
                .navigationSubtitle(
                    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                )
        }
        .frame(minWidth: 800, minHeight: 450)
        .sheet(isPresented: $showExtensionsManager) {
            ExtensionsManagerView(model: model)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openExtensionsManager)) { _ in
            showExtensionsManager = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToPath)) { note in
            guard let path = note.object as? String else { return }
            model.navigate(to: path)
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectFile)) { note in
            guard let path = note.object as? String else { return }
            model.pendingSelectURL = URL(fileURLWithPath: path)
        }
    }
}

// MARK: - FileListView

struct FileListView: View {
    @Bindable var model: FileExplorerModel
    @State private var isEditingPath = false
    @State private var pathEditText = ""
    @FocusState private var pathEditFocused: Bool
    @State private var sortKey = "name"
    @State private var sortAscending = true
    @State private var isDropTargeted = false
    @FocusState private var fileListFocused: Bool
    @State private var typeSelectBuffer = ""
    @State private var typeSelectTask: DispatchWorkItem? = nil
    @State private var anchorURL: URL? = nil
    @State private var scrollToURL: URL? = nil

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
        .background(KeyDeleteMonitor(model: model))
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

                if isEditingPath {
                    TextField("Path", text: $pathEditText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($pathEditFocused)
                        .onSubmit {
                            model.navigate(to: pathEditText)
                            isEditingPath = false
                        }
                        .onKeyPress(.escape) {
                            isEditingPath = false
                            return .handled
                        }
                        .onChange(of: pathEditFocused) { _, focused in
                            if !focused { isEditingPath = false }
                        }
                        .frame(width: max(0, fieldsWidth * 0.8 - 4))
                } else {
                    breadcrumbView
                        .frame(width: max(0, fieldsWidth * 0.8 - 4))
                }

                TextField(
                    "",
                    text: $model.searchText,
                    prompt: Text("\(Image(systemName: "magnifyingglass")) ") + Text("Search")
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

    private var breadcrumbView: some View {
        let components = pathComponents()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(components.enumerated()), id: \.offset) { idx, component in
                    Button {
                        model.navigate(to: component.path)
                    } label: {
                        if idx == 0 {
                            Image(systemName: "externaldrive.fill")
                                .font(.caption)
                        } else {
                            Text(component.name)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(.body))
                    .foregroundStyle(
                        idx == components.count - 1 ? Color.primary : Color.secondary
                    )
                    .padding(.horizontal, 6)
                    .frame(height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(idx == components.count - 1
                                  ? Color.accentColor.opacity(0.12)
                                  : Color(NSColor.labelColor).opacity(0.07))
                    )

                    ChevronMenuView(
                        subdirectories: subdirectories(at: component.path),
                        onNavigate: { sub in
                            model.navigate(
                                to: URL(fileURLWithPath: component.path)
                                    .appendingPathComponent(sub).path
                            )
                        }
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
        }
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .onTapGesture {
            pathEditText = model.currentPath
            isEditingPath = true
            pathEditFocused = true
        }
    }

    private func pathComponents() -> [(name: String, path: String)] {
        let path = model.currentPath
        var result: [(name: String, path: String)] = []
        var accumulated = ""
        for part in path.split(separator: "/", omittingEmptySubsequences: true) {
            accumulated += "/" + part
            result.append((name: String(part), path: accumulated))
        }
        result.insert((name: "/", path: "/"), at: 0)
        return result
    }

    private func subdirectories(at path: String) -> [String] {
        let url = URL(fileURLWithPath: path)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return contents.compactMap { u -> String? in
            guard (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            else { return nil }
            return u.lastPathComponent
        }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // MARK: - Column header

    private var columnHeader: some View {
        HStack(spacing: 0) {
            headerButton("Name", key: "name")
            Divider().frame(height: 14)
            headerButton("Date Modified", key: "date")
                .frame(width: dateColumnWidth)
            Divider().frame(height: 14)
            headerButton("Size", key: "size")
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
        ScrollViewReader { proxy in
        List(model.displayed, id: \.id, selection: $model.selection) { item in
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    fileItemIcon(for: item)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.displayName)
                            .lineLimit(1)
                        if let path = item.relativePath {
                            Text(path)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
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
                let mods = NSEvent.modifierFlags
                if mods.contains(.shift) {
                    // Range selection between anchor and this item.
                    if let anchor = anchorURL,
                       let anchorIdx = model.displayed.firstIndex(where: { $0.url == anchor }),
                       let currentIdx = model.displayed.firstIndex(where: { $0.url == item.url }) {
                        let lo = min(anchorIdx, currentIdx)
                        let hi = max(anchorIdx, currentIdx)
                        model.selection = Set(model.displayed[lo...hi].map(\.url))
                    } else {
                        // No anchor yet: treat as plain click and set anchor.
                        model.selection = [item.url]
                        anchorURL = item.url
                    }
                    // Shift+click never moves the anchor.
                } else if mods.contains(.command) {
                    if model.selection.contains(item.url) {
                        model.selection.remove(item.url)
                    } else {
                        model.selection.insert(item.url)
                    }
                    anchorURL = item.url
                } else {
                    model.selection = [item.url]
                    anchorURL = item.url
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
        .contextMenu {
            Button { promptNewFolder() } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            Button { promptNewFile() } label: {
                Label("New File", systemImage: "doc.badge.plus")
            }
            if model.canPaste() {
                Divider()
                Button { model.paste() } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
            }
            let bgActions = model.customActions.filter { $0.matchesContext(.background) }
            if !bgActions.isEmpty {
                Divider()
                ForEach(Array(bgActions.enumerated()), id: \.offset) { _, action in
                    topLevelAction(action, paths: [model.currentPath])
                }
            }
        }
        .onChange(of: scrollToURL) { _, url in
            guard let url else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                proxy.scrollTo(url, anchor: nil)
            }
            scrollToURL = nil
        }
        .onChange(of: model.pendingSelectURL) { _, url in
            guard let url else { return }
            model.selection = [url]
            anchorURL = url
            scrollToURL = url
            model.pendingSelectURL = nil
        }
        } // ScrollViewReader
    }

    // MARK: - File item icon

    @ViewBuilder
    private func fileItemIcon(for item: FileItem) -> some View {
        if item.isDirectory {
            Image(systemName: "folder.fill")
                .foregroundStyle(Color(red: 1, green: 214/255, blue: 10/255))
                .frame(width: 16, height: 16)
        } else {
            let ext = item.url.pathExtension.lowercased()
            let assetName = "viv-\(ext)"
            if !ext.isEmpty, let img = NSImage(named: assetName) {
                Image(nsImage: img)
                    .interpolation(.high)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
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
                scrollToURL = nextURL
            }
        } else {
            // Different or extended prefix: append and jump to first match
            typeSelectBuffer += lower
            let buf = typeSelectBuffer
            if let match = model.displayed.first(where: { $0.name.lowercased().hasPrefix(buf) }) {
                model.selection = [match.url]
                scrollToURL = match.url
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

    // MARK: - Custom action execution

    private func executeAction(_ command: String, file: String) {
        let escaped = "'" + file.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let cmd = command.replacingOccurrences(of: "{file}", with: escaped)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", cmd]
        try? proc.run()
    }

    private static let transparentIcon: NSImage = {
        let img = NSImage(size: NSSize(width: 16, height: 16))
        img.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: img.size).fill(using: .copy)
        img.unlockFocus()
        return img
    }()

    private func actionLabel(name: String, icon: NSImage?) -> some View {
        Label {
            Text(name)
        } icon: {
            Image(nsImage: icon ?? Self.transparentIcon)
                .interpolation(.high)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        }
    }

    private func menuItem(_ item: WFMenuItem, paths: [String]) -> AnyView {
        switch item {
        case .separator:
            return AnyView(Divider())
        case .action(let name, let icon, let content):
            switch content {
            case .command(let cmd):
                return AnyView(
                    Button {
                        paths.forEach { executeAction(cmd, file: $0) }
                    } label: {
                        actionLabel(name: name, icon: icon)
                    }
                )
            case .submenu(let sub):
                return AnyView(
                    Menu {
                        ForEach(Array(sub.enumerated()), id: \.offset) { _, child in
                            self.menuItem(child, paths: paths)
                        }
                    } label: {
                        actionLabel(name: name, icon: icon)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func topLevelAction(_ action: WFAction, paths: [String]) -> some View {
        if case .command(let cmd) = action.content {
            Button {
                paths.forEach { executeAction(cmd, file: $0) }
            } label: {
                actionLabel(name: action.name, icon: action.icon)
            }
        } else if case .submenu(let items) = action.content {
            Menu {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    menuItem(item, paths: paths)
                }
            } label: {
                actionLabel(name: action.name, icon: action.icon)
            }
        }
    }

    // MARK: - Row context menu

    @ViewBuilder
    private func rowContextMenu(for item: FileItem) -> some View {
        let selectedItems: [FileItem] = model.selection.contains(item.url)
            ? model.displayed.filter { model.selection.contains($0.url) }
            : [item]
        let first = selectedItems.first ?? item

        Button { model.open(first) } label: {
            Label("Open", systemImage: "arrow.right.circle")
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
                Label("Open With…", systemImage: "ellipsis.circle")
            }
        }

        Button {
            let urls = selectedItems.map(\.url)
            NSSharingService(named: .sendViaAirDrop)?.perform(withItems: urls)
        } label: {
            Label("AirDrop", systemImage: "dot.radiowaves.left.and.right")
        }

        Divider()

        Button { model.copy(selectedItems) } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        Button { model.cut(selectedItems) } label: {
            Label("Cut", systemImage: "scissors")
        }
        if model.canPaste() {
            Button { model.paste() } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
        }

        Divider()

        if selectedItems.count == 1 {
            Button { promptRename(first) } label: {
                Label("Rename", systemImage: "pencil")
            }
        }
        Button { model.compress(selectedItems) } label: {
            Label("Compress to ZIP", systemImage: "archivebox")
        }

        Divider()

        Button { promptNewFolder() } label: {
            Label("New Folder", systemImage: "folder.badge.plus")
        }
        Button { promptNewFile() } label: {
            Label("New File", systemImage: "doc.badge.plus")
        }

        let ext = first.url.pathExtension
        let ctx: WFActionContext = first.isDirectory ? .folder : .file
        let matching = model.customActions.filter { $0.matches(ext: ext, context: ctx) }
        if !matching.isEmpty {
            Divider()
            ForEach(Array(matching.enumerated()), id: \.offset) { _, action in
                topLevelAction(action, paths: selectedItems.map { $0.url.path })
            }
        }

        Divider()

        Button(role: .destructive) { confirmDelete(selectedItems) } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack {
            Text("\(model.displayed.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !model.selection.isEmpty {
                Text("\(model.selection.count) selected")
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
            title: String(localized: "Rename"),
            message: String(format: String(localized: "New name for \"%@\":"), item.displayName),
            defaultValue: item.displayName,
            confirmLabel: String(localized: "Rename")
        ) { newName in
            if newName != item.name { model.rename(item, to: newName) }
        }
    }

    private func promptNewFolder() {
        nsPrompt(
            title: String(localized: "New Folder"),
            message: String(localized: "Folder name:"),
            defaultValue: String(localized: "New Folder"),
            confirmLabel: String(localized: "Create")
        ) { model.createFolder(named: $0) }
    }

    private func promptNewFile() {
        nsPrompt(
            title: String(localized: "New File"),
            message: String(localized: "File name:"),
            defaultValue: String(localized: "Untitled.txt"),
            confirmLabel: String(localized: "Create")
        ) { model.createFile(named: $0) }
    }

    private func confirmDelete(_ items: [FileItem]) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let alert = NSAlert()
            let label = items.count == 1
                ? "\"\(items[0].name)\""
                : String(format: String(localized: "%lld items"), Int64(items.count))
            alert.messageText = String(format: String(localized: "Move %@ to Trash?"), label)
            alert.alertStyle = .warning
            alert.addButton(withTitle: String(localized: "Move to Trash"))
            alert.addButton(withTitle: String(localized: "Cancel"))
            if alert.runModal() == .alertFirstButtonReturn {
                model.delete(items)
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
            alert.addButton(withTitle: String(localized: "Cancel"))
            let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            tf.stringValue = defaultValue
            alert.accessoryView = tf
            alert.window.initialFirstResponder = tf
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: alert.window,
                queue: .main
            ) { _ in
                tf.selectText(nil)
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
            }
            if alert.runModal() == .alertFirstButtonReturn {
                let value = tf.stringValue.trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { action(value) }
            }
        }
    }

    // MARK: - File icon

    private func appDisplayName(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }
}

// MARK: - FileIconView

struct FileIconView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.imageAlignment = .alignCenter
        view.wantsLayer = true
        view.layer?.contentsGravity = .resizeAspect
        view.image = NSWorkspace.shared.icon(forFile: url.path)
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - ChevronMenuView

struct ChevronMenuView: View {
    let subdirectories: [String]
    let onNavigate: (String) -> Void

    @State private var isMenuOpen = false

    var body: some View {
        ZStack {
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(
                    subdirectories.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary)
                )
                .rotationEffect(.degrees(isMenuOpen ? 90 : 0))
                .animation(.easeInOut(duration: 0.15), value: isMenuOpen)
                .allowsHitTesting(false)

            if !subdirectories.isEmpty {
                NSMenuButton(
                    subdirectories: subdirectories,
                    onOpen:   { isMenuOpen = true  },
                    onClose:  { isMenuOpen = false },
                    onSelect: onNavigate
                )
                .opacity(0.001)
            }
        }
        .frame(width: 14, height: 22)
    }
}

// MARK: - NSMenuButton

struct NSMenuButton: NSViewRepresentable {
    let subdirectories: [String]
    let onOpen:   () -> Void
    let onClose:  () -> Void
    let onSelect: (String) -> Void

    func makeNSView(context: Context) -> NSButton {
        let btn = NSButton()
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.title = ""
        btn.target = context.coordinator
        btn.action = #selector(Coordinator.showMenu(_:))
        return btn
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, NSMenuDelegate {
        var parent: NSMenuButton

        init(parent: NSMenuButton) { self.parent = parent }

        @objc func showMenu(_ sender: NSButton) {
            let menu = NSMenu()
            menu.delegate = self
            for sub in parent.subdirectories {
                let item = NSMenuItem(
                    title: sub,
                    action: #selector(pick(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                menu.addItem(item)
            }
            parent.onOpen()
            menu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: sender.bounds.height),
                in: sender
            )
        }

        @objc func pick(_ item: NSMenuItem) {
            parent.onSelect(item.title)
        }

        func menuDidClose(_ menu: NSMenu) {
            DispatchQueue.main.async { self.parent.onClose() }
        }
    }
}

#Preview {
    ContentView()
}
