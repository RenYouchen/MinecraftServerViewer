//
//  ServerStatusService.swift
//  MinecraftServerViewer
//

import Foundation
import Network

/// Queries a server and returns its refreshed status.
protocol ServerStatusService {
    func fetchStatus(of server: ServerStatus) async throws -> ServerStatus
}

/// Queries real servers over Network.framework: TCP Server List Ping for
/// Java and RakNet Unconnected Ping over UDP for Bedrock.
struct MinecraftServerStatusService: ServerStatusService {
    func fetchStatus(of server: ServerStatus) async throws -> ServerStatus {
        let address = server.address
        guard !address.host.isEmpty else { throw ServerStatusError.invalidURL }

        var host = address.host
        var port = address.resolvedPort(for: server.edition)
        var resolvedAddress: String?
        // Like the Java client: an address without a port may point elsewhere via SRV.
        if server.edition == .java, address.port == nil, !Self.isIPLiteral(host),
           let target = await SRVResolver.resolve("_minecraft._tcp.\(host)") {
            host = target.host
            port = target.port
            resolvedAddress = ServerAddress(host: target.host, port: target.port).description
        }

        let timeout = Duration.seconds(AppSettings.connectionTimeout)
        let result = switch server.edition {
        case .java: try await JavaStatusPinger.ping(host: host, port: port, timeout: timeout)
        case .bedrock: try await BedrockStatusPinger.ping(host: host, port: port, timeout: timeout)
        }

        var updated = server
        updated.online = true
        updated.version = result.version
        updated.protocolVersion = result.protocolVersion
        updated.motd = result.motd
        updated.favicon = result.favicon
        updated.resolvedAddress = resolvedAddress
        updated.playersOnline = result.playersOnline
        updated.playersMax = result.playersMax
        updated.players = result.players
        updated.latency = result.latency
        updated.pingHistory = Array((server.pingHistory + [result.latency]).suffix(AppSettings.pingHistoryLength))
        updated.errorMessage = nil
        updated.lastChecked = .now
        return updated
    }

    private static func isIPLiteral(_ host: String) -> Bool {
        IPv4Address(host) != nil || IPv6Address(host) != nil
    }
}

/// Stand-in until the real protocol is implemented: simulates a round trip,
/// jitters the latency of known online servers and treats never-checked
/// servers as reachable so the Add Server flow can be exercised.
struct MockServerStatusService: ServerStatusService {
    func fetchStatus(of server: ServerStatus) async throws -> ServerStatus {
        try await Task.sleep(for: .milliseconds(Int.random(in: 400...900)))

        let neverChecked = server.lastChecked == nil
        guard server.online || neverChecked else { throw ServerStatusError.timeout }

        var updated = server
        updated.online = true
        let base = server.latency ?? Int.random(in: 20...120)
        let latency = max(1, base + Int.random(in: -base / 5...base / 5 + 1))
        updated.latency = latency
        updated.pingHistory = Array((server.pingHistory + [latency]).suffix(AppSettings.pingHistoryLength))
        updated.errorMessage = nil
        updated.lastChecked = .now
        return updated
    }
}
