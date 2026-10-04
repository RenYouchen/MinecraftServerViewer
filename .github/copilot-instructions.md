# Minecraft Server Viewer - GitHub Copilot Instructions

## Project Overview
Minecraft Server Viewer is a SwiftUI macOS application that displays Minecraft server status information.

## Tech Stack
- **Language**: Swift 6.0+
- **UI**: SwiftUI
- **Network**: Foundation → Network.framework (future)
- **Platform**: macOS 14.0+
- **Xcode**: 15.0+

## Architecture

### MVVM Pattern (Implicit in SwiftUI)
```
┌─────────────────┐
│   ContentView    │ ← View (SwiftUI)
└────────┬─────────┘
         │
         │ State Management
         ▼
┌─────────────────┐
│  ServerStatus   │ ← Model
│    Model        │
└─────────────────┘

┌─────────────────────────────────┐
│      ServerStatusAPI             │ ← API Layer
│     (Network.framework)          │
└─────────────────────────────────┘
```

### Key Files
- `MinecraftServerViewerApp.swift` - App entry point
- `ContentView.swift` - Main UI with server list
- `DataModel.swift` - Pure Swift models
- `ServerStatusAPI.swift` - HTTP client (placeholder for real protocol)

## Data Models

### Player
```swift
class Player {
    let uuid: String
    let name: String
}
```

### ServerStatus
```swift
class ServerStatus {
    let serverName: String?
    let online: Bool
    let ip: String
    let port: Int
    let version: ServerVersion
    
    var players: [Player]     // Computed
    var playersOnline: Int    // Computed
    var playersMax: Int       // Computed
}
```

### ServerVersion
```swift
enum ServerVersion: String, Codable {
    case java, bedrock, legacy
    
    var versionName: String {
        switch self {
        case .java:  return "Java"
        case .bedrock:  return "Bedrock"
        case .legacy:  return "Legacy"
        }
    }
}
```

## Critical: Minecraft Protocol Reality

### IMPORTANT WARNING
Real Minecraft server status requires **low-level TCP protocol implementation**, NOT standard REST API.

**Current State**: `ServerStatusAPI.fetchMOTD()` uses `URLSession` as a placeholder.

**To Implement Real Protocol**:
1. Use `Network.framework` for custom TCP sockets
2. Implement Minecraft Status Ping protocol
3. Handle Minecraft's MOTD encoding (Unicode + styles)
4. Support both Java (25565) and Bedrock (19132) ports

### Bedrock Protocol Example
```swift
struct StatusResponse: Decodable {
    let players: Players
    let server: Server
    let description: Description
    let version: Version
    let favicon: String?  // Base64 encoded
}

struct Description {
    let plain: String
    let extra: [TextComponent]  // Rich text with styles
}

struct TextComponent {
    let text: String
    let bold: Bool?
    let italic: Bool?
    let underline: Bool?
    let color: String?  // Minecraft color codes
}
```

## Error Handling

### ServerStatusError
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
        case .badResponse:
            return "Invalid HTTP response status code."
        case .motdNotFound:
            return "MOTD not found in server status."
        case .networkFailed(let desc):
            return "Network request failed: \(desc)"
        case .parsingFailed(let desc):
            return "Data parsing failed: \(desc)"
        }
    }
}
```

## Development Guidelines

### 1. API Implementation
- Use `async/await` for all network operations
- Handle all possible error cases from `ServerStatusError`
- Provide user-friendly error messages in UI

### 2. Network Framework Usage
```swift
import Network

// Create custom TCP socket
let socket = NWEndpoint.transport.socket(.init(
    address: NWHostEndpoint.host(port: Int(port)).host,
    protocol: .tcp
))

// Connect to server
socket.stateUpdateHandler = { state in
    switch state.state {
    case .ready:
        // Send status request
    case .failed:
        // Handle error
    }
}
```

### 3. SwiftUI Best Practices
- Keep views declarative and pure
- Use `@State` for local state
- Use `@Published` if introducing Combine
- Implement `ObservableObject` for view models
- Use `.animation()` for smooth transitions

### 4. Code Style
- Follow Swift naming conventions
- Use `async`/`await` for async operations
- Prefer `let` over `var` when possible
- Add doc comments for public APIs
- Use trailing closure syntax

### 5. Error Handling
- Never catch errors without handling them
- Present errors to user in appropriate context
- Log errors for debugging

## Build Commands

```bash
# Build
xcodebuild -project MinecraftServerViewer.xcodeproj \
    -scheme MinecraftServerViewer \
    -configuration Debug \
    -sdk macosx \
    -destination 'platform=macOS' build

# Run tests
xcodebuild test -project MinecraftServerViewer.xcodeproj \
    -scheme MinecraftServerViewer

# Clean build
xcodebuild clean -project MinecraftServerViewer.xcodeproj

# Archive
xcodebuild -project MinecraftServerViewer.xcodeproj \
    -scheme MinecraftServerViewer \
    -configuration Release \
    -archivePath build/Release/MinecraftServerViewer.xcarchive \
    archive
```

## Testing Guidelines

1. **Unit tests**: Test model transformations and business logic
2. **API tests**: Mock network calls before implementing real protocol
3. **UI tests**: Test navigation and user interactions
4. **Edge cases**: Test empty states, error states, network failures

## Project Configuration

- **Swift**: 6.0+
- **macOS**: 14.0+
- **Xcode**: 15.0+
- **Language**: Swift
- **Deployment**: macOS only

## External Resources

- [Minecraft Bedrock Protocol](https://wiki.vg/Bedrock_Edition_Protocol)
- [Minecraft Java Protocol](https://wiki.vg/Java_Edition_Protocol)
- [Network.framework](https://developer.apple.com/documentation/network)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)

## Known Issues & TODOs

### High Priority
- [ ] Implement real Minecraft protocol using Network.framework
- [ ] Add server add functionality
- [ ] Handle MOTD Unicode and style encoding
- [ ] Support both Java and Bedrock protocols

### Medium Priority
- [ ] Add server icons/avatars
- [ ] Improve error messages
- [ ] Add loading states
- [ ] Implement server filtering/search

### Low Priority
- [ ] Dark mode support
- [ ] Server statistics (ping, uptime)
- [ ] Server ranking system
- [ ] Export server lists

## Code Examples

### Fetching Server Status
```swift
func fetchServerStatus(host: String, port: String) async throws -> ServerStatus {
    // TODO: Implement with Network.framework
    // Placeholder for now
    return try await ServerStatusAPI.shared.fetchMOTD(host: host, port: port)
}
```

### Adding a Server
```swift
func addServer(serverName: String, ip: String, port: Int) {
    // 1. Validate input
    // 2. Create ServerStatus model
    // 3. Add to servers state array
    // 4. Update UI
}
```

### Parsing MOTD with Styles
```swift
func parseMOTD(encodedMOTD: String) -> (plain: String, formatted: String) {
    // 1. Decode UTF-8 with style information
    // 2. Handle color codes (\u{10}0 = black, etc.)
    // 3. Return styled and plain text
}
```

## Notes for AI Assistants

- This project is **not a REST API** - real Minecraft servers use TCP protocol
- Always verify network implementation approach
- Handle both Java and Bedrock protocol differences
- MOTD encoding requires special handling for Unicode and styles
- Error handling is critical for network operations
- Keep data models pure and testable
