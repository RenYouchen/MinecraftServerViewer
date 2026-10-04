//
//  DataModel.swift
//  MinecraftServerViewer
//

import Foundation

/// Minecraft edition, which decides the status protocol and default port.
nonisolated enum ServerEdition: String, CaseIterable, Identifiable, Codable {
    case java
    case bedrock

    var id: Self { self }

    var displayName: String {
        switch self {
        case .java: "Java 版"
        case .bedrock: "Bedrock 版"
        }
    }

    var defaultPort: Int {
        switch self {
        case .java: 25565
        case .bedrock: 19132
        }
    }

    var protocolNote: String {
        switch self {
        case .java: "Java 版使用 TCP Server List Ping。未指定連接埠時會先查詢 SRV 記錄，查無記錄則使用 25565。"
        case .bedrock: "Bedrock 版使用 RakNet UDP Unconnected Ping，未指定連接埠時使用 19132。"
        }
    }
}

/// A server address as typed by the user: `host`, `host:port`, or `[IPv6]:port`.
nonisolated struct ServerAddress: Hashable, Sendable, Codable, CustomStringConvertible {
    var host: String
    /// `nil` when not given; Java then tries an SRV record before the default port.
    var port: Int?

    init(host: String, port: Int? = nil) {
        self.host = host
        self.port = port
    }

    init?(_ string: String) {
        let text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace) else { return nil }

        let hostPart: Substring
        let portPart: Substring?
        if text.hasPrefix("[") {
            guard let close = text.firstIndex(of: "]") else { return nil }
            hostPart = text[text.index(after: text.startIndex)..<close]
            let rest = text[text.index(after: close)...]
            if rest.isEmpty {
                portPart = nil
            } else {
                guard rest.hasPrefix(":") else { return nil }
                portPart = rest.dropFirst()
            }
        } else if text.filter({ $0 == ":" }).count == 1, let colon = text.firstIndex(of: ":") {
            hostPart = text[..<colon]
            portPart = text[text.index(after: colon)...]
        } else {
            // Plain host, or a bare IPv6 address without a port.
            hostPart = Substring(text)
            portPart = nil
        }

        guard !hostPart.isEmpty else { return nil }
        if let portPart {
            guard let port = Int(portPart), (1...65535).contains(port) else { return nil }
            self.port = port
        }
        host = String(hostPart)
    }

    /// A private-range IP literal or a `.local` name. Since macOS 15, reaching
    /// these needs the Local Network permission, which extensions cannot request.
    /// Loopback is not included: it never needs the permission.
    var isOnLocalNetwork: Bool {
        let name = host.lowercased()
        if name.hasSuffix(".local") { return true }
        let octets = name.split(separator: ".").compactMap { UInt8($0) }
        if octets.count == 4 {
            switch (octets[0], octets[1]) {
            case (10, _), (192, 168), (169, 254): return true
            case (172, 16...31): return true
            default: return false
            }
        }
        // IPv6 link-local (fe80::/10) and unique local (fc00::/7).
        return name.contains(":") && (name.hasPrefix("fe8") || name.hasPrefix("fe9") || name.hasPrefix("fea")
            || name.hasPrefix("feb") || name.hasPrefix("fc") || name.hasPrefix("fd"))
    }

    func resolvedPort(for edition: ServerEdition) -> Int {
        port ?? edition.defaultPort
    }

    var description: String {
        let displayHost = host.contains(":") ? "[\(host)]" : host
        return port.map { "\(displayHost):\($0)" } ?? displayHost
    }
}

/// Placeholder artwork used when a server provides no favicon.
enum BlockIconStyle: String, CaseIterable, Codable {
    case grass, diamond, tnt, command, bedrock
}

nonisolated struct Player: Identifiable, Hashable, Sendable, Codable {
    let uuid: String
    let name: String

    var id: String { uuid }

    enum Account {
        /// Mojang/Microsoft account (version 4 UUID).
        case premium
        /// Offline-mode server: version 3 UUID derived from the name.
        case offline
        /// Not a real player, e.g. an all-zero UUID used for a server message.
        case unknown
    }

    /// Lowercase 32-digit hex, or `nil` if `uuid` is not a UUID.
    private var hexUUID: String? {
        let hex = uuid.replacingOccurrences(of: "-", with: "").lowercased()
        return hex.count == 32 && hex.allSatisfy(\.isHexDigit) ? hex : nil
    }

    var account: Account {
        guard let hex = hexUUID, !hex.allSatisfy({ $0 == "0" }) else { return .unknown }
        switch hex[hex.index(hex.startIndex, offsetBy: 12)] {
        case "4": return .premium
        case "3": return .offline
        default: return .unknown
        }
    }

    /// `uuid` in 8-4-4-4-12 form when it is a UUID, otherwise as given.
    var formattedUUID: String {
        guard let hex = hexUUID else { return uuid }
        var parts: [Substring] = []
        var rest = Substring(hex)
        for length in [8, 4, 4, 4, 12] {
            parts.append(rest.prefix(length))
            rest = rest.dropFirst(length)
        }
        return parts.joined(separator: "-")
    }

    /// Whether `name` is a valid Minecraft username (servers also send styled text).
    var hasValidName: Bool {
        name.range(of: "^[A-Za-z0-9_]{1,16}$", options: .regularExpression) != nil
    }

    /// What skin services should look the player up by: the UUID for premium
    /// accounts (Mojang does not know offline UUIDs), else the name, if valid.
    var skinIdentifier: String? {
        switch account {
        case .premium: hexUUID
        case .offline: hasValidName ? name : nil
        case .unknown: hexUUID == nil && hasValidName ? name : nil
        }
    }
}

