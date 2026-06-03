import SwiftUI
import Sparkle

extension Notification.Name {
    static let openExtensionsManager = Notification.Name("winfinder.openExtensionsManager")
}

@main
struct winfinderApp: App {
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController.checkForUpdates(nil)
                }
            }
            CommandGroup(after: .appSettings) {
                Divider()
                Button {
                    NotificationCenter.default.post(name: .openExtensionsManager, object: nil)
                } label: {
                    Label("Manage Extensions…", systemImage: "bolt.fill")
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}
