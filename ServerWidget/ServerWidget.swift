//
//  ServerWidget.swift
//  ServerWidget
//

import SwiftUI
import WidgetKit

@main
struct ServerWidgetBundle: WidgetBundle {
    var body: some Widget {
        ServerWidget()
    }
}

struct ServerWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: ServerWidgetKind.status, intent: SelectServerIntent.self, provider: ServerTimelineProvider()) { entry in
            ServerWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("伺服器狀態")
        .description("顯示 Minecraft 伺服器是否在線、玩家人數與延遲。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ServerEntry: TimelineEntry {
    let date: Date
    let servers: [ServerStatus]
    /// The app has no servers saved yet.
    var isEmpty: Bool { servers.isEmpty }
}

struct ServerTimelineProvider: AppIntentTimelineProvider {
    /// WidgetKit decides the real schedule; this is the refresh it asks for.
    private static let refreshInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> ServerEntry {
        ServerEntry(date: .now, servers: Array(ServerStatus.samples.prefix(capacity(for: context.family))))
    }

    /// Gallery previews and quick snapshots show the last saved status without pinging.
    func snapshot(for configuration: SelectServerIntent, in context: Context) async -> ServerEntry {
        if context.isPreview {
            return placeholder(in: context)
        }
        let servers = await selectedServers(for: configuration, family: context.family)
        return ServerEntry(date: .now, servers: servers)
    }

    func timeline(for configuration: SelectServerIntent, in context: Context) async -> Timeline<ServerEntry> {
        let saved = await selectedServers(for: configuration, family: context.family)
        let checked = await Self.check(saved)
        let entry = ServerEntry(date: .now, servers: checked)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(Self.refreshInterval)))
    }

    private func capacity(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: 1
        case .systemMedium: 3
        default: 6
        }
    }

    private func selectedServers(for configuration: SelectServerIntent, family: WidgetFamily) async -> [ServerStatus] {
        let all = await MainActor.run { ServerPersistence.standard.load() ?? [] }
        if family == .systemSmall, let id = configuration.server?.id, let server = all.first(where: { $0.id == id }) {
            return [server]
        }
        return Array(all.prefix(capacity(for: family)))
    }

    /// How old the app's saved result may be and still stand in for a failed check.
    nonisolated private static let savedStatusMaxAge: TimeInterval = 10 * 60

    /// Pings every server concurrently. LAN servers are not pinged: the widget cannot
    /// get the Local Network permission, so it shows what the app (which has it) saved.
    /// Other failures also fall back to a recent saved result before reporting offline.
    private static func check(_ servers: [ServerStatus]) async -> [ServerStatus] {
        await withTaskGroup(of: (Int, ServerStatus).self) { group in
            for (index, server) in servers.enumerated() {
                group.addTask {
                    if server.address.isOnLocalNetwork {
                        return (index, server)
                    }
                    do {
                        return (index, try await MinecraftServerStatusService().fetchStatus(of: server))
                    } catch {
                        if let checked = server.lastChecked, Date.now.timeIntervalSince(checked) < savedStatusMaxAge {
                            return (index, server)
                        }
                        var failed = server
                        failed.online = false
                        failed.errorMessage = error.localizedDescription
                        failed.lastChecked = .now
                        return (index, failed)
                    }
                }
            }
            var results = servers
            for await (index, server) in group {
                results[index] = server
            }
            return results
        }
    }
}

enum ServerWidgetKind {
    static let status = "ServerStatusWidget"
}