/// Connection quality buckets used by the ping bars and history chart.
enum PingQuality {
    case good, fair, poor

    init(latency: Int) {
        switch latency {
        case ..<100: self = .good
        case ..<200: self = .fair
        default: self = .poor
        }
    }

    var label: String {
        switch self {
        case .good: "連線品質良好"
        case .fair: "連線品質普通"
        case .poor: "連線品質不佳"
        }
    }

    /// Number of filled signal bars (out of 4).
    static func bars(for latency: Int) -> Int {
        switch latency {
        case ..<50: 4
        case ..<100: 3
        case ..<200: 2
        default: 1
        }
    }
}

struct ServerStatus: Identifiable, Codable {
    let id: UUID
    var serverName: String
    var address: ServerAddress
    var edition: ServerEdition
    var iconStyle: BlockIconStyle
    var refreshInterval: TimeInterval?

    var online: Bool
    var version: String?
    var protocolVersion: Int?
    /// Raw MOTD, may contain `§` formatting codes.
    var motd: String
    /// PNG data of the server's 64×64 icon (Java only).
    var favicon: Data?
    /// Host and port actually connected to, when it differs from `address` (SRV).
    var resolvedAddress: String?
    var playersOnline: Int
    var playersMax: Int
    /// `nil` when the protocol does not report player names (Bedrock).
    var players: [Player]?
    var latency: Int?
    var pingHistory: [Int]
    var errorMessage: String?
    var lastChecked: Date?

    init(
        id: UUID = UUID(),
        serverName: String,
        address: ServerAddress,
        edition: ServerEdition,
        iconStyle: BlockIconStyle = .grass,
        refreshInterval: TimeInterval? = defaultRefreshInterval,
        online: Bool = false,
        version: String? = nil,
        protocolVersion: Int? = nil,
        motd: String = "",
        favicon: Data? = nil,
        resolvedAddress: String? = nil,
        playersOnline: Int = 0,
        playersMax: Int = 0,
        players: [Player]? = nil,
        latency: Int? = nil,
        pingHistory: [Int] = [],
        errorMessage: String? = nil,
        lastChecked: Date? = nil
    ) {
        self.id = id
        self.serverName = serverName
        self.address = address
        self.edition = edition
        self.iconStyle = iconStyle
        self.refreshInterval = refreshInterval
        self.online = online
        self.version = version
        self.protocolVersion = protocolVersion
        self.motd = motd
        self.favicon = favicon
        self.resolvedAddress = resolvedAddress
        self.playersOnline = playersOnline
        self.playersMax = playersMax
        self.players = players
        self.latency = latency
        self.pingHistory = pingHistory
        self.errorMessage = errorMessage
        self.lastChecked = lastChecked
    }

    /// Auto-refresh intervals offered in the UI.
    nonisolated static let refreshIntervalChoices: [TimeInterval] = [1, 5, 15, 30, 60, 300]
    nonisolated static let defaultRefreshInterval: TimeInterval = 30

    static func refreshIntervalLabel(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        return seconds < 60 ? "每 \(seconds) 秒" : "每 \(seconds / 60) 分鐘"
    }

    var playerFillRatio: Double {
        guard playersMax > 0 else { return 0 }
        return min(1, Double(playersOnline) / Double(playersMax))
    }

    var quality: PingQuality? {
        guard let latency else { return nil }
        return PingQuality(latency: latency)
    }
}

nonisolated enum ServerStatusError: Error, LocalizedError {
    case invalidURL
    case badResponse
    case motdNotFound
    case timeout
    case networkFailed(String)
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "位址或連接埠格式不正確。"
        case .badResponse:
            "伺服器回應格式不正確。"
        case .motdNotFound:
            "伺服器回應中沒有 MOTD。"
        case .timeout:
            "連線逾時（\(AppSettings.connectionTimeout) 秒）。請確認位址與連接埠是否正確，或伺服器是否正在維護。"
        case .networkFailed(let desc):
            "網路連線失敗：\(desc)"
        case .parsingFailed(let desc):
            "資料解析失敗：\(desc)"
        }
    }
}
