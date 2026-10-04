//
//  AppSettings.swift
//  MinecraftServerViewer
//

import Foundation

/// User preferences in `UserDefaults`. Views bind to the same keys with
/// `@AppStorage`; services read the current values through the accessors.
nonisolated enum AppSettings {
    /// Shared by the app and the widget (`Config/*.entitlements`); macOS groups carry the team prefix.
    static let appGroupID = "2C4X8AL22P.com.renyouchen.MinecraftServerViewer"

    enum Key {
        /// Seconds; `0` means new servers are refreshed manually.
        static let defaultRefreshInterval = "defaultRefreshInterval"
        static let refreshOnLaunch = "refreshOnLaunch"
        /// Seconds.
        static let connectionTimeout = "connectionTimeout"
        static let pingHistoryLength = "pingHistoryLength"
        static let loadPlayerSkins = "loadPlayerSkins"
    }

    static let connectionTimeoutChoices = [2, 3, 5, 10, 15]
    static let pingHistoryLengthChoices = [30, 60, 120]

    /// Call once at launch so the accessors and `@AppStorage` agree on defaults.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.defaultRefreshInterval: ServerStatus.defaultRefreshInterval,
            Key.refreshOnLaunch: true,
            Key.connectionTimeout: 5,
            Key.pingHistoryLength: 30,
            Key.loadPlayerSkins: true,
        ])
    }

    /// `nil` when new servers should not refresh automatically.
    static var defaultRefreshInterval: TimeInterval? {
        let seconds = UserDefaults.standard.double(forKey: Key.defaultRefreshInterval)
        return seconds > 0 ? seconds : nil
    }

    static var refreshOnLaunch: Bool {
        UserDefaults.standard.bool(forKey: Key.refreshOnLaunch)
    }

    static var connectionTimeout: Int {
        max(1, UserDefaults.standard.integer(forKey: Key.connectionTimeout))
    }

    static var pingHistoryLength: Int {
        max(1, UserDefaults.standard.integer(forKey: Key.pingHistoryLength))
    }
}
