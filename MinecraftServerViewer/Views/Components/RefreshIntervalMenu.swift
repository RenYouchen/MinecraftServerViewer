//
//  RefreshIntervalMenu.swift
//  MinecraftServerViewer
//

import SwiftUI

/// Menu for choosing how often servers are checked. `nil` means manual only.
struct RefreshIntervalMenu: View {
    /// The current interval; ignored when `isMixed`.
    let interval: TimeInterval?
    /// Servers use different intervals, so no choice is checked.
    var isMixed = false
    var label: String?
    var onChange: (TimeInterval?) -> Void

    var body: some View {
        Menu {
            ForEach(ServerStatus.refreshIntervalChoices, id: \.self) { choice in
                item(ServerStatus.refreshIntervalLabel(choice), value: choice)
            }
            Divider()
            item("手動（不自動檢測）", value: nil)
        } label: {
            Label(label ?? Self.title(for: interval), systemImage: "timer")
        }
        .fixedSize()
        .help("修改檢測時間")
    }

    static func title(for interval: TimeInterval?) -> String {
        interval.map { ServerStatus.refreshIntervalLabel($0) } ?? "手動"
    }

    /// A Toggle renders as a checkmarked menu item on macOS.
    private func item(_ title: String, value: TimeInterval?) -> some View {
        Toggle(title, isOn: Binding(
            get: { !isMixed && interval == value },
            set: { _ in onChange(value) }
        ))
    }
}
