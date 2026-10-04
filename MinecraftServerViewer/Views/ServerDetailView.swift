//
//  ServerDetailView.swift
//  MinecraftServerViewer
//

import Charts
import SwiftUI

struct ServerDetailView: View {
    let server: ServerStatus
    let isRefreshing: Bool
    var onRetry: () -> Void
    var onChangeInterval: (TimeInterval?) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ServerHeader(server: server, isRefreshing: isRefreshing, onChangeInterval: onChangeInterval)

                if server.online {
                    if !server.motd.isEmpty {
                        MOTDSection(motd: server.motd)
                    }
                    StatsRow(server: server, isRefreshing: isRefreshing)
                    HStack(alignment: .top, spacing: 12) {
                        PlayerListCard(server: server)
                        PingHistoryCard(history: server.pingHistory)
                            .frame(minWidth: 260, maxWidth: 340)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    OfflineCard(server: server, isRefreshing: isRefreshing, onRetry: onRetry)
                }
            }
            .padding(24)
        }
        .navigationTitle(server.serverName)
        .navigationSubtitle(subtitle)
    }

    private var subtitle: String {
        if server.online {
            return "\(server.playersOnline) 位玩家在線 · \(server.latency ?? 0) ms"
        }
        return "離線"
    }
}

// MARK: - Header

private struct ServerHeader: View {
    let server: ServerStatus
    let isRefreshing: Bool
    var onChangeInterval: (TimeInterval?) -> Void

    var body: some View {
        HStack(spacing: 16) {
            ServerIcon(server: server, size: 64, cornerRadius: 12)
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(server.serverName)
                    .font(.title2.bold())
                HStack(spacing: 6) {
                    Text(server.address.description)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.trailing, 4)
                    if let resolved = server.resolvedAddress {
                        Text("→ \(resolved)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                            .padding(.trailing, 4)
                            .help("透過 SRV 記錄解析的實際連線位址")
                    }
                    Badge(server.edition.displayName)
                    if server.online, let version = server.version {
                        Badge(version)
                    }
                }
            }

            Spacer()

            RefreshIntervalMenu(interval: server.refreshInterval, onChange: onChangeInterval)
                .menuStyle(.button)
            StatusPill(server: server, isRefreshing: isRefreshing)
        }
    }
}

// MARK: - MOTD

private struct MOTDSection: View {
    let motd: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("伺服器訊息（MOTD）")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(MOTDFormatter.attributedString(from: motd))
                .lineSpacing(4)
                .shadow(color: .black.opacity(0.6), radius: 0, x: 1, y: 1)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(Color(white: 0.09), in: .rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.06))
                }
        }
    }
}

// MARK: - Stats

private struct StatsRow: View {
    let server: ServerStatus
    let isRefreshing: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StatCard(title: "在線玩家", systemImage: "person.2") {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(server.playersOnline)")
                        .font(.title2.bold().monospacedDigit())
                    Text("/ \(server.playersMax)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: server.playerFillRatio)
                    .accessibilityLabel("玩家人數比例")
            }

            StatCard(title: "延遲", systemImage: "wifi") {
                if let latency = server.latency {
                    HStack(alignment: .lastTextBaseline) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(latency)")
                                .font(.title2.bold().monospacedDigit())
                            Text("ms")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        PingBars(latency: latency)
                    }
                    Text(PingQuality(latency: latency).label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PingQuality(latency: latency).color)
                }
            }

            StatCard(title: "版本", systemImage: "shippingbox") {
                Text(server.version ?? "未知")
                    .font(.title2.bold())
                Text("協定 \(server.protocolVersion.map(String.init) ?? "—") · \(server.edition.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            StatCard(title: "最後檢查", systemImage: "clock") {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(lastCheckedText(now: context.date))
                        .font(.title2.bold())
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Text(server.refreshInterval.map { "\(ServerStatus.refreshIntervalLabel($0))自動更新" } ?? "自動更新已關閉")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Counts up every second. A check in flight keeps showing the previous
    /// time, so short intervals do not make it flicker to "檢查中…".
    private func lastCheckedText(now: Date) -> String {
        guard let date = server.lastChecked else { return isRefreshing ? "檢查中…" : "—" }
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<1: return "剛剛"
        case ..<60: return "\(seconds) 秒前"
        default: return date.formatted(.relative(presentation: .numeric, unitsStyle: .wide))
        }
    }
}

private struct StatCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            content
        }
        .card()
    }
}

// MARK: - Players

private struct PlayerListCard: View {
    let server: ServerStatus
    @State private var showsAll = false

