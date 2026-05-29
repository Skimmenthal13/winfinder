//
//  winfinderApp.swift
//  winfinder
//
//  Created by Vincenzo Schimmenti on 29/05/26.
//

import SwiftUI

@main
struct winfinderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentMinSize)
    }
}
