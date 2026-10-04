//
//  ServerPersistence.swift
//  MinecraftServerViewer
//

import Foundation
import OSLog

/// Reads and writes the server list, including the last known status, as JSON.
struct ServerPersistence {
    let fileURL: URL

    /// `servers.json` in the App Group container, so the widget reads the same list.
    /// Falls back to the app's own container if the group is unavailable.
    static let standard: ServerPersistence = {
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppSettings.appGroupID) else {
            logger.error("App Group container unavailable; the widget will not see the server list")
            return ServerPersistence(fileURL: legacyFileURL)
        }
        let fileURL = group.appending(path: "servers.json")
        migrateLegacyFile(to: fileURL)
        return ServerPersistence(fileURL: fileURL)
    }()

    /// Where the app saved the list before the widget existed (inside the app's own sandbox).
    private static let legacyFileURL = URL.applicationSupportDirectory
        .appending(path: "MinecraftServerViewer", directoryHint: .isDirectory)
        .appending(path: "servers.json")

    /// Moves the list saved by older versions into the group container, once.
    private static func migrateLegacyFile(to fileURL: URL) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: fileURL.path),
              fileManager.fileExists(atPath: legacyFileURL.path) else { return }
        do {
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: legacyFileURL, to: fileURL)
        } catch {
            logger.error("Failed to migrate \(legacyFileURL.path, privacy: .public): \(error)")
        }
    }

    private static let logger = Logger(subsystem: "com.renyouchen.MinecraftServerViewer", category: "Persistence")

    /// `nil` on first launch, or when the file cannot be decoded. An unreadable
    /// file is moved aside to `servers.json.corrupt` so the next save keeps it.
    func load() -> [ServerStatus]? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            return try Self.decoder.decode([ServerStatus].self, from: data)
        } catch {
            Self.logger.error("Failed to decode \(fileURL.path, privacy: .public): \(error)")
            let backup = fileURL.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            return nil
        }
    }

    func save(_ servers: [ServerStatus]) throws {
        let data = try Self.encoder.encode(servers)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
