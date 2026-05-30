import SwiftUI
import UniformTypeIdentifiers

// MARK: - WFMenuNode

@Observable
final class WFMenuNode: Identifiable {
    let id = UUID()

    enum NodeType: String, CaseIterable {
        case command   = "Command"
        case separator = "Separator"
        case submenu   = "Submenu"

        var icon: String {
            switch self {
            case .command:   "terminal"
            case .separator: "minus"
            case .submenu:   "list.triangle"
            }
        }
    }

    var type:     NodeType
    var name:     String
    var command:  String
    var children: [WFMenuNode]
    var iconURL:  URL?

    init(type: NodeType = .command, name: String = "", command: String = "") {
        self.type = type; self.name = name; self.command = command; self.children = []; self.iconURL = nil
    }

    func toDict() -> [String: Any]? {
        switch type {
        case .separator:
            return ["separator": true]
        case .command:
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            var dict: [String: Any] = ["name": name, "command": command]
            if let url = iconURL { dict["icon"] = url.path }
            return dict
        case .submenu:
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            var dict: [String: Any] = ["name": name, "submenu": children.compactMap { $0.toDict() }]
            if let url = iconURL { dict["icon"] = url.path }
            return dict
        }
    }

    static func fromDict(_ dict: [String: Any]) -> WFMenuNode? {
        if dict["separator"] as? Bool == true { return WFMenuNode(type: .separator) }
        guard let name = dict["name"] as? String else { return nil }
        let node = WFMenuNode()
        node.name = name
        if let iconPath = dict["icon"] as? String { node.iconURL = URL(fileURLWithPath: iconPath) }
        if let cmd = dict["command"] as? String {
            node.type = .command; node.command = cmd
        } else if let sub = dict["submenu"] as? [[String: Any]] {
            node.type = .submenu; node.children = sub.compactMap { WFMenuNode.fromDict($0) }
        }
        return node
    }
}

// MARK: - MenuNodeRow

