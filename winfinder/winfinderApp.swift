import SwiftUI
import Sparkle
import CoreServices

extension Notification.Name {
    static let openExtensionsManager = Notification.Name("winfinder.openExtensionsManager")
    static let navigateToPath = Notification.Name("winfinder.navigateToPath")
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Owned here (reference type, app-lifetime) so the Sparkle scheduler is never torn down.
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard UserDefaults.standard.bool(forKey: "winfinder.useAsDefaultFolderHandler"),
              let bundleID = Bundle.main.bundleIdentifier else { return }
        LSSetDefaultRoleHandlerForContentType(
            "public.folder" as CFString,
            .viewer,
            bundleID as CFString
        )
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "winfinder" {
                handleSchemeURL(url)
            } else if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                navigate(to: url.path)
                break
            }
        }
    }

    // MARK: - URL scheme

    private func handleSchemeURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host,
              host == "reveal" || host == "open",
              let path = components.queryItems?.first(where: { $0.name == "path" })?.value,
              !path.isEmpty
        else { return }
        navigate(to: path)
    }

    private func navigate(to path: String) {
        NotificationCenter.default.post(name: .navigateToPath, object: path)
    }
}

// MARK: - App

@main
struct winfinderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    appDelegate.updaterController.checkForUpdates(nil)
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    DispatchQueue.main.async {
                        print("[Settings DEBUG] window count: \(NSApp.windows.count)")
                        for (i, w) in NSApp.windows.enumerated() {
                            print("""
                                [Settings DEBUG] [\(i)] \
                                class=\(type(of: w)) \
                                title="\(w.title)" \
                                isKey=\(w.isKeyWindow) \
                                isMain=\(w.isMainWindow) \
                                canBecomeKey=\(w.canBecomeKey) \
                                isVisible=\(w.isVisible) \
                                isPanel=\(w is NSPanel)
                                """)
                        }
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.windows
                            .first { !($0 is NSPanel) && $0 !== NSApp.mainWindow && $0.canBecomeKey }?
                            .makeKeyAndOrderFront(nil)
                    }
                }
                .keyboardShortcut(",", modifiers: .command)
                Divider()
                Button {
                    NotificationCenter.default.post(name: .openExtensionsManager, object: nil)
                } label: {
                    Label("Manage Extensions…", systemImage: "bolt.fill")
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
        }
    }
}
