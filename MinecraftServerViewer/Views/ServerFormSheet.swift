//
//  ServerFormSheet.swift
//  MinecraftServerViewer
//

import SwiftUI

/// Adds a new server, or edits `original` when one is given.
struct ServerFormSheet: View {
    let store: ServerStore
    let original: ServerStatus?
    var onSave: (ServerStatus) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var edition: ServerEdition
    @State private var addressText: String
    @State private var autoRefresh: Bool
    @State private var interval: TimeInterval
    @State private var testState: TestState = .idle

    init(store: ServerStore, editing original: ServerStatus? = nil, onSave: @escaping (ServerStatus) -> Void) {
        self.store = store
        self.original = original
        self.onSave = onSave
        _name = State(initialValue: original?.serverName ?? "")
        _edition = State(initialValue: original?.edition ?? .java)
        _addressText = State(initialValue: original?.address.description ?? "")
        let initialInterval = original.map(\.refreshInterval) ?? AppSettings.defaultRefreshInterval
        _autoRefresh = State(initialValue: initialInterval != nil)
        _interval = State(initialValue: initialInterval ?? ServerStatus.defaultRefreshInterval)
    }

    private var isEditing: Bool { original != nil }

    private enum TestState {
        case idle
        case running
        case success(ServerStatus)
        case failure(String)
    }

    private var address: ServerAddress? { ServerAddress(addressText) }

    private var canSubmit: Bool { address != nil }

    private var draft: ServerStatus {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let address = address ?? ServerAddress(host: "")

        var server: ServerStatus
        if let original, original.address == address, original.edition == edition {
            server = original
        } else {
            // New server, or the connection target changed so the old status no longer applies.
            server = ServerStatus(
                id: original?.id ?? UUID(),
                serverName: "",
                address: address,
                edition: edition,
                iconStyle: original?.iconStyle ?? (edition == .java ? .grass : .diamond)
            )
        }
        server.serverName = trimmedName.isEmpty ? address.host : trimmedName
        server.refreshInterval = autoRefresh ? interval : nil
        return server
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? "修改伺服器" : "新增伺服器")
                    .font(.headline)
                Text(isEditing ? "變更位址或版本後會重新檢查伺服器狀態。" : "輸入位址後可先測試連線，再加入側邊欄。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.horizontal, .top], 20)

            Form {
                Section {
                    TextField("名稱", text: $name, prompt: Text("例如：生存伺服器"))
                    Picker("版本", selection: $edition) {
                        ForEach(ServerEdition.allCases) { edition in
                            Text(edition.displayName).tag(edition)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("伺服器位址", text: $addressText, prompt: Text("play.example.net 或 play.example.net:25565"))
                } header: {
                    Text("連線")
                } footer: {
                    VStack(alignment: .leading, spacing: 2) {
                        if !addressText.isEmpty && address == nil {
                            Text("位址格式不正確，連接埠需介於 1–65535；IPv6 請寫成 [::1]:25565。")
                                .foregroundStyle(.red)
                        }
                        Text(edition.protocolNote)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                Section("更新") {
                    Toggle("自動重新整理", isOn: $autoRefresh)
                    Picker("更新頻率", selection: $interval) {
                        ForEach(ServerStatus.refreshIntervalChoices, id: \.self) { choice in
                            Text(ServerStatus.refreshIntervalLabel(choice)).tag(choice)
                        }
                    }
                    .disabled(!autoRefresh)
                }

                Section("連線測試") {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(testColor)
                            .frame(width: 9, height: 9)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(testTitle)
                                .fontWeight(.semibold)
                            Text(testDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("測試連線", action: runTest)
                            .disabled(!canSubmit || isTesting)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "儲存" : "新增", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
            }
            .padding(16)
        }
        .frame(width: 520, height: 620)
        .onChange(of: edition) { testState = .idle }
        .onChange(of: addressText) { testState = .idle }
    }

    // MARK: - Actions

    private var isTesting: Bool {
        if case .running = testState { return true }
        return false
    }

    private func runTest() {
        testState = .running
        let server = draft
        Task {
            do {
                testState = .success(try await store.test(server))
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }

    private func submit() {
        var server = draft
        if case .success(let tested) = testState {
            server = tested
        }
        onSave(server)
        dismiss()
    }

    // MARK: - Test status text

    private var testColor: Color {
        switch testState {
        case .idle: .secondary.opacity(0.4)
        case .running: .orange
        case .success: .green
        case .failure: .red
        }
    }

    private var testTitle: String {
        switch testState {
        case .idle: "尚未測試"
        case .running: "連線中…"
        case .success: "連線成功"
        case .failure: "連線失敗"
        }
    }

    private var testDetail: String {
        switch testState {
        case .idle:
            return "送出前建議先確認伺服器可以連線。"
        case .running:
            return edition == .java ? "正在進行 Handshake 與 Status Request（TCP）" : "正在送出 Unconnected Ping（UDP）"
        case .success(let server):
            return "\(server.latency ?? 0) ms · \(server.edition.displayName) \(server.version ?? "版本未知")"
        case .failure(let message):
            return message
        }
    }
}
