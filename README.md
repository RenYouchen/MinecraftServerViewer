# Minecraft Server Viewer

一個用 SwiftUI 打造的 macOS App，用來監看 Minecraft 伺服器的狀態：是否在線、玩家人數與名單、延遲、MOTD，並附有桌面／通知中心小工具。

App 直接實作 Minecraft 的狀態查詢協定（不依賴任何第三方 API）：

- **Java 版**：TCP [Server List Ping](https://minecraft.wiki/w/Java_Edition_protocol/Server_List_Ping)，未指定連接埠時會先查詢 `_minecraft._tcp` SRV 記錄
- **Bedrock 版**：RakNet Unconnected Ping（UDP）

## 功能

- **伺服器清單**：新增、編輯、移除伺服器，可搜尋並篩選只看在線的伺服器
- **詳細資訊**：
  - MOTD（支援 `§` 顏色與格式碼）
  - 伺服器圖示、版本與協定編號
  - 玩家人數與玩家名單
  - 延遲與延遲紀錄圖表
- **玩家資訊**：點擊玩家可查看全身皮膚、完整 UUID、帳號類型（正版／離線模式），並可連到 NameMC
- **自動更新**：每台伺服器可設定檢測頻率（1 秒到 5 分鐘，或手動），也能一次修改所有伺服器
- **本機儲存**：伺服器清單、設定與上次的狀態會存成 JSON，重新開啟時立即顯示，再於背景更新
- **設定（⌘,）**：
  - 新伺服器預設的檢測頻率
  - 啟動時是否更新所有伺服器
  - 連線逾時
  - 延遲紀錄保留筆數
  - 是否載入玩家皮膚
  - 還原預設伺服器清單
- **小工具**：小、中、大三種尺寸，附重新整理按鈕；小尺寸可選擇要顯示的伺服器

## 安裝

到 [Releases](https://github.com/RenYouchen/MinecraftServerViewer/releases) 下載最新的 `MinecraftServerViewer-*.zip`，解壓縮後把 `MinecraftServerViewer.app` 拖進「應用程式」資料夾。

這個版本使用開發者憑證簽署、沒有經過 Apple 公證（notarization），所以第一次開啟時 macOS 會擋下來。請用以下任一方式開啟：

- 在 Finder 中對 App 按右鍵 › 「打開」，再按一次「打開」
- 或到「系統設定 › 隱私權與安全性」，在下方按「強制打開」
- 或在終端機執行：`xattr -dr com.apple.quarantine /Applications/MinecraftServerViewer.app`

## 系統需求

- macOS 26.2 以上
- Xcode 27 以上（建置用）
- Apple Developer 帳號：App 與小工具透過 App Group 共用資料，需要簽署（免費帳號也可以）

## 建置與執行

```bash
# 建置並啟動（Debug）
scripts/run.sh

# 在終端機前景執行，可看到 print() 輸出
scripts/run.sh --logs

# 建置 Release
scripts/run.sh --release
```

腳本會把產物放在 `build/`，並重新向系統登錄 App，讓 Finder 與 Dock 讀到最新的圖示。

也可以直接用 Xcode 開啟 `MinecraftServerViewer.xcodeproj`，選擇 `MinecraftServerViewer` scheme 執行。

> **使用自己的開發者帳號建置**：專案的 Team ID 是 `2C4X8AL22P`。若要用自己的帳號，請在 Xcode 的 Signing & Capabilities 更換 Team，並把下列三處的 App Group ID 改成你的 Team ID：
> - `Config/MinecraftServerViewer.entitlements`
> - `Config/ServerWidget.entitlements`
> - `Shared/Services/AppSettings.swift` 中的 `appGroupID`

## 小工具

1. 建置並執行一次 App。
2. 在桌面按右鍵 › 「編輯小工具…」，或打開通知中心 › 「編輯小工具」。
3. 搜尋「伺服器狀態」並加入。

| 尺寸 | 內容 |
|---|---|
| 小 | 單一伺服器（右鍵 › 編輯小工具可選擇伺服器） |
| 中 | 清單中的前 3 台 |
| 大 | 清單中的前 6 台與在線數量 |

小工具會自己查詢伺服器，所以 App 沒開時也會更新。小工具大約每 15 分鐘更新一次，實際頻率由 macOS 決定；按 ↻ 可立即重新整理。

**區域網路伺服器**：macOS 15 起，連線到區域網路需要「本地網路」權限，但小工具無法要求這個權限。因此對 `192.168.x.x`、`10.x.x.x`、`.local` 等位址，小工具會改為顯示 App 最後一次存下的狀態。

## 專案結構

```
MinecraftServerViewer/   App：進入點、主視窗、側邊欄、詳細資訊、表單、設定
  Services/ServerStore.swift   伺服器清單狀態（@Observable）、刷新與儲存
Shared/                  App 與小工具共用
  Models/                ServerStatus、ServerAddress、Player 等純資料模型與範例資料
  Services/              狀態查詢服務、JSON 儲存、使用者設定
  Services/Protocol/     Minecraft 協定：TCP/UDP 連線、封包編碼、SRV 查詢、聊天元件（MOTD）解析
  Views/                 共用的像素圖示、狀態指示元件
ServerWidget/            WidgetKit 小工具、設定 Intent、重新整理 Intent
Config/                  Entitlements（App Group）與小工具的 Info.plist
scripts/
  run.sh                 建置並啟動
  render_icon.py         產生 App 圖示（需要 Pillow）：scripts/render_icon.py [rack|pulse]
```

架構採 SwiftUI 原生的 MVVM：`ContentView` 等 View → `ServerStore` → `ServerStatusService`（Network.framework）→ 純資料模型。

## 資料儲存位置

| 資料 | 位置 |
|---|---|
| 伺服器清單與上次狀態 | `~/Library/Group Containers/2C4X8AL22P.com.renyouchen.MinecraftServerViewer/servers.json` |
| 設定 | App 的 `UserDefaults` |

也可以在「設定 › 資料 › 在 Finder 中顯示」直接打開。

## 第三方服務

開啟「從 mc-heads.net 載入玩家皮膚」時（預設開啟），App 會把玩家名稱與 UUID 傳送給 [mc-heads.net](https://mc-heads.net) 以取得頭像與全身皮膚；關閉後改用產生的像素頭像。其餘所有查詢都直接連線到伺服器本身。

## 備註

- 本專案與 Mojang Studios 或 Microsoft 無關。Minecraft 是 Mojang Synergies AB 的商標。
