# 效能分析與驗證（#84）

## 免下載站名搜尋（2026-10-10）

搜尋頁統一在一個搜尋框同時查路線與站名，讓 Web 版與尚未下載資料庫的裝置也能依站名查路線，並支援中英文與「台／臺」正規化。

- **後端**：新增 `GET /api/v1/stops/search`，只查靜態資料庫、不呼叫 TDX。以 `ROW_NUMBER()` 在每個 `(routeid, pathid)` 只取最符合的一站，先精確、再前綴、再部分比對。`cities` 以固定前綴 `GLOB` 套用索引；所有使用者輸入走參數化查詢，`%`、`_` 視為文字。`stopid` 保留原字串（含前導零）。
- **前端資料層**：一次請求涵蓋多個地區，查詢正規化後合併與快取（30 秒、上限 32 筆），並以 `_routeDataGeneration` 拒絕過期結果。本機資料庫優先，僅對未就緒的地區改走 API。
- **前端畫面**：同一次查詢先取路線，不像強路線比對時再解析站名。輸入變更立刻使進行中的舊查詢失效，避免慢回應在 debounce 期間覆蓋新查詢。部分地區失敗保留可用結果並顯示重試，全部失敗則顯示可重試的錯誤而非空結果。線上結果不預抓整條路線站序，選取時才解析上車站，並在無定位時直接帶入符合的方向與站牌。

### 本次驗證

| 檢查 | 結果 |
| --- | --- |
| `flutter test --no-pub --reporter expanded` | 482 項通過 |
| `flutter analyze --no-pub` | No issues found |
| `flutter build web --release --no-pub` | 成功輸出 `build/web`，Wasm dry run 通過 |
| 後端離線回歸（排除兩個需 TDX 憑證的手動探測腳本） | 366 項通過，另含 661 個 subtests |

新增回歸涵蓋：精確／前綴／部分排序、方向去重、`limit` 於去重後套用、中英文與「台／臺」、公路客運原字串站號、`%`／`_`／引號視為文字、城市範圍合併、參數驗證、多地區合併成一次請求、等價查詢合併與快取、失敗／格式錯誤可重試、資料庫失效不復原舊結果、輸入變更不被舊回應覆蓋、部分失敗保留本機結果、總失敗顯示重試，以及無定位時導向正確站牌。

Web build 與 Wasm dry run 通過，但 `flutter test --platform chrome` 在本機環境仍會逾時（與 #84 相同現象），因此 Web 執行期測試維持未驗證。發布時先部署後端 `/api/v1/stops/search`，再發布前端。

## 查車可靠性與請求控制（2026-10-10）

- **到站時間契約**：API 的 `eta_reference_at` 是 ETA 計算基準；`updated_at` 保留上游來源時間。App 只扣除計算基準之後經過的秒數，來源時間獨立用於 90 秒有效期限。舊 API 缺少基準時間時以收到回應的時間降級，避免重複扣除來源延遲。
- **過期資料**：後端失敗／304 不重設備援壽命；過期站牌清除 ETA 與車輛。共用 ETA badge 顯示本地化的過期狀態及最後更新時間，並以一次性計時器在期限到達時更新，不必等待下一次網路回應。合併路線變體時保留各車輛自己的時間基準。
- **請求生命週期**：JSON 請求涵蓋 headers 與 body 的 15 秒總期限，逾時只取消該請求；資料庫下載使用 30 秒 idle timeout。正常完成的串流不重複取消，以免阻塞上層 Future 的完成。
- **限流與重試**：路線／收藏畫面失敗後漸增退避至 60 秒，成功後恢復使用者設定；`Retry-After` 支援秒數與 HTTP-date，且可延長等待至超過 60 秒。資料層在冷卻期間阻止同額度的新請求，全公車地圖額度與一般查車分開。
- **路線變體**：詳情頁實際使用的 `enrichRouteWithFamily` 已使用批次 ETA，站序載入並行上限為 4；個別變體失敗不影響主路線及其他成功結果。
- **後端並行**：捷運、鐵路、自行車的同步 I/O 使用 FastAPI worker pool，重疊載入合併為一份；請求分析改為有界佇列、背景批次 SQLite 寫入。上游等待、節流與重試共用預算；車位來源失敗仍保留成功取得的 ETA。

### 本次驗證

| 檢查 | 結果 |
| --- | --- |
| `flutter test --no-pub --reporter expanded` | 471 項通過 |
| `flutter analyze --no-pub` | No issues found |
| `flutter build web --release --no-pub` | 成功輸出 `build/web`，Wasm dry run 通過 |
| 後端離線回歸（排除兩個需 TDX 憑證的手動探測腳本） | 331 項通過，另含 466 個 subtests |

回歸涵蓋重複扣時、90 秒過期、連續失敗／304、車位來源失敗、慢上游並行、分析佇列滿載／寫入失敗／關機、body 停滯／持續緩慢傳送、限流冷卻、實際路線變體批次請求及部分失敗。完整套件也驗證地圖、整站、天氣與意見回饋的既有行為。

