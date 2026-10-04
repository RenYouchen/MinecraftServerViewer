//
//  ServerSidebar.swift
//  MinecraftServerViewer
//

import SwiftUI

struct ServerSidebar: View {
    let store: ServerStore
    @Binding var selection: ServerStatus.ID?
    var onAdd: () -> Void
    var onEdit: (ServerStatus) -> Void

    @State private var filter: Filter = .all
    @State private var query = ""

    private enum Filter: Hashable {
        case all, online
    }

    private var visibleServers: [ServerStatus] {
        store.servers.filter { server in
            (filter == .all || server.online)
                && (query.isEmpty
                    || server.serverName.localizedCaseInsensitiveContains(query)
                    || server.address.description.localizedCaseInsensitiveContains(query))
        }
    }

    /// The interval every server shares (inner `nil` = all manual), or `nil` when they differ.
    private var sharedInterval: TimeInterval?? {
        let intervals = Set(store.servers.map(\.refreshInterval))
        return intervals.count <= 1 ? (intervals.first ?? ServerStatus.defaultRefreshInterval) : nil
    }

    var body: some View {
        List(selection: $selection) {
            Section("我的伺服器") {
                ForEach(visibleServers) { server in
                    ServerRow(server: server)
                        .tag(server.id)
                        .contextMenu {
                            Button("重新整理") {
                                Task { await store.refresh(server.id) }
                            }
                            Button("修改伺服器…") {
                                onEdit(server)
                            }
                            Button("複製位址") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(server.address.description, forType: .string)
                            }
                            Divider()
                            Button("移除伺服器", role: .destructive) {
                                store.remove(server.id)
                            }
                        }
                }
            }
        }
        .searchable(text: $query, placement: .sidebar, prompt: "搜尋伺服器")
        .safeAreaInset(edge: .top) {
            Picker("篩選", selection: $filter) {
                Text("全部（\(store.servers.count)）").tag(Filter.all)
                Text("在線（\(store.servers.filter(\.online).count)）").tag(Filter.online)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(action: onAdd) {
                    Label("新增伺服器", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                Spacer()
                RefreshIntervalMenu(
                    interval: sharedInterval ?? nil,
                    isMixed: sharedInterval == nil,
                    label: sharedInterval.map { "\(RefreshIntervalMenu.title(for: $0))更新" } ?? "各伺服器不同"
                ) { interval in
                    store.setRefreshIntervalForAll(interval)
                }
                .menuStyle(.borderlessButton)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("修改所有伺服器的檢測時間")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }
}

struct ServerRow: View {
    let server: ServerStatus

    var body: some View {
        HStack(spacing: 10) {
            ServerIcon(server: server, size: 32, cornerRadius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.serverName)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(server.address.description)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                StatusDot(server: server)
                Text(server.online ? "\(server.latency ?? 0) ms" : "離線")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