    private let collapsedCount = 8
    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .leading),
        GridItem(.flexible(), spacing: 12, alignment: .leading),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("玩家列表")
                    .font(.headline)
                Spacer()
                if let players = server.players, players.count > collapsedCount {
                    Button(showsAll ? "收合" : "顯示全部 \(players.count) 位") {
                        withAnimation { showsAll.toggle() }
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }

            if let players = server.players {
                if players.isEmpty {
                    Text("目前沒有玩家在線")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                        ForEach(showsAll ? players : Array(players.prefix(collapsedCount))) { player in
                            PlayerRow(player: player)
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("此伺服器未提供玩家名單", systemImage: "info.circle")
                } description: {
                    Text(server.edition == .bedrock
                        ? "Bedrock 版的 Unconnected Ping 只回傳人數，不含玩家名稱。"
                        : "伺服器沒有回傳玩家樣本，可能已在設定中隱藏。")
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            }
        }
        .card()
    }
}

private struct PlayerRow: View {
    let player: Player
    @State private var showsDetail = false
    @State private var isHovered = false

    var body: some View {
        Button {
            showsDetail = true
        } label: {
            HStack(spacing: 10) {
                PlayerHead(player: player)
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.name)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(player.uuid.prefix(8) + "…")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 40)
            .padding(.horizontal, 6)
            .contentShape(.rect)
            .background(.primary.opacity(isHovered || showsDetail ? 0.06 : 0), in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("查看 \(player.name) 的詳細資訊")
        .popover(isPresented: $showsDetail, arrowEdge: .trailing) {
            PlayerDetailView(player: player)
        }
    }
}

private struct PlayerDetailView: View {
    let player: Player
    @State private var copied = false
    @AppStorage(AppSettings.Key.loadPlayerSkins) private var loadsSkins = true

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            skinRender
                .frame(width: 90, height: 180)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.name)
                        .font(.title2.bold())
                        .textSelection(.enabled)
                    Label(accountLabel, systemImage: accountSymbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("UUID")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(player.formattedUUID)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .fixedSize()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(player.formattedUUID, forType: .string)
                            copied = true
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("複製 UUID")
                    }
                }

                if player.account == .premium, let url = URL(string: "https://namemc.com/profile/\(player.formattedUUID)") {
                    Link(destination: url) {
                        Label("在 NameMC 查看", systemImage: "arrow.up.right.square")
                    }
                    .font(.callout)
                }
            }
        }
        .padding(18)
    }

    @ViewBuilder
    private var skinRender: some View {
        if loadsSkins, let id = player.skinIdentifier, let url = URL(string: "https://mc-heads.net/body/\(id)/180") {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                } else if phase.error != nil {
                    PlayerHead(player: player, size: 72)
                } else {
                    ProgressView()
                }
            }
        } else {
            PlayerHead(player: player, size: 72)
        }
    }

    private var accountLabel: String {
        switch player.account {
        case .premium: "正版帳號"
        case .offline: "離線模式帳號（皮膚依名稱查詢，可能不準確）"
        case .unknown: "非玩家項目（伺服器訊息）"
        }
    }

    private var accountSymbol: String {
        switch player.account {
        case .premium: "checkmark.seal"
        case .offline: "person.crop.circle.badge.questionmark"
        case .unknown: "text.bubble"
        }
    }
}

// MARK: - Ping history

private struct PingHistoryCard: View {
    let history: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("延遲紀錄")
                    .font(.headline)
                Spacer()
                Text("最近 \(history.count) 次")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(Array(history.enumerated()), id: \.offset) { index, latency in
                BarMark(
                    x: .value("取樣", index),
                    y: .value("延遲（ms）", latency)
                )
                .foregroundStyle(PingQuality(latency: latency).color)
                .clipShape(.rect(topLeadingRadius: 2, topTrailingRadius: 2))
            }
            .chartXAxis(.hidden)
            // 0–10 ms by default; grows to the highest sample once latency exceeds that.
            .chartYScale(domain: 0...max(10, history.max() ?? 0))
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
            .frame(minHeight: 140)

            if let low = history.min(), let high = history.max() {
                HStack {
                    Text("平均 \(history.reduce(0, +) / history.count) ms")
                    Spacer()
                    Text("最低 \(low) ms")
                    Spacer()
                    Text("最高 \(high) ms")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

// MARK: - Offline

private struct OfflineCard: View {
    let server: ServerStatus
    let isRefreshing: Bool
    var onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("無法連線到伺服器", systemImage: "wifi.slash")
        } description: {
            Text(server.errorMessage ?? ServerStatusError.timeout.localizedDescription)
        } actions: {
            Button(action: onRetry) {
                if isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Text("重試連線")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRefreshing)
        }
        .frame(maxWidth: .infinity, minHeight: 420)
        .background(.quinary, in: .rect(cornerRadius: 12))
    }
}

#Preview {
    ServerDetailView(server: ServerStatus.samples[0], isRefreshing: false) {}
        .frame(width: 900, height: 760)
}