以上為自動化正確性與建置驗證；本次未進行 Android 真機或瀏覽器互動效能量測，不能換算成載入時間或 FPS 改善幅度。發布時先部署後端新增的時間欄位，再發布前端。

## Android 漸進式啟動

啟動流程採用「保留外觀、漸進載入」：`main.dart` 在 `runApp` 前只等待啟動入口、版本資訊與 `initializeForFirstFrame()`，後者只載入設定及修改時間。既有主題、語言、首次使用狀態與背景路徑可立即使用；自動配色優先使用路徑相符的取色快取，再於首個畫面後更新。

- 帳號、收藏、路線歷史、智慧使用紀錄及公告狀態分為獨立的載入領域。同一領域的操作共用進行中的 Future；讀取失敗可以重試，不能用未載入的空集合覆寫資料。
- `initialized` 表示首頁所需設定已就緒，不代表所有本機集合已就緒。需要完整資料的呼叫端可使用 `initialize()`／`ensureLocalDataReady()`；相關操作須等待對應的 `ensure…Ready()`。
- 收藏與帳號頁面在必要資料就緒前顯示載入狀態。搜尋入口可先使用，歷史紀錄稍後補齊；推薦資料及資料庫狀態未知時，不先發起「沒有學習紀錄」的附近站牌備援請求。
- 路線開啟僅儲存路線使用紀錄，不再順便覆寫尚未載入的收藏使用與站牌造訪紀錄。推薦刷新使用修訂值，路線簽章只在組成資料變更後重算。
- 圖片路徑修復與清理移至首個畫面後，並與背景圖片設定變更共用序列。修復保留當前外觀及真正的使用者修改時間，不觸發設定同步。
- 所有廣告載入入口等待共用的首個 rasterized frame 閘門；首頁不無條件初始化廣告。啟用 Android Ads 初始化／載入最佳化旗標。
- Android `YABusApplication` 提供 WorkManager 隨用初始化設定，只移除其 AndroidX Startup metadata，保留其他 initializer。小工具與背景程序仍可透過 `WorkManager.getInstance()` 排程及取消工作。

### 驗證

- `flutter test`：**461 項全部通過**。新增情境包括設定優先啟動、阻塞資料載入時首頁可見、早期收藏變更、窄化路線紀錄儲存、載入中清除、讀取失敗重試、dispose 後回應、舊帳號驗證回應及圖片維護競態。
- `progressive_startup_test.dart` 明確模擬 Android home-integration 通道，避免本機及 Linux CI 的 `MissingPluginException`。沒有停用三項原本失敗的測試。
- `YABusApplicationTest`：**2 項通過**，驗證 merged manifest 未啟動 WorkManager initializer，以及沒有 Flutter Activity 的程序可以初始化、排程及取消工作。
- 尚未連接 Android 實機量測冷啟動，不能由單元測試或建置時間推算縮短秒數。正式版 APK 建置曾逾時，尚未確認成功輸出。

實機驗收須固定同一裝置及資料，分開量測 Logo 消失／首個 Flutter 畫面、主要操作可用、收藏／推薦資料就緒，以及啟動後首次點擊延遲。比較無背景、自動配色、大量歷史、離線、通知／小工具開啟；Android 第一幀自動回報的 fully-drawn 時間不能直接代表漸進載入完成。

## 本次確認的熱點與修改

| 範圍 | 程式碼證據 | 修改 |
| --- | --- | --- |
| 公車 API 資料解析 | `BusRepository` 原有 22 處在 HTTP 回應後同步呼叫 `jsonDecode(apiResponseText(response))`；包含 Brotli 解壓縮、UTF-8 與 JSON 解析 | 改用 `apiDecodeJsonResponseAsync`。原生平台對 64 KiB 以上的回應或含 Brotli 編碼的回應使用 `compute`，DevTools isolate 標籤為 `api.decodeJson`。僅傳送 bytes 與編碼資訊，不傳送 HTTP client／request。小型未壓縮回應避免啟動 isolate 的成本 |
| 路線搜尋排序 | 每次 comparator 比較都正規化 query、兩筆路線文字、建立排名物件並計算縣市優先序 | 每次搜尋先建立排名與優先序，再排序。排名計算從 O(n log n) 次降至 O(n) 次；排序本身仍是 O(n log n)。快取只存活於該次排序 |
| 自訂背景與列表重繪 | 背景圖片與前景內容原本共享 Stack 的繪製範圍 | 各自加入 `RepaintBoundary`，讓 GIF 動畫與前景更新有獨立的重繪邊界。實際 raster 時間與圖層記憶體成本仍需量測 |

64 KiB 是起始分流門檻，尚未以低階 Android 實機調校。Brotli 壓縮後大小無法代表解壓縮成本，因此原生平台的 Brotli 回應一律走背景解析。

### 已存在的機制

本次閱讀程式碼確認：

