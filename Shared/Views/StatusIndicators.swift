//
//  StatusIndicators.swift
//  MinecraftServerViewer
//

import SwiftUI

extension PingQuality {
    var color: Color {
        switch self {
        case .good: .green
        case .fair: .orange
        case .poor: .red
        }
    }
}

extension ServerStatus {
    var statusColor: Color { online ? (quality?.color ?? .green) : .red }
}

struct StatusDot: View {
    let server: ServerStatus
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(server.statusColor)
            .frame(width: size, height: size)
            .accessibilityLabel(server.online ? "在線" : "離線")
    }
}

struct PingBars: View {
    let latency: Int

    var body: some View {
        let filled = PingQuality.bars(for: latency)
        let color = PingQuality(latency: latency).color
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(1...4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(level <= filled ? AnyShapeStyle(color) : AnyShapeStyle(.quaternary))
                    .frame(width: 4, height: CGFloat(level * 4 + 2))
            }
        }
        .accessibilityHidden(true)
    }
}

struct StatusPill: View {
    let server: ServerStatus
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isRefreshing {
                ProgressView().controlSize(.mini)
            } else {
                Circle().fill(server.statusColor).frame(width: 7, height: 7)
            }
            Text(isRefreshing ? "更新中" : server.online ? "在線" : "離線")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(server.online ? Color.green : Color.red)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background((server.online ? Color.green : Color.red).opacity(0.14), in: .capsule)
    }
}

struct Badge: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.quaternary, in: .rect(cornerRadius: 5))
    }
}

extension View {
    /// Rounded panel used for detail sections.
    func card() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.quinary, in: .rect(cornerRadius: 12))
    }
}
