# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Minecraft Server Viewer is a macOS SwiftUI app (plus a WidgetKit widget) that monitors Minecraft servers: online state, player count and list, latency history, version, favicon and MOTD. It implements the Minecraft status protocols itself — no third-party status API.

**Tech Stack:**
- **Language**: Swift (language mode 5, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency)
- **UI**: SwiftUI, WidgetKit, App Intents
- **Network**: Network.framework (TCP/UDP), `dnssd` for SRV lookups
- **Platform**: macOS 26.2+
- **Xcode**: 27+
- **Targets**: `MinecraftServerViewer` (app) and `ServerWidgetExtension` (widget). There is no test target.

UI strings are Traditional Chinese (zh-Hant); keep new user-facing text consistent with that. Code comments are in English.

## Architecture

```
Views (ContentView, ServerSidebar, ServerDetailView, ServerFormSheet, SettingsView)
        │
        ▼
ServerStore (@Observable)          ← app only: list state, refresh scheduling, saving
        │
        ├── ServerStatusService     ← protocol; MinecraftServerStatusService is the real one
        │        └── Protocol/      ← JavaStatusPinger, BedrockStatusPinger, SRVResolver, …
        └── ServerPersistence       ← servers.json in the App Group container
                 │
                 ▼
        Models (ServerStatus, ServerAddress, Player, ServerEdition) — pure value types
```

The widget does not use `ServerStore`: `ServerTimelineProvider` loads the list via `ServerPersistence.standard` and calls `MinecraftServerStatusService` directly.

## Key Files

```
MinecraftServerViewer/                 App target
  MinecraftServerViewerApp.swift       @main, registers AppSettings defaults
  ContentView.swift                    NavigationSplitView + auto-refresh loop
  Services/ServerStore.swift           @Observable list state; refresh/add/update/remove; saves on every change
  Views/                               Sidebar, detail (players, ping chart), add/edit sheet, settings
  Views/Components/MOTDFormatter.swift `§` codes → AttributedString
Shared/                                Compiled into both targets
  Models/DataModel.swift               ServerStatus, ServerAddress, Player, ServerEdition, PingQuality, ServerStatusError
  Models/SampleData.swift              ServerStatus.defaults / .samples
  Services/ServerStatusService.swift   MinecraftServerStatusService (+ MockServerStatusService)
  Services/ServerPersistence.swift     JSON load/save, legacy-file migration, corrupt-file backup
  Services/AppSettings.swift           UserDefaults keys/defaults, appGroupID
  Services/Protocol/
    MinecraftConnection.swift          Async NWConnection wrapper (TCP and UDP)
    PacketCoding.swift                 VarInt / string packet encoding
    StatusPingers.swift                JavaStatusPinger (Server List Ping), BedrockStatusPinger (RakNet Unconnected Ping)
    SRVResolver.swift                  `_minecraft._tcp` SRV lookup via dnssd
    ChatComponent.swift                JSON text component → legacy `§` string
  Views/                               PixelArt (block icons), StatusIndicators
ServerWidget/                          Widget bundle, timeline provider, SelectServerIntent, views
Config/                                Entitlements (App Group) and widget Info.plist
scripts/run.sh                         Build and launch
scripts/render_icon.py                 Generates the app icon (needs Pillow)
```

## Minecraft Protocol

- **Java** (default port 25565): TCP Server List Ping — handshake (protocol version -1) → status request → JSON response → ping/pong for latency. If the address has no port and the host is not an IP literal, the `_minecraft._tcp.<host>` SRV record is tried first; the actual target is stored in `ServerStatus.resolvedAddress`.
- **Bedrock** (default port 19132): RakNet Unconnected Ping over UDP. Bedrock does not report player names, so `players` is `nil`.
- MOTD: Java's JSON `description` is flattened by `ChatComponent` into a legacy `§`-coded string, stored raw in `ServerStatus.motd`, and rendered by `MOTDFormatter`.
- Timeout comes from `AppSettings.connectionTimeout`.

## Data & Persistence

- `ServerStatus` is a `Codable` struct holding both user settings (`serverName`, `address`, `edition`, `iconStyle`, `refreshInterval`) and the last status (`online`, `players`, `latency`, `pingHistory`, `favicon`, `errorMessage`, `lastChecked`, …).
- `ServerAddress` parses `host`, `host:port`, and `[IPv6]:port`; `port == nil` means "use SRV/default".
- The list is saved to `~/Library/Group Containers/2C4X8AL22P.com.renyouchen.MinecraftServerViewer/servers.json`, shared with the widget. `ServerStore.servers` saves on every `didSet` — batch changes into one assignment.
- `ServerStore.applyStatus` merges refresh results without overwriting settings edited mid-refresh, and drops results whose address/edition changed.
- Settings live in `UserDefaults` (`AppSettings.Key`); views use `@AppStorage` with the same keys.

## Widget Notes

- Small widget shows one server chosen via `SelectServerIntent`; medium shows the first 3, large the first 6.
- Widget extensions cannot request the Local Network permission (macOS 15+), so LAN addresses (`ServerAddress.isOnLocalNetwork`) are not pinged by the widget — it shows the app's last saved status. Other failures fall back to a saved result younger than 10 minutes.
- The app calls `WidgetCenter.shared.reloadAllTimelines()` only when the list changes.

## Error Handling

Errors are `ServerStatusError` (`invalidURL`, `badResponse`, `motdNotFound`, `timeout`, `networkFailed`, `parsingFailed`) with zh-Hant `errorDescription`s. On failure, `ServerStore.refresh` marks the server offline and stores `error.localizedDescription` in `errorMessage`.

## Development Commands

```bash
# Build and launch (Debug; output in build/)
scripts/run.sh
scripts/run.sh --logs      # run in foreground to see print() output
scripts/run.sh --release

# Build only
xcodebuild -project MinecraftServerViewer.xcodeproj \
    -scheme MinecraftServerViewer \
    -configuration Debug \
    -destination 'platform=macOS' build
```

Signing is required (App Group shared with the widget). Team ID `2C4X8AL22P` appears in both `Config/*.entitlements` and `AppSettings.appGroupID` — change all three together.

## TODOs

- [ ] Server categories: group servers in the sidebar (e.g. survival, minigames)
- [ ] Widget server selection: let medium/large widgets choose which servers to show (small widget already picks one via `SelectServerIntent`)
- [ ] Widget category filter: let widgets filter servers by category (depends on server categories)
- [ ] Local server detection: find Minecraft servers running on this Mac (e.g. probe localhost on the default Java/Bedrock ports)
- [ ] LAN discovery: scan the local network for servers on other hosts (Java LAN worlds announce via multicast 224.0.2.60:4445; Bedrock answers RakNet Unconnected Ping broadcast on 19132)
- [ ] Server statistics beyond latency (uptime)
- [ ] Server ranking system

## Notes for AI Assistants

- Real servers use TCP (Java) / UDP (Bedrock), not HTTP — extend the code in `Shared/Services/Protocol/`.
- Code in `Shared/` is compiled into both targets; it must not depend on app-only types like `ServerStore`.
- Types are `MainActor` by default; mark protocol/model types `nonisolated` and network work `@concurrent`, matching existing code.
- Keep models pure value types (no side effects, no UI references).
- Use `async/await` for all network operations.
- When adding a persisted field to `ServerStatus`, keep decoding of existing `servers.json` files working (a decode failure moves the file to `servers.json.corrupt`).
