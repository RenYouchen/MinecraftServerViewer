//
//  StatusPingers.swift
//  MinecraftServerViewer
//
//  Java Edition: TCP Server List Ping (handshake → status request → ping/pong).
//  Bedrock Edition: RakNet Unconnected Ping over UDP.
//

import Foundation

/// Protocol-independent result of one status query.
nonisolated struct ServerPingResult: Sendable {
    var version: String
    var protocolVersion: Int?
    var motd: String
    /// PNG data of the server icon (Java only).
    var favicon: Data?
    var playersOnline: Int
    var playersMax: Int
    /// `nil` when the protocol does not report player names (Bedrock).
    var players: [Player]?
    var latency: Int
}

nonisolated private func milliseconds(since start: ContinuousClock.Instant) -> Int {
    let elapsed = ContinuousClock.now - start
    let ms = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
    return max(1, Int(ms.rounded()))
}

// MARK: - Java

nonisolated enum JavaStatusPinger {
    /// Protocol version -1 is the convention for "probing which version to use".
    private static let probeProtocolVersion: Int32 = -1
    /// Protocol limit for a packet is 2^21 - 1 bytes.
    private static let maxPacketLength = 2_097_151

    @concurrent
    static func ping(host: String, port: Int, timeout: Duration) async throws -> ServerPingResult {
        let connection = try MinecraftConnection(host: host, port: port, transport: .tcp)
        return try await connection.run(timeout: timeout) { connection in
            var handshake = PacketWriter()
            handshake.writeVarInt(0x00)
            handshake.writeVarInt(probeProtocolVersion)
            handshake.writeString(host)
            handshake.writeUInt16(UInt16(port))
            handshake.writeVarInt(1) // next state: status

            var statusRequest = PacketWriter()
            statusRequest.writeVarInt(0x00)

            let requestStart = ContinuousClock.now
            try await connection.send(handshake.framed + statusRequest.framed)

            var response = try await readPacket(from: connection, expectedID: 0x00)
            let statusLatency = milliseconds(since: requestStart)
            let json = try response.readString()

            // Ping/pong gives a cleaner latency figure; some servers close the
            // connection after the status response, so fall back if it fails.
            var latency = statusLatency
            do {
                var ping = PacketWriter()
                ping.writeVarInt(0x01)
                ping.writeInt64(Int64(Date.now.timeIntervalSince1970 * 1000))
                let pingStart = ContinuousClock.now
                try await connection.send(ping.framed)
                _ = try await readPacket(from: connection, expectedID: 0x01)
                latency = milliseconds(since: pingStart)
            } catch is ServerStatusError {
                // Keep the status round-trip time.
            }

            return try parse(json: json, latency: latency)
        }
    }

    private static func readPacket(from connection: MinecraftConnection, expectedID: Int32) async throws -> PacketReader {
        let length = Int(try await connection.readVarInt())
        guard (1...maxPacketLength).contains(length) else {
            throw ServerStatusError.parsingFailed("封包長度不正確（\(length)）")
        }
        var reader = PacketReader(try await connection.read(count: length))
        guard try reader.readVarInt() == expectedID else { throw ServerStatusError.badResponse }
        return reader
    }

    private struct StatusJSON: Decodable {
        struct Version: Decodable {
            let name: String
            let `protocol`: Int?
        }

        struct Players: Decodable {
            let max: Int
            let online: Int
            let sample: [Sample]?
        }

        struct Sample: Decodable {
            let name: String
            let id: String
        }

        let version: Version?
        let players: Players?
        let description: ChatComponent?
        /// `data:image/png;base64,...`
        let favicon: String?
    }

    private static func decodeFavicon(_ dataURL: String) -> Data? {
        guard dataURL.hasPrefix("data:image/png;base64,"), let comma = dataURL.firstIndex(of: ",") else { return nil }
        // Some servers wrap the base64 payload with newlines.
        return Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...]), options: .ignoreUnknownCharacters)
    }

    private static func parse(json: String, latency: Int) throws -> ServerPingResult {
        let status: StatusJSON
        do {
            status = try JSONDecoder().decode(StatusJSON.self, from: Data(json.utf8))
        } catch {
            throw ServerStatusError.parsingFailed("狀態 JSON 格式不正確")
        }
        guard let description = status.description else { throw ServerStatusError.motdNotFound }

        return ServerPingResult(
            version: status.version?.name.strippingFormattingCodes ?? "未知",
            protocolVersion: status.version?.protocol,
            motd: description.legacyText,
            favicon: status.favicon.flatMap(decodeFavicon),
            playersOnline: status.players?.online ?? 0,
            playersMax: status.players?.max ?? 0,
            players: (status.players?.sample ?? []).map { Player(uuid: $0.id, name: $0.name) },
            latency: latency
        )
    }
}

// MARK: - Bedrock

nonisolated enum BedrockStatusPinger {
    private static let unconnectedPing: UInt8 = 0x01
    private static let unconnectedPong: UInt8 = 0x1C
    private static let offlineMessageID: [UInt8] = [
        0x00, 0xFF, 0xFF, 0x00, 0xFE, 0xFE, 0xFE, 0xFE,
        0xFD, 0xFD, 0xFD, 0xFD, 0x12, 0x34, 0x56, 0x78,
    ]

    @concurrent
    static func ping(host: String, port: Int, timeout: Duration) async throws -> ServerPingResult {
        let connection = try MinecraftConnection(host: host, port: port, transport: .udp)
        return try await connection.run(timeout: timeout) { connection in
            var ping = PacketWriter()
            ping.writeByte(unconnectedPing)
            ping.writeInt64(Int64(Date.now.timeIntervalSince1970 * 1000))
            ping.writeBytes(offlineMessageID)
            ping.writeInt64(Int64.random(in: 0...Int64.max)) // client GUID

            let start = ContinuousClock.now
            try await connection.send(ping.data)

            // Skip unrelated datagrams until the pong arrives (or the timeout fires).
            while true {
                var reader = PacketReader(try await connection.receiveDatagram())
                guard reader.remaining > 0, try reader.readByte() == unconnectedPong else { continue }
                let latency = milliseconds(since: start)
                _ = try reader.readInt64() // echoed time
                _ = try reader.readInt64() // server GUID
                guard Array(try reader.readBytes(offlineMessageID.count)) == offlineMessageID else {
                    throw ServerStatusError.badResponse
                }
                let length = Int(try reader.readUInt16())
                guard let info = String(bytes: try reader.readBytes(length), encoding: .utf8) else {
                    throw ServerStatusError.parsingFailed("伺服器資訊不是有效的 UTF-8")
                }
                return try parse(info: info, latency: latency)
            }
        }
    }

    /// `MCPE;MOTD;protocol;version;online;max;serverID;levelName;gameMode;...`
    private static func parse(info: String, latency: Int) throws -> ServerPingResult {
        let fields = info.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 6 else { throw ServerStatusError.parsingFailed("伺服器資訊欄位不足") }

        let levelName = fields.count > 7 ? fields[7] : ""
        let motd = levelName.isEmpty ? fields[1] : "\(fields[1])\n§r\(levelName)"

        return ServerPingResult(
            version: fields[3],
            protocolVersion: Int(fields[2]),
            motd: motd,
            favicon: nil,
            playersOnline: Int(fields[4]) ?? 0,
            playersMax: Int(fields[5]) ?? 0,
            players: nil,
            latency: latency
        )
    }
}
