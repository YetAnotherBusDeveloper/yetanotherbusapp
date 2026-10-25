
<img src="assets/branding/icon.png" width="90" height="90">
<h1>YetAnotherBusApp</h1>


現代化跨平台公車動態查詢 App

<p align="left">
  <a href="https://github.com/YetAnotherBusDeveloper/yetanotherbusapp/actions/workflows/build.yml">
    <img src="https://img.shields.io/github/actions/workflow/status/YetAnotherBusDeveloper/yetanotherbusapp/build.yml?branch=main">
  </a>
  <img src="https://img.shields.io/github/license/YetAnotherBusDeveloper/yetanotherbusapp">
  <img src="https://img.shields.io/github/stars/YetAnotherBusDeveloper/yetanotherbusapp">
  <img src="https://img.shields.io/github/downloads/YetAnotherBusDeveloper/yetanotherbusapp/total">
</p>

## 關於專案

YetAnotherBusApp（YABus）是一個以 Flutter 開發的跨平台公車動態查詢應用程式。

目標提供：

- 更直覺的使用體驗
- 更美觀的介面設計
- 支援多平台運行
- 開放原始碼、社群共同維護

目前支援：

- Android
- iOS
- Windows
- macOS
- Linux
- Web

## 功能特色

### 路線與站名搜尋

- 同一個搜尋框同時查路線與站名，不必切換模式；站名也能用英文、含數字的名稱查詢。
- 支援中英文站名及「台／臺」寫法，例如「市政府」、「City Hall」、「台北車站」。
- Web 版與尚未下載資料庫的裝置可直接使用線上站名搜尋；已有的離線資料仍優先使用。
- 結果保留路線方向與符合的站牌，點選後直接開啟對應路線與站牌；不需要先授予定位權限。
- 多地區的線上查詢合併成一次請求；部分地區失敗時保留可用結果並提供重試。

線上站名搜尋需要後端提供 `GET /api/v1/stops/search`。發布此版本時應先更新 API Server。

### 即時公車動態

- 查看公車目前位置
- 預估到站時間
- 發車狀態查詢

### 收藏路線

- 快速查看常用公車
- 個人化首頁

### 地圖顯示

- 顯示公車即時位置
- 路線視覺化
- Google Maps 與 OpenStreetMap 都能用兩指旋轉；旋轉後會出現指北針，點一下即轉回正北，公車方向箭頭仍指向實際行進方向

### 現代化介面

- Material Design 3
- 深色模式支援
- 響應式設計

### 跨平台支援

一次開發，多平台運行。


## 線上體驗

https://busapp.avianjay.sbs/


## 下載

### Stable Release

前往 Releases 頁面下載最新正式版本：

<p>
  <a href="https://play.google.com/store/apps/details?id=tw.avianjay.taiwanbus.flutter">
    <img alt="Get it on Google Play" src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" width="180">
  </a>
</p>

https://github.com/YetAnotherBusDeveloper/yetanotherbusapp/releases/latest


### Nightly Build

最新測試版本請從 [GitHub Releases](https://github.com/YetAnotherBusDeveloper/yetanotherbusapp/releases) 中標示為 Nightly 的預先發布版本下載。Nightly 只會指向 `main` 分支最近一次完整建置並成功發布的版本。

| 平台 | 發布檔案 |
| --- | --- |
| Android | `YABus-nightly-<commit>.apk` |
| Windows | `YABus-nightly-<commit>-windows-x64-setup.exe` |
| Linux | `YABus-nightly-<commit>-linux-amd64.deb` / `.AppImage` |
| macOS | `YABus-nightly-<commit>-macos.dmg` |

## 技術棧

### Framework

- Flutter

### Language

- Dart

### Data Source

- TDX 運輸資料流通服務

### Platforms

- Android
- iOS
- Windows
- macOS
- Linux
- Web


## 開發環境

### Requirements

- Flutter 3.x+
- Dart SDK
- Android Studio / VS Code
- Node.js 24.22.1（Web 工具；版本記錄於 `.node-version`）

### Clone

```bash
git clone https://github.com/YetAnotherBusDeveloper/yetanotherbusapp.git
cd yetanotherbusapp
```

### Install dependencies

```bash
flutter pub get
```

Web 開發／部署工具先切換至 `.node-version` 指定的 Node.js，再執行 `npm ci`。
支援的安全版本為 Node.js `22.23.4+`、`24.22.1+`、`26.12.1+`（各自的主版本），
修補 [CVE-2026-111497 / HTTP2Shell](https://nodejs.org/en/blog/vulnerability/october-2026-security-releases)。
安裝、Web 開發與部署命令會拒絕舊版 Node.js；只更新 npm 套件無法修補 Node 內建的解碼器。
App 的 `brotli` 套件為純 Dart 實作，未連結此次受影響的原生 C 解碼器。
`npm run serve:web` 改用 Flutter Web 開發伺服器（`http://127.0.0.1:8080`）。
Wrangler 依賴的本機 `workerd` 仍內嵌舊版 Brotli，因此暫停以 `wrangler dev`
執行本機 Worker；Wrangler 僅用於部署，由指定的安全版 Node.js 執行。

### Run

```bash
flutter run
```

### Build

Android

```bash
flutter build apk
```

Web

```bash
flutter build web
```

Windows

```bash
flutter build windows
```

---

## 貢獻

歡迎提交：

- Bug Report
- Feature Request
- Pull Request

如果有任何建議或問題，歡迎開 Issue 討論

## 授權

本專案採用 AGPL-3.0 license

## Acknowledgements

- TDX 運輸資料流通服務
- Flutter Team
