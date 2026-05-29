import SwiftUI

struct SidebarView: View {
    @Bindable var model: FileExplorerModel
    @State private var selection: String? = nil

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
                    Label(item.name, systemImage: item.icon)
                        .tag(item.path)
                }
            }

            // MARK: Posizioni
            Section("Posizioni") {
                Label(homeName, systemImage: "house.fill")
                    .tag(homePath)
                Label("Macintosh HD", systemImage: "internaldrive.fill")
                    .tag("/")
            }

            // MARK: Dispositivi
            if !model.mountedVolumes.isEmpty {
                Section("Dispositivi") {
                    ForEach(model.mountedVolumes, id: \.path) { url in
                        Label(volumeName(url), systemImage: volumeIcon(url))
                            .tag(url.path)
                    }
                }
            }

            // MARK: Recenti
            let recents = model.validRecentPaths
            if !recents.isEmpty {
                Section("Recenti") {
                    ForEach(recents, id: \.self) { path in
                        Label(URL(fileURLWithPath: path).lastPathComponent, systemImage: "clock")
                            .tag(path)
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
            // Sync highlight when navigating from the main pane
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
