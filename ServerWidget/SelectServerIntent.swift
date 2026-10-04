//
//  SelectServerIntent.swift
//  ServerWidget
//

import AppIntents
import WidgetKit

/// Widget configuration: which server the small widget shows.
struct SelectServerIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "選擇伺服器"
    static let description = IntentDescription("選擇小工具要顯示的伺服器。")

    /// `nil` shows the first server in the app's list.
    @Parameter(title: "伺服器")
    var server: ServerEntity?
}

struct ServerEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "伺服器"
    static let defaultQuery = ServerEntityQuery()

    let id: UUID
    let name: String
    let address: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(address)")
    }
}

struct ServerEntityQuery: EntityQuery {
    func entities(for identifiers: [ServerEntity.ID]) async throws -> [ServerEntity] {
        await savedServers().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ServerEntity] {
        await savedServers()
    }

    func defaultResult() async -> ServerEntity? {
        await savedServers().first
    }

    private func savedServers() async -> [ServerEntity] {
        await MainActor.run {
            (ServerPersistence.standard.load() ?? []).map {
                ServerEntity(id: $0.id, name: $0.serverName, address: $0.address.description)
            }
        }
    }
}

/// Backs the widget's refresh button. WidgetKit reloads the widget's timeline
/// once `perform()` returns, which pings the servers again.
struct RefreshServersIntent: AppIntent {
    static let title: LocalizedStringResource = "重新整理伺服器狀態"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        .result()
    }
}
