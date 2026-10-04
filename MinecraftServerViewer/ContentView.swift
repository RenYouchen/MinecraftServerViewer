//
//  ContentView.swift
//  MinecraftServerViewer
//
//  Created by BrianRen on 2026/4/26.
//

import SwiftUI

struct ContentView: View {

    var body: some View {
        VStack(spacing: 20) {
            Text("Hello, World!")
                .font(.largeTitle)
                .foregroundColor(.blue)

            Text("Minecraft Server Viewer")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}
#Preview {
    ContentView()
}
