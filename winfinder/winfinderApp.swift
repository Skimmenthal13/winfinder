//
//  winfinderApp.swift
//  winfinder
//
//  Created by Vincenzo Schimmenti on 29/05/26.
//

import SwiftUI

extension Notification.Name {
    static let openExtensionsManager = Notification.Name("winfinder.openExtensionsManager")
}

@main
struct winfinderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
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