- 路線主要站牌列表使用 `ListView.separated` 延遲建立項目。
- 路線拓撲與即時 ETA 分階段載入；倒數使用 `ValueListenableBuilder`，進度動畫局部更新。
- 路線資料有 TTL 快取、同時請求合併與資料失效世代檢查。
- 全公車地圖有視窗篩選、聚合標記、局部動畫更新，以及頁面／App 隱藏時暫停輪詢。
- `MaterialApp` 監聽 `themeRevision`，已有將主題重建與一般 controller 通知分開。

以上是程式碼層級的確認，不能代替真實操作的 CPU／幀率追蹤。

## 自動化驗證結果

環境：Windows x64、Flutter 3.44.2、Dart 3.12.2。

- `flutter test --reporter expanded`：**300 項通過**，涵蓋路線分階段載入、快取／同時請求合併、資料失效、列表捲動保留、地圖生命週期及新增解析／排序測試。
- `flutter analyze`：無 error／warning；仍有兩處既有 `onReorder` 棄用 info，位於 `app_controller.dart`、`favorites_screen.dart`。
- `flutter build web --release`：成功，Wasm dry run 也通過。
- Chrome 測試：編譯成功，Chrome 與測試套件啟動後未回報測試結果；整組測試於 180 秒逾時，單獨解析測試重試於 90 秒逾時。**Web 執行測試尚未通過**，原因未確認。
- `flutter devices` 未列出 Android 裝置，**尚未進行 Android 實機效能驗收**。

新增回歸測試涵蓋：小型 JSON、UTF-8、5,000 筆站牌的大型 JSON、Brotli、已由 HTTP 層解壓縮的回應、兩種解析路徑的錯誤傳播、排序相容性與優先序計算次數。

### 可重跑的排序基準

```sh
flutter test test/performance/route_search_benchmark_test.dart --reporter expanded
flutter test test/api_http_test.dart test/route_search_ranking_test.dart test/performance/route_search_benchmark_test.dart --platform chrome --reporter expanded
```

固定種子打散 10,000 筆路線，先暖機 5 次，再交錯量測各 15 次取中位數。基準使用保留的逐次計算 comparator，並驗證新舊排序輸出一致。沒有以耗時設定 CI 通過門檻。

| Windows 原生測試執行器 | 舊 comparator | 預先計算排名 |
| --- | ---: | ---: |
| 定向測試執行 | 145.983 ms | 23.449 ms |
| 完整測試並行執行 | 209.253 ms | 29.556 ms |

定向測試約快 **6.2 倍**。這是 debug/JIT 下的 CPU 微型基準，會受背景負載影響，**不是 Android／Web 的幀率數據，也不是頁面切換速度**。

## 尚待完成的實機驗收

### 操作流程

1. 在低階 Android 真機以 `flutter run --profile -d <device-id>` 執行；Web 以 `flutter run --profile -d chrome` 執行。
2. 固定相同 API 資料、裝置、螢幕更新率與設定，分別記錄冷啟動和暖快取。每個情境重複至少 3 次，每次錄製 30 秒。
3. 執行首頁 → 搜尋 → 路線詳情 → 返回，快速輸入與刪除查詢文字。
4. 選擇站牌較多的路線，持續捲動、切換方向，同時等待 ETA 更新。以網路節流檢查載入中仍能捲動／返回。
5. 開啟全公車地圖，縮放、拖曳、選取路線；切換到其他頁面及背景再返回，確認輪詢沒有重疊。
6. 分別測試無背景、靜態大圖、GIF 背景；比較重繪範圍、raster 時間與記憶體，確認新增圖層的取捨。

### 記錄方式

- Android：Flutter DevTools Performance 記錄 UI／raster frame 的 p50／p95／p99 與超過 frame budget 的比例；CPU profiler 檢查解析、模型轉換、排序；確認大型回應解析出現在 `api.decodeJson` isolate。
- Widget rebuild 診斷另開一次追蹤，不把額外診斷開銷混入正式幀率比較。
- Web：Chrome Performance 記錄 main-thread long task、frame 與輸入延遲；Network 比較重複 API 請求。以相同 CPU／網路節流設定比較前後版本。
- Memory：進出頁面 20 次並經過 GC 後，比較 retained heap、image cache 與路線快取；記錄峰值與回收後大小。
- 60 Hz 裝置的 frame budget 為 16.67 ms；120 Hz 為 8.33 ms。驗收報告需列出實際裝置與預算，不能用單元測試時間換算 FPS。

### 後續待量測的項目

- Web 的 JSON 解碼仍在主執行緒；本次未加入 Web Worker。若 profile 顯示 long task，需評估 Worker 或後端資料分批。
- JSON 轉成路線／站牌模型、polyline 展開仍在主執行緒；需依 trace 決定是否連同解析一起移入背景或分批處理。
- 公車資料層部分快取僅在讀取同一個 key 時淘汰過期值；長時間跨路線操作的記憶體成長需量測，必要時加容量上限。
- 原尺寸背景解碼、全域 controller 依賴的 rebuild 範圍需以 image memory／rebuild 記錄確認。

**#84 尚不能僅憑本次測試結案：Android／Web 的主要操作幀率、長時間記憶體與載入中互動仍待實機 profile 驗收。**
