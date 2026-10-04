# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Minecraft Server Viewer is a macOS desktop application built with SwiftUI that monitors Minecraft server status information.

**Tech Stack:**
- **Language**: Swift 6.0+
- **UI**: SwiftUI
- **Network**: Foundation (Network.framework for TCP protocol)
- **Platform**: macOS 14.0+
- **Xcode**: 15.0+

## Architecture

### MVVM Pattern (SwiftUI-native)

```
┌─────────────────────────────────┐
│      ContentView                 │ ← View (SwiftUI)
│      - servers: [ServerStatus]   │   - Manages state
│      - showAlert: Bool           │     - User interactions
└───────────┬──────────────────────┘
            │ State Management (SwiftUI @State)
            ▼
┌─────────────────────────────────┐
│       ServerStatusAPI           │ ← Service Layer
│     (Network.framework)         │     - Handles TCP protocol
└───────────┬──────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│         DataModel               │ ← Pure Models
│ - Player                         │     - No side effects
│ - ServerStatus                   │     - Computed properties
│ - ServerVersion (enum)          │
└─────────────────────────────────┘
```

### Data Flow

`ContentView` → `ServerStatusAPI` → JSON Parse → `ServerStatus` → UI Render

## Key Files

- `MinecraftServerViewerApp.swift` - App entry point (`@main`)
- `ContentView.swift` - Main UI with server list display
- `ServerStatusAPI.swift` - Network service (placeholder with URLSession)
- `DataModel.swift` - Pure Swift models

## Minecraft Protocol Implementation

**Critical Context**: Real Minecraft servers use TCP protocol, not HTTP/REST.

- **Java Edition**: Port 25565
- **Bedrock Edition**: Port 19132

**Current State**: `ServerStatusAPI.fetchMOTD()` uses `URLSession` as a placeholder.

**To Implement Real Protocol**:
1. Use `Network.framework` for custom TCP sockets
2. Implement Minecraft Status Ping protocol
3. Handle MOTD encoding (Unicode + rich text styles)
4. Support both Java and Bedrock ports

## Development Commands

```bash
# Build
xcodebuild -project MinecraftServerViewer.xcodeproj \
    -scheme MinecraftServerViewer \
    -configuration Debug \
    -destination 'platform=macOS' build

# Run tests
xcodebuild test -project MinecraftServerViewer.xcodeproj \
    -scheme MinecraftServerViewer

# Clean build
xcodebuild clean -project MinecraftServerViewer.xcodeproj
```

## Error Handling

Use `ServerStatusError` enum for unified error handling:

```swift
enum ServerStatusError: Error, LocalizedError {
    case invalidURL
    case badResponse
    case motdNotFound
    case networkFailed(String)
    case parsingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid host or port format."
        case .networkFailed(let desc):
            return "Network request failed: \(desc)"
        case .parsingFailed(let desc):
            return "Data parsing failed: \(desc)"
        }
    }
}
```

## Data Models

### ServerStatus
```swift
class ServerStatus {
    let serverName: String?
    let online: Bool
    let ip: String
    let port: Int
    let version: ServerVersion
    
    var players: [Player]          // Computed
    var playersOnline: Int         // Computed
    var playersMax: Int            // Computed
}
```

### Player
```swift
class Player {
    let uuid: String
    let name: String
}
```

## Known Issues & TODOs

### High Priority
- [ ] Implement real Minecraft TCP protocol using Network.framework
- [ ] Handle MOTD Unicode and style encoding (color codes, rich text)
- [ ] Support both Java and Bedrock protocols

### Medium Priority
- [ ] Add server add/remove functionality
- [ ] Add server icons/avatars
- [ ] Improve error messages in UI
- [ ] Implement loading states

### Low Priority
- [ ] Dark mode support
- [ ] Server statistics (ping, uptime)
- [ ] Server ranking system

## Notes for AI Assistants

- This project is **not a REST API** - real Minecraft servers use TCP protocol
- Always verify network implementation approach before writing code
- MOTD parsing requires special handling for Unicode and Minecraft color codes
- Keep data models pure (no side effects, no UI references)
- Use `async/await` for all network operations
- Handle both Java and Bedrock protocol differences
