//
//  MinecraftServerViewerApp.swift
//  MinecraftServerViewer
//
//  Created by BrianRen on 2026/4/26.
//

import SwiftUI

@main
struct MinecraftServerViewerApp: App {
    @State private var store: ServerStore

    init() {
        AppSettings.registerDefaults()
        _store = State(initialValue: ServerStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        Settings {
            SettingsView(store: store)
        }
    }
}