struct MenuNodeRow: View {
    @Bindable var node: WFMenuNode
    let depth: Int
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: CGFloat(depth) * 18, height: 1)

            Menu {
                ForEach(WFMenuNode.NodeType.allCases, id: \.self) { t in
                    Button { node.type = t } label: { Label(t.rawValue, systemImage: t.icon) }
                }
            } label: {
                Image(systemName: node.type.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .fixedSize()

            switch node.type {
            case .separator:
                Divider()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            case .command:
                TextField("Item name", text: $node.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                TextField("Command {file}", text: $node.command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minWidth: 60)
                iconButton
            case .submenu:
                TextField("Submenu name", text: $node.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 100)
                iconButton
            }

            Spacer(minLength: 2)

            if node.type == .submenu {
                Button { node.children.append(WFMenuNode()) } label: {
                    Image(systemName: "plus.circle").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Add child item")
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle").foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var iconButton: some View {
        if let url = node.iconURL, let img = NSImage(contentsOf: url) {
            HStack(spacing: 2) {
                Button { pickNodeIcon() } label: {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .cornerRadius(2)
                }
                .buttonStyle(.plain)
                .help("Change icon")
                Button { node.iconURL = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove icon")
            }
        } else {
            Button { pickNodeIcon() } label: {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help("Choose icon")
        }
    }

    private func pickNodeIcon() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose Icon")
        panel.allowedContentTypes = [.png]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK { node.iconURL = panel.url }
    }
}

// MARK: - ChildrenView

struct ChildrenView: View {
    @Bindable var node: WFMenuNode
    let depth: Int

    var body: some View {
        MenuTreeEditor(nodes: $node.children, depth: depth)
    }
}

// MARK: - MenuTreeEditor

struct MenuTreeEditor: View {
    @Binding var nodes: [WFMenuNode]
    var depth: Int = 0

    var body: some View {
        ForEach(nodes) { node in
            MenuNodeRow(node: node, depth: depth, onDelete: {
                nodes.removeAll { $0.id == node.id }
            })
            if node.type == .submenu {
                ChildrenView(node: node, depth: depth + 1)
            }
        }
        .onMove { from, to in nodes.move(fromOffsets: from, toOffset: to) }
    }
}

// MARK: - NewExtensionForm

struct NewExtensionForm: View {
    @Bindable var model: FileExplorerModel
    var editingEntry: WFActionEntryInfo? = nil
    @State private var name = ""
    @State private var extensionsText = "*"
    @State private var ctxFile       = true
    @State private var ctxFolder     = true
    @State private var ctxBackground = false
    @State private var isSubmenu     = false
    @State private var command       = ""
    @State private var submenuNodes: [WFMenuNode] = []
    @State private var iconURL: URL?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey(editingEntry == nil ? "New Extension" : "Edit Extension"))
                .font(.headline)
                .padding(.bottom, 14)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Name").gridColumnAlignment(.trailing)
                    TextField("E.g. Open with TextEdit", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Extensions").gridColumnAlignment(.trailing)
                    TextField("pdf, txt, * (all)", text: $extensionsText)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Context").gridColumnAlignment(.trailing)
                    HStack(spacing: 12) {
                        Toggle("File",       isOn: $ctxFile)
                        Toggle("Folder",     isOn: $ctxFolder)
                        Toggle("Background", isOn: $ctxBackground)
                    }
                }
                GridRow {
                    Text("Action type").gridColumnAlignment(.trailing)
                    Picker("", selection: $isSubmenu) {
                        Text("Command").tag(false)
                        Text("Submenu").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .onChange(of: isSubmenu) { _, new in
                        if new && submenuNodes.isEmpty { submenuNodes = [WFMenuNode()] }
                    }
                }
                GridRow {
                    Text("Icon").gridColumnAlignment(.trailing)
                    HStack(spacing: 8) {
                        if let url = iconURL, let img = NSImage(contentsOf: url) {
                            Image(nsImage: img).resizable().scaledToFit().frame(width: 20, height: 20)
                            Text(url.lastPathComponent).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Button("Choose…") { pickIcon() }
                        if iconURL != nil { Button("Remove") { iconURL = nil }.foregroundStyle(.secondary) }
                    }
                }
            }

            if isSubmenu {
                submenuSection
            } else {
                commandSection
            }

            if let err = errorMessage {
                Text(err).foregroundStyle(.red).font(.caption).padding(.top, 6)
            }

            Spacer(minLength: 12)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(LocalizedStringKey(editingEntry == nil ? "Create" : "Save")) { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                              (!isSubmenu && command.trimmingCharacters(in: .whitespaces).isEmpty))
            }
        }
        .padding(22)
        .frame(width: 520)
        .onAppear { if let e = editingEntry { loadForEditing(e) } }
    }

    private var commandSection: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                Text("Command").gridColumnAlignment(.trailing)
                TextField("open -a TextEdit {file}", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .padding(.top, 10)
    }

    private var submenuSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Menu items")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 10)

            List {
                MenuTreeEditor(nodes: $submenuNodes)
                Button {
                    submenuNodes.append(WFMenuNode())
                } label: {
                    Label("Add item", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .frame(height: 190)
            .border(Color(NSColor.separatorColor), width: 0.5)
        }
    }

    private func pickIcon() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose Icon")
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK { iconURL = panel.url }
    }

    private func loadForEditing(_ entry: WFActionEntryInfo) {
        let jsonURL = entry.isFolder
            ? entry.url.appendingPathComponent("action.json")
            : entry.url
        guard let data = try? Data(contentsOf: jsonURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        name = json["name"] as? String ?? entry.displayName
        if let exts = json["extensions"] as? [String] {
            extensionsText = exts.joined(separator: ", ")
        }
        if let ctxArr = json["context"] as? [String] {
            ctxFile       = ctxArr.contains("file")
            ctxFolder     = ctxArr.contains("folder")
            ctxBackground = ctxArr.contains("background")
        }
        if let cmd = json["command"] as? String {
            isSubmenu = false
            command = cmd
        } else if let sub = json["submenu"] as? [[String: Any]] {
            submenuNodes = sub.compactMap { WFMenuNode.fromDict($0) }
            isSubmenu = true
        }
        if entry.isFolder {
            let existingIcon = entry.url.appendingPathComponent("icon.png")
            if FileManager.default.fileExists(atPath: existingIcon.path) { iconURL = existingIcon }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let exts = extensionsText.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        var contexts: Set<WFActionContext> = []
        if ctxFile       { contexts.insert(.file) }
        if ctxFolder     { contexts.insert(.folder) }
        if ctxBackground { contexts.insert(.background) }
        guard !contexts.isEmpty else { errorMessage = String(localized: "Select at least one context."); return }
        let finalExts = exts.isEmpty ? ["*"] : exts
        do {
            if let entry = editingEntry {
                if isSubmenu {
                    try model.updateAction(entry: entry, name: trimmedName, extensions: finalExts,
                                           contexts: contexts, submenuItems: submenuNodes.compactMap { $0.toDict() },
                                           newIconURL: iconURL)
                } else {
                    try model.updateAction(entry: entry, name: trimmedName, extensions: finalExts,
                                           contexts: contexts, command: command.trimmingCharacters(in: .whitespaces),
                                           newIconURL: iconURL)
                }
            } else {
                if isSubmenu {
                    try model.createAction(name: trimmedName, extensions: finalExts,
                                           contexts: contexts, submenuItems: submenuNodes.compactMap { $0.toDict() },
                                           iconSourceURL: iconURL)
                } else {
                    try model.createAction(name: trimmedName, extensions: finalExts,
                                           contexts: contexts, command: command.trimmingCharacters(in: .whitespaces),
                                           iconSourceURL: iconURL)
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - ExtensionsManagerView

struct ExtensionsManagerView: View {
    @Bindable var model: FileExplorerModel
    @State private var entries: [WFActionEntryInfo] = []
    @State private var showNewForm  = false
    @State private var deleteTarget: WFActionEntryInfo?
    @State private var editTarget:   WFActionEntryInfo?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Extensions")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            Group {
                if entries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bolt.slash").font(.largeTitle).foregroundStyle(.secondary)
                        Text("No extensions").foregroundStyle(.secondary)
                        Text("Add JSON files to\n~/.config/winfinder/actions/")
                            .font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(entries) { entry in
                        HStack(spacing: 10) {
                            if let icon = entry.icon {
                                Image(nsImage: icon).resizable().scaledToFit().frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "bolt.fill").foregroundStyle(.secondary).frame(width: 20, height: 20)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.displayName)
                                Text(entry.isFolder ? LocalizedStringKey("Folder") : LocalizedStringKey("JSON File"))
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(get: { entry.isEnabled },
                                                    set: { _ in model.toggleEntry(entry) }))
                                .toggleStyle(.switch).labelsHidden()
                            Button { editTarget = entry } label: {
                                Image(systemName: "pencil").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Edit")
                            Button { deleteTarget = entry } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .opacity(entry.isEnabled ? 1 : 0.5)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { editTarget = entry }
                    }
                    .listStyle(.plain)
                }
            }

            Divider()

            HStack {
                Button { showNewForm = true } label: {
                    Label("New Extension", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                Spacer()
                Button { NSWorkspace.shared.open(model.actionsDir) } label: {
                    Label("Open Folder", systemImage: "folder")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 520, height: 420)
        .onAppear { reload() }
        .onChange(of: model.customActions.count) { _, _ in reload() }
        .confirmationDialog(
            "Delete \"\(deleteTarget?.displayName ?? "")\"?",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let t = deleteTarget { model.deleteEntry(t) }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        }
        .sheet(isPresented: $showNewForm, onDismiss: reload) {
            NewExtensionForm(model: model)
        }
        .sheet(item: $editTarget, onDismiss: reload) { entry in
            NewExtensionForm(model: model, editingEntry: entry)
        }
    }

    private func reload() { entries = model.loadAllEntries() }
}
