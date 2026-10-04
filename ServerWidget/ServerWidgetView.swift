//
//  ServerWidgetView.swift
//  ServerWidget
//

import AppIntents
import SwiftUI
import WidgetKit

struct ServerWidgetView: View {
    let entry: ServerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if entry.isEmpty {
            ContentUnavailableView {
                Label("尚無伺服器", systemImage: "server.rack")
            } description: {
                Text("在 App 中新增伺服器後就會顯示在這裡。")
            }
        } else if family == .systemSmall, let server = entry.servers.first {
            SmallServerView(server: server)
        } else {
            ServerListView(servers: entry.servers, date: entry.date, showsHeader: family == .systemLarge)
        }
    }
}

/// One server: name, online state, players and latency.
private struct SmallServerView: View {
    let server: ServerStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ServerIcon(server: server, size: 30, cornerRadius: 6)
                StatusDot(server: server, size: 10)
                Spacer(minLength: 0)
                RefreshButton()
            }
            Text(server.serverName)
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 0)
            if server.online {
                Text("\(server.playersOnline) / \(server.playersMax)")
                    .invalidatableContent()
                    .font(.title2.bold().monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let latency = server.latency {
                        PingBars(latency: latency)
                        Text("\(latency) ms")
                    }
                }
                .invalidatableContent()
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            } else {
                Text("離線")
                    .font(.title2.bold())
                    .foregroundStyle(.red)
                Text(server.address.description)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ServerListView: View {
    let servers: [ServerStatus]
    let date: Date
    let showsHeader: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsHeader {
                HStack {
                    Text("伺服器狀態")
                        .font(.headline)
                    Spacer()
                    Text("\(servers.filter(\.online).count) / \(servers.count) 在線")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(servers) { server in
                ServerListRow(server: server)
                    .invalidatableContent()
            }
            Spacer(minLength: 0)
            HStack {
                Text("更新於 \(date, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                RefreshButton()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ServerListRow: View {
    let server: ServerStatus

    var body: some View {
        HStack(spacing: 8) {
            ServerIcon(server: server, size: 24, cornerRadius: 5)
            VStack(alignment: .leading, spacing: 0) {
                Text(server.serverName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(server.online ? "\(server.playersOnline) / \(server.playersMax) 位玩家" : "離線")
                    .font(.caption)
                    .foregroundStyle(server.online ? Color.secondary : Color.red)
            }
            Spacer(minLength: 4)
            if server.online, let latency = server.latency {
                Text("\(latency) ms")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                PingBars(latency: latency)
            } else {
                StatusDot(server: server)
            }
        }
    }
}

/// Re-checks the servers shown in this widget.
private struct RefreshButton: View {
    var body: some View {
        Button(intent: RefreshServersIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("重新整理")
    }
}

#Preview(as: .systemSmall) {
    ServerWidget()
} timeline: {
    ServerEntry(date: .now, servers: [ServerStatus.samples[0]])
    ServerEntry(date: .now, servers: [ServerStatus.samples[3]])
}

#Preview(as: .systemMedium) {
    ServerWidget()
} timeline: {
    ServerEntry(date: .now, servers: Array(ServerStatus.samples.prefix(3)))
}
