import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Bindable var model: FileExplorerModel
    @State private var selection: String? = nil
    @State private var dropTargetPath: String? = nil

    private let fm = FileManager.default

    private var homePath: String { fm.homeDirectoryForCurrentUser.path }
    private var homeName: String { fm.homeDirectoryForCurrentUser.lastPathComponent }

    private var favoriteItems: [(name: String, icon: String, path: String)] {
        [
            ("Desktop",   "menubar.dock.rectangle", folderPath(.desktopDirectory)),
            ("Documenti", "doc.fill",                folderPath(.documentDirectory)),
            ("Download",  "arrow.down.circle.fill",  folderPath(.downloadsDirectory)),
            ("Immagini",  "photo.fill",               folderPath(.picturesDirectory)),
        ].filter { !$0.path.isEmpty }
    }

    var body: some View {
        List(selection: $selection) {

            // MARK: Preferiti
            Section("Preferiti") {
                ForEach(favoriteItems, id: \.path) { item in
                    dropRow(name: item.name, icon: item.icon, path: item.path)
                }
            }

            // MARK: Posizioni
            Section("Posizioni") {
                dropRow(name: homeName, icon: "house.fill", path: homePath)
                dropRow(name: "Macintosh HD", icon: "internaldrive.fill", path: "/")
            }

            // MARK: Dispositivi
            if !model.mountedVolumes.isEmpty {
                Section("Dispositivi") {
                    ForEach(model.mountedVolumes, id: \.path) { url in
                        dropRow(name: volumeName(url), icon: volumeIcon(url), path: url.path)
                    }
                }
            }

            // MARK: Recenti
            let recents = model.validRecentPaths
            if !recents.isEmpty {
                Section("Recenti") {
                    ForEach(recents, id: \.self) { path in
                        dropRow(
                            name: URL(fileURLWithPath: path).lastPathComponent,
                            icon: "clock",
                            path: path
                        )
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: selection) { _, path in
            guard let path else { return }
            model.navigate(to: path)
        }
        .onChange(of: model.currentPath) { _, path in
            let knownPaths: Set<String> = Set(
                favoriteItems.map(\.path)
                + [homePath, "/"]
                + model.mountedVolumes.map(\.path)
                + model.validRecentPaths
            )
            if knownPaths.contains(path) {
                selection = path
            }
        }
    }

    // MARK: - Drop row

    @ViewBuilder
    private func dropRow(name: String, icon: String, path: String) -> some View {
        let isTarget = dropTargetPath == path
        Label(name, systemImage: icon)
            .tag(path)
            .listRowBackground(
                isTarget
                    ? RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.accentColor, lineWidth: 1.5)
                        )
                    : nil
            )
            .onDrop(
                of: [UTType.winfinderFiles, UTType.fileURL],
                isTargeted: Binding(
                    get: { dropTargetPath == path },
                    set: { active in
                        dropTargetPath = active ? path : (dropTargetPath == path ? nil : dropTargetPath)
                    }
                )
            ) { providers in
                let shouldCopy = NSEvent.modifierFlags.contains(.command)
                loadDroppedURLs(from: providers) { urls in
                    guard !urls.isEmpty else { return }
                    model.moveFiles(urls, to: path, copy: shouldCopy)
                }
                dropTargetPath = nil
                return true
            }
    }

    // MARK: - Helpers

    private func folderPath(_ dir: FileManager.SearchPathDirectory) -> String {
        fm.urls(for: dir, in: .userDomainMask).first?.path ?? ""
    }

    private func volumeName(_ url: URL) -> String {
        (try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? url.lastPathComponent
    }

    private func volumeIcon(_ url: URL) -> String {
        let rv = try? url.resourceValues(forKeys: [.volumeIsRemovableKey])
        return rv?.volumeIsRemovable == true ? "externaldrive.fill" : "internaldrive.fill"
    }
}
