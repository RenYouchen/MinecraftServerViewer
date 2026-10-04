//
//  ServerStore.swift
//  MinecraftServerViewer
//

import Foundation
import Observation
import WidgetKit

@Observable
final class ServerStore {
    /// Saved on every change, so settings and the last known status survive relaunch.
    var servers: [ServerStatus] {
        didSet { save() }
    }
    private(set) var refreshingIDs: Set<ServerStatus.ID> = []

    private let service: any ServerStatusService
    private let persistence: ServerPersistence?

    /// Without `servers`, starts from the saved list, or the defaults on first launch.
    /// Pass `persistence: nil` to keep everything in memory (previews, tests).
    init(
        servers: [ServerStatus]? = nil,
        service: any ServerStatusService = MinecraftServerStatusService(),
        persistence: ServerPersistence? = .standard
    ) {
        self.servers = servers ?? persistence?.load() ?? ServerStatus.defaults
        self.service = service
        self.persistence = persistence
    }

    var isRefreshing: Bool { !refreshingIDs.isEmpty }

    func server(with id: ServerStatus.ID?) -> ServerStatus? {
        servers.first { $0.id == id }
    }

    func add(_ server: ServerStatus) {
        servers.append(server)
        reloadWidgets()
    }

    /// Saves edited settings. If the address and edition are unchanged, only the
    /// settings are applied so a status refreshed meanwhile is not overwritten.
    func update(_ server: ServerStatus) {
        guard var current = self.server(with: server.id),
              current.address == server.address,
              current.edition == server.edition,
              (current.lastChecked ?? .distantPast) >= (server.lastChecked ?? .distantPast) else {
            // New target, or the sheet's connection test is newer than the stored status.
            replace(server)
            reloadWidgets()
            return
        }
        current.serverName = server.serverName
        current.iconStyle = server.iconStyle
        current.refreshInterval = server.refreshInterval
        replace(current)
        reloadWidgets()
    }

    /// `nil` turns auto-refresh off.
    func setRefreshInterval(_ interval: TimeInterval?, for id: ServerStatus.ID) {
        guard var server = server(with: id) else { return }
        server.refreshInterval = interval
        replace(server)
    }

    /// Applies one interval to every server; `nil` turns auto-refresh off.
    func setRefreshIntervalForAll(_ interval: TimeInterval?) {
        var updated = servers
        for index in updated.indices {
            updated[index].refreshInterval = interval
        }
        servers = updated // one assignment, so one save
    }

    /// Replaces the list with the built-in defaults (unchecked, so the next refresh queries them).
    func resetToDefaults() {
        servers = ServerStatus.defaults
        reloadWidgets()
    }

    func remove(_ id: ServerStatus.ID) {
        servers.removeAll { $0.id == id }
        reloadWidgets()
    }

    func refreshAll() async {
        await refresh(servers.map(\.id))
    }

    /// Refreshes servers whose auto-refresh interval has elapsed.
    func refreshDue(now: Date = .now) async {
        let due = servers.filter { server in
            guard let interval = server.refreshInterval else { return false }
            return now.timeIntervalSince(server.lastChecked ?? .distantPast) >= interval
        }
        await refresh(due.map(\.id))
    }

    private func refresh(_ ids: [ServerStatus.ID]) async {
        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask { await self.refresh(id) }
            }
        }
    }

    func refresh(_ id: ServerStatus.ID) async {
        guard let server = server(with: id), !refreshingIDs.contains(id) else { return }
        refreshingIDs.insert(id)
        defer { refreshingIDs.remove(id) }

        do {
            let updated = try await service.fetchStatus(of: server)
            applyStatus(updated)
        } catch {
            var failed = server
            failed.online = false
            failed.errorMessage = error.localizedDescription
            failed.lastChecked = .now
            applyStatus(failed)
        }
    }

    /// One-off check used by the Add Server sheet before the server is saved.
    func test(_ server: ServerStatus) async throws -> ServerStatus {
        try await service.fetchStatus(of: server)
    }

    /// Stores a refresh result, keeping settings the user may have edited
    /// while it was in flight. Results for an old address are dropped.
    private func applyStatus(_ result: ServerStatus) {
        guard let current = server(with: result.id),
              current.address == result.address,
              current.edition == result.edition else { return }
        var merged = result
        merged.serverName = current.serverName
        merged.iconStyle = current.iconStyle
        merged.refreshInterval = current.refreshInterval
        replace(merged)
    }

    private func replace(_ server: ServerStatus) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }
        servers[index] = server
    }

    /// The widget pings servers on its own schedule; it only needs a nudge when the list changes.
    private func reloadWidgets() {
        guard persistence != nil else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func save() {
        guard let persistence else { return }
        do {
            try persistence.save(servers)
        } catch {
            print("Failed to save servers: \(error)")
        }
    }
}
