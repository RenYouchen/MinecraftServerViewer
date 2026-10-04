//
//  SampleData.swift
//  MinecraftServerViewer
//
//  Default servers for first launch and fixed data for previews.
//

import Foundation

extension ServerStatus {
    /// Real public servers used on first launch, before anything has been saved.
    /// Never checked, so the first refresh queries them immediately.
    static let defaults: [ServerStatus] = [
        ServerStatus(serverName: "Hypixel", address: ServerAddress(host: "mc.hypixel.net"), edition: .java, iconStyle: .grass),
        ServerStatus(serverName: "CubeCraft (Bedrock)", address: ServerAddress(host: "play.cubecraft.net"), edition: .bedrock, iconStyle: .diamond),
        ServerStatus(serverName: "本機測試", address: ServerAddress(host: "127.0.0.1"), edition: .java, iconStyle: .bedrock),
    ]

    /// Fixed example data for SwiftUI previews.
    static let samples: [ServerStatus] = [
        ServerStatus(
            serverName: "生存伺服器", address: ServerAddress(host: "smp.example.net", port: 25565), edition: .java, iconStyle: .grass,
            online: true, version: "1.21.4", protocolVersion: 769,
            motd: "§6§lSurvival SMP§r§7 · §aJava 1.21.4\n§f歡迎回來！§7本週活動：§b§l村莊建造大賽",
            playersOnline: 12, playersMax: 50, players: Player.samples(count: 12, seed: 11),
            latency: 38, pingHistory: History.make(around: 38, seed: 11), lastChecked: .now
        ),
        ServerStatus(
            serverName: "創造建築服", address: ServerAddress(host: "build.example.net", port: 25565), edition: .java, iconStyle: .command,
            online: true, version: "1.20.6", protocolVersion: 766,
            motd: "§d§lCreative §r§fBuild World\n§7WorldEdit 已開放 · §e/plot claim",
            playersOnline: 3, playersMax: 20, players: Player.samples(count: 3, seed: 22),
            latency: 72, pingHistory: History.make(around: 72, seed: 22), lastChecked: .now
        ),
        ServerStatus(
            serverName: "基岩手機服", address: ServerAddress(host: "be.example.net", port: 19132), edition: .bedrock, iconStyle: .diamond,
            online: true, version: "1.21.50", protocolVersion: 766,
            motd: "§b§lBedrock Realm\n§f手機、Switch、Xbox 跨平台",
            playersOnline: 7, playersMax: 30, players: nil,
            latency: 54, pingHistory: History.make(around: 54, seed: 33), lastChecked: .now
        ),
        ServerStatus(
            serverName: "小遊戲大廳", address: ServerAddress(host: "mini.example.net", port: 25565), edition: .java, iconStyle: .tnt,
            online: false, errorMessage: ServerStatusError.timeout.localizedDescription,
            lastChecked: .now.addingTimeInterval(-7200)
        ),
        ServerStatus(
            serverName: "本機測試", address: ServerAddress(host: "127.0.0.1", port: 25565), edition: .java, iconStyle: .bedrock,
            online: true, version: "1.21.4", protocolVersion: 769,
            motd: "§fA Minecraft Server\n§9Paper 開發環境",
            playersOnline: 1, playersMax: 10, players: Player.samples(count: 1, seed: 55),
            latency: 2, pingHistory: History.make(around: 2, seed: 55), lastChecked: .now
        ),
    ]
}

extension Player {
    private static let sampleNames = [
        "Steve_Builder", "AlexMiner", "Creeper_Hugs", "RedstoneWiz", "小鐵匠", "NightOwl42",
        "PixelPanda", "DiamondDave", "LavaSurfer", "EnderSnow", "Moss_Walker", "QuartzQueen",
    ]

    static func samples(count: Int, seed: UInt64) -> [Player] {
        var rng = SeededGenerator(seed: seed)
        return sampleNames.prefix(count).map { name in
            let hex = (0..<32).map { _ in String(Int.random(in: 0..<16, using: &rng), radix: 16) }.joined()
            return Player(uuid: hex, name: name)
        }
    }
}

enum History {
    /// 30 samples of plausible latency around `ms`, with one spike.
    static func make(around ms: Int, seed: UInt64) -> [Int] {
        var rng = SeededGenerator(seed: seed &+ 99)
        return (0..<30).map { i in
            let jitter = Double.random(in: 0.75...1.25, using: &rng)
            let spike = i == 18 ? Double(ms) * 0.9 : 0
            return max(1, Int((Double(ms) * jitter + spike).rounded()))
        }
    }
}

/// Deterministic SplitMix64 so sample art and data stay stable between launches.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
