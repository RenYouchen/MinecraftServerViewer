//
//  PixelArt.swift
//  MinecraftServerViewer
//
//  8×8 pixel artwork for server icons and player heads.
//

import SwiftUI

/// Draws a row-major 8×8 grid of colors.
struct PixelGrid: View {
    let pixels: [Color]
    var size: CGFloat
    var cornerRadius: CGFloat = 4

    var body: some View {
        Canvas { context, canvasSize in
            let cell = canvasSize.width / 8
            for (index, color) in pixels.enumerated() {
                let rect = CGRect(
                    x: CGFloat(index % 8) * cell,
                    y: CGFloat(index / 8) * cell,
                    width: cell + 0.5,
                    height: cell + 0.5
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .accessibilityHidden(true)
    }
}

struct ServerIcon: View {
    let server: ServerStatus
    var size: CGFloat
    var cornerRadius: CGFloat

    var body: some View {
        Group {
            if let favicon = server.favicon, let image = NSImage(data: favicon) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none) // keep the 64×64 pixel art crisp
                    .frame(width: size, height: size)
                    .clipShape(.rect(cornerRadius: cornerRadius))
                    .accessibilityHidden(true)
            } else {
                PixelGrid(pixels: server.iconStyle.pixels(seed: stableHash(server.address.host)), size: size, cornerRadius: cornerRadius)
            }
        }
        .opacity(server.online ? 1 : 0.55)
    }
}

/// The player's real skin face (with hat layer) from mc-heads.net, falling back
/// to generated art while loading, offline, or for entries that are not real players.
struct PlayerHead: View {
    let player: Player
    var size: CGFloat = 26
    @AppStorage(AppSettings.Key.loadPlayerSkins) private var loadsSkins = true

    var body: some View {
        if loadsSkins, let url = Self.headURL(for: player) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .interpolation(.none) // keep the 8×8 skin pixels crisp
                        .frame(width: size, height: size)
                        .clipShape(.rect(cornerRadius: 4))
                        .accessibilityHidden(true)
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        PixelGrid(pixels: Self.pixels(seed: stableHash(player.uuid)), size: size, cornerRadius: 4)
    }

    /// `nil` for fake sample entries (all-zero UUID, styled text) servers often send.
    static func headURL(for player: Player) -> URL? {
        player.skinIdentifier.flatMap { URL(string: "https://mc-heads.net/avatar/\($0)/64") }
    }

    private static func pixels(seed: UInt64) -> [Color] {
        var rng = SeededGenerator(seed: seed)
        let hair = Color(hex: [0x3B2A1E, 0x6B4A2B, 0x1E1E1E, 0xC9A55A, 0x8C3B1E].randomElement(using: &rng)!)
        let skin = Color(hex: [0xE0AC86, 0xC68E6A, 0x8D5A3F, 0xF1C7A5].randomElement(using: &rng)!)
        let iris = Color(hex: [0x3B6CC7, 0x4A8A3B, 0x5B3A1E].randomElement(using: &rng)!)

        return (0..<64).map { index in
            let x = index % 8, y = index / 8
            if y < 2 || (y == 2 && (x == 0 || x == 7)) { return hair }
            if y == 4 && (x == 1 || x == 5) { return .white }
            if y == 4 && (x == 2 || x == 6) { return iris }
            if y == 6 && (x == 3 || x == 4) { return Color(hex: 0x7A3E2E) }
            return skin
        }
    }
}

extension BlockIconStyle {
    func pixels(seed: UInt64) -> [Color] {
        var rng = SeededGenerator(seed: seed)
        func pick(_ hexes: [UInt32]) -> Color { Color(hex: hexes.randomElement(using: &rng)!) }
        let ore: Set<Int> = [9, 10, 21, 30, 42, 43, 53]

        return (0..<64).map { index in
            let x = index % 8, y = index / 8
            switch self {
            case .grass:
                if y < 2 { return pick([0x5D9E3A, 0x6FB343, 0x4F8A31]) }
                if y == 2 { return Bool.random(using: &rng) ? pick([0x5D9E3A, 0x4F8A31]) : pick([0x8A5A3B, 0x7A4E33]) }
                return pick([0x8A5A3B, 0x7A4E33, 0x9B6A47, 0x6B4429])
            case .diamond:
                return ore.contains(index) ? pick([0x5DE0D8, 0x3BC7C0, 0xA6F2EE]) : pick([0x8E8E8E, 0x7D7D7D, 0x9C9C9C, 0x727272])
            case .tnt:
                if y == 3 && (2...5).contains(x) { return Color(hex: 0x2B2B2B) }
                if y == 3 || y == 4 { return Color(hex: 0xECECEC) }
                return pick([0xD8413A, 0xC23630, 0xE2534B])
            case .command:
                if (3...4).contains(x) && (3...4).contains(y) { return Color(hex: 0xD9D9D9) }
                if x == 0 || y == 0 || x == 7 || y == 7 { return pick([0x9C6B3F, 0x8A5D36]) }
                return pick([0xC98B4D, 0xB97D43, 0xD59A5C])
            case .bedrock:
                return pick([0x3A3A3A, 0x565656, 0x2A2A2A, 0x6A6A6A])
            }
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// FNV-1a, stable across launches (unlike `hashValue`).
func stableHash(_ string: String) -> UInt64 {
    string.utf8.reduce(0xcbf2_9ce4_8422_2325) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
}
