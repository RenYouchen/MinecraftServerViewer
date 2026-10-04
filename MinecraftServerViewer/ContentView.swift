//
//  ContentView.swift
//  MinecraftServerViewer
//
//  Created by BrianRen on 2026/4/26.
//

import SwiftUI

struct ContentView: View {
    let store: ServerStore
    @State private var selection: ServerStatus.ID?
    @State private var isAddingServer = false
    @State private var editingServer: ServerStatus?

    var body: some View {
        NavigationSplitView {
            ServerSidebar(store: store, selection: $selection) {
                isAddingServer = true
            } onEdit: { server in
                editingServer = server
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 270, max: 340)
        } detail: {
            if let server = store.server(with: selection) {
                ServerDetailView(server: server, isRefreshing: store.refreshingIDs.contains(server.id)) {
                    Task { await store.refresh(server.id) }
                } onChangeInterval: { interval in
                    store.setRefreshInterval(interval, for: server.id)
                }
            } else {
                ContentUnavailableView(
                    "尚未選擇伺服器",
                    systemImage: "server.rack",
                    description: Text("從側邊欄選擇一台伺服器以查看狀態。")
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await store.refreshAll() }
                } label: {
                    Label(store.isRefreshing ? "更新中…" : "重新整理", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRefreshing)
                .keyboardShortcut("r")
                .help("重新整理所有伺服器")

                Button {
                    isAddingServer = true
                } label: {
                    Label("新增伺服器", systemImage: "plus")
                }
                .keyboardShortcut("n")
                .help("新增伺服器")
            }
        }
        .sheet(isPresented: $isAddingServer) {
            ServerFormSheet(store: store) { server in
                store.add(server)
                selection = server.id
                if server.lastChecked == nil {
                    Task { await store.refresh(server.id) }
                }
            }
        }
        .sheet(item: $editingServer) { original in
            ServerFormSheet(store: store, editing: original) { server in
                store.update(server)
                if server.lastChecked == nil {
                    Task { await store.refresh(server.id) }
                }
            }
        }
        .task {
            if selection == nil {
                selection = store.servers.first?.id
            }
            // Saved status shows immediately; bring every server up to date once on launch.
            if AppSettings.refreshOnLaunch {
                await store.refreshAll()
            }
            while !Task.isCancelled {
                await store.refreshDue()
                try? await Task.sleep(for: .seconds(1)) // finest refresh interval offered
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    ContentView(store: ServerStore(persistence: nil))
}
