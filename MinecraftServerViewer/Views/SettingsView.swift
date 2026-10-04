//
//  SettingsView.swift
//  MinecraftServerViewer
//

import AppKit
import SwiftUI

/// The app's Settings window (⌘,).
struct SettingsView: View {
    let store: ServerStore

    var body: some View {
        TabView {
            Tab("一般", systemImage: "gearshape") {
                GeneralSettings()
            }
            Tab("連線", systemImage: "network") {
                ConnectionSettings()
            }
            Tab("資料", systemImage: "externaldrive") {
                DataSettings(store: store)
            }
        }
        .frame(width: 480)
    }
}

private struct GeneralSettings: View {
    @AppStorage(AppSettings.Key.defaultRefreshInterval) private var defaultInterval = ServerStatus.defaultRefreshInterval
    @AppStorage(AppSettings.Key.refreshOnLaunch) private var refreshOnLaunch = true

    var body: some View {
        Form {
            Section {
                Picker("新伺服器的檢測頻率", selection: $defaultInterval) {
                    ForEach(ServerStatus.refreshIntervalChoices, id: \.self) { choice in
                        Text(ServerStatus.refreshIntervalLabel(choice)).tag(choice)
                    }
                    Divider()
                    Text("手動").tag(0.0)
                }
            } footer: {
                Text("只套用到之後新增的伺服器。要一次修改現有伺服器，請使用側邊欄左下角的選單。")
            }
            Section {
                Toggle("啟動時更新所有伺服器", isOn: $refreshOnLaunch)
            } footer: {
                Text("關閉時會先顯示上次儲存的狀態，之後依各伺服器的檢測頻率更新。")
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ConnectionSettings: View {
    @AppStorage(AppSettings.Key.connectionTimeout) private var timeout = 5
    @AppStorage(AppSettings.Key.pingHistoryLength) private var historyLength = 30

    var body: some View {
        Form {
            Section {
                Picker("連線逾時", selection: $timeout) {
                    ForEach(AppSettings.connectionTimeoutChoices, id: \.self) { seconds in
                        Text("\(seconds) 秒").tag(seconds)
                    }
                }
            } footer: {
                Text("伺服器在這段時間內沒有回應，就視為離線。")
            }
            Section {
                Picker("延遲紀錄保留", selection: $historyLength) {
                    ForEach(AppSettings.pingHistoryLengthChoices, id: \.self) { count in
                        Text("最近 \(count) 次").tag(count)
                    }
                }
            } footer: {
                Text("調低時，較舊的紀錄會在下次檢測時移除。")
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct DataSettings: View {
    let store: ServerStore
    @AppStorage(AppSettings.Key.loadPlayerSkins) private var loadPlayerSkins = true
    @State private var confirmsReset = false

    var body: some View {
        Form {
            Section {
                Toggle("從 mc-heads.net 載入玩家皮膚", isOn: $loadPlayerSkins)
            } footer: {
                Text("開啟時會將玩家名稱與 UUID 傳送給 mc-heads.net。關閉後改用產生的像素頭像。")
            }
            Section {
                LabeledContent("伺服器清單") {
                    Button("在 Finder 中顯示") {
                        NSWorkspace.shared.activateFileViewerSelecting([ServerPersistence.standard.fileURL])
                    }
                }
                LabeledContent("還原預設伺服器") {
                    Button("還原…", role: .destructive) {
                        confirmsReset = true
                    }
                }
            } footer: {
                Text("伺服器清單、設定與上次的狀態都存在這個 JSON 檔中。")
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .confirmationDialog("要還原成預設伺服器清單嗎？", isPresented: $confirmsReset) {
            Button("還原", role: .destructive) {
                store.resetToDefaults()
                Task { await store.refreshAll() }
            }
        } message: {
            Text("你新增或修改的 \(store.servers.count) 台伺服器將被移除，且無法復原。")
        }
    }
}

#Preview {
    SettingsView(store: ServerStore(persistence: nil))
}
