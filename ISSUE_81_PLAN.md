# Issue #81：根據定位與步行時間判斷是否來得及搭車

Issue：https://github.com/YetAnotherBusDeveloper/yetanotherbusapp/issues/81

## 目標

根據使用者目前位置、Google 實際步行路線、公車 ETA 與即時資料品質，提供保守且不保證結果的搭車建議。

第一版涵蓋：

- 路線詳情的最近站牌
- 附近站牌結果
- 首頁智慧推薦與附近路線 fallback

所有文案必須使用「預估」、「可能」等措辭，不能表示使用者一定能搭上公車。

## 系統設計

這項功能需同時修改兩個專案：

- 前端：`YetAnotherBusDeveloper/yetanotherbusapp`
- API：`YetAnotherBusDeveloper/busapiserver`

前端不直接持有 Google Routes API Key。所有步行路線請求皆透過 YaBus API Server 轉送。

## 後端步行路線 API

在 `busapiserver` 新增：

```http
POST /api/v1/walking/routes
```

### Request

```json
{
  "origin": {
    "lat": 25.033,
    "lon": 121.5654
  },
  "destinations": [
    {
      "id": "stop-1",
      "lat": 25.034,
      "lon": 121.566
    }
  ]
}
```

### Response

```json
{
  "routes": [
    {
      "id": "stop-1",
      "distance_meters": 420,
      "duration_seconds": 330,
      "status": "available"
    }
  ],
  "generated_at": "2026-09-21T12:00:00Z"
}
```

單一目的地無法計算時，該元素回傳 `unavailable`，不可讓整批請求失敗。

### Google Routes 整合

使用：

```text
POST https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix
```

設定：

- `travelMode: WALK`
- 不設定只適用於汽車或機車的 `routingPreference`
- Field mask：`originIndex,destinationIndex,status,condition,distanceMeters,duration`
- API Key 使用後端環境變數 `GOOGLE_ROUTES_API_KEY`

### 後端防護

- 每次最多 12 個目的地
- 驗證所有經緯度與目的地 ID
- 限制目的地與起點的合理直線距離
- Google 請求加入 timeout
- 使用獨立 rate-limit bucket
- API Key 未設定時回傳明確的 service unavailable
- 不記錄 request body 中的精確座標
- 不將 API Key 回傳或暴露給前端
- 設定 Google Cloud 每日配額及費用告警

Google Compute Route Matrix 依 element 計費；一個 origin 與 12 個 destinations 會計為 12 個 elements。

## 前端步行路線服務

新增獨立的步行路線 model 與 service，由 `AppController` 共用，避免各畫面自行發送重複請求。

應具備：

- 一個起點批次查詢多個站牌
- 依目的地 ID 對應 Google matrix 結果
- 部分失敗容錯
- request generation，拒絕過期非同步結果
- 使用者移動超過約 50 公尺後才重新計算
- 步行結果快取約 1 至 2 分鐘
- 公車 ETA 每 10 秒更新時不重新呼叫 Google Routes
- 步行服務失敗時不影響原本 ETA 與路線內容

## 搭車判斷模型

新增純 Dart evaluator，例如：

```text
lib/core/catch_bus_recommendation.dart
```

### 輸入

- Google 步行距離
- Google 步行時間
- 使用者位置時間
- GPS horizontal accuracy
- 公車有效 ETA
- ETA 更新時間
- ETA 是否為推估或 backfill
- `carOnStop`
- 即時訊息
- 車輛 ID（若存在）
- 目前時間，由呼叫端注入以利測試

### 輸出狀態

- `likelyCatchable`：預估來得及
- `tight`：時間接近，可能來不及
- `likelyMiss`：建議搭下一班
- `atStop`：公車進站中
- `departed`：有可靠離站證據時才使用
- `unavailable`：定位、步行路線或即時資料不足

### 保守判斷原則

- 定位超過 2 分鐘時不做正向判斷
- GPS accuracy 過差時顯示資料不足
- ETA 超過現有 90 秒有效範圍時不判斷
- Google 步行時間需加入 GPS、過馬路與上車緩衝
- 推估 ETA 或 backfill ETA 需增加不確定性
- 步行時間與 ETA 的誤差區間重疊時回傳 `tight`
- 不可因車輛暫時從 feed 消失就判斷為已離站
- 不可使用地圖 marker 的動畫推估位置作為搭車判斷依據

建議採區間比較：

- 最壞步行時間仍短於保守 ETA：`likelyCatchable`
- 最快步行時間仍晚於樂觀 ETA：`likelyMiss`
- 兩者區間重疊：`tight`

所有門檻需使用具名常數，並由單元測試固定邊界行為。

## 到站與離站狀態

目前前端已具備：

- `StopInfo.sec`
- `StopInfo.msg`
- `StopInfo.t`
- `StopInfo.buses`
- `StopInfo.etas`
- `BusVehicle.carOnStop`

但目前缺少可靠的 `departed` 狀態，且 realtime payload 中的 `is_arriving` 尚未完整保留到模型。

實作時應：

- 集中處理 `未發車`、`末班駛離`、`今日未營運`、`進站中` 等狀態
- 保留可用的結構化進站欄位
- 只有上游明確離站事件或可靠車輛進度才能顯示「公車已離站」
- 沒有可靠資訊時使用「即時資料不足」，不可自行猜測

## UI 整合

### 路線詳情

檔案：`lib/screens/route_detail_screen.dart`

在目前最近站牌的站名下方顯示完整判斷：

- `預估來得及，步行約 4 分鐘`
- `時間接近，建議加快腳步`
- `可能來不及，建議搭下一班`
- `公車進站中`
- `即時資料不足，暫時無法判斷`

只讓小型 recommendation widget 每秒更新，不可讓整個站牌列表每秒重建。

### 附近站牌

檔案：`lib/screens/nearby_screen.dart`

- 將畫面上可見的候選站牌合併為一次 matrix request
- 每條路線顯示精簡結果
- 定位、Google Routes 或 ETA 不可用時維持原本列表

### 首頁推薦

檔案：`lib/screens/home_screen.dart`

- 智慧推薦使用已解析的最近或常用站牌
- 附近 fallback 使用既有搜尋結果的站牌
- 同一批推薦只送一次 matrix request
- 首頁不得為此功能主動要求定位權限
- 沒有既有定位權限或位置時隱藏判斷文字

## 資料更新策略

- ETA 沿用既有路線更新週期
- 步行時間與 ETA 分開更新
- 定位移動未達門檻時重用步行路線
- App 進入背景或畫面被覆蓋時停止新增請求
- 返回前景時先檢查位置與快取是否仍有效
- 使用 request generation 避免舊結果覆蓋新位置

## 隱私與合規

- 使用 POST 傳送座標，避免座標出現在 URL
- YaBus API 不持久化精確位置
- 不在一般 request log 中記錄 request body
- 確認 Google Routes attribution 與資料保存條款
- 更新隱私說明：定位座標會經 YaBus API 傳送至 Google，以計算步行路線

## 測試計畫

### API Server

- Google 正常回應
- 部分 matrix element 失敗
- `ROUTE_NOT_FOUND`
- Google timeout 或非 2xx
- API Key 缺失
- 經緯度驗證
- 目的地數量限制
- rate limit
- response field mapping

### 純 Dart evaluator

- 明顯來得及
- 明顯來不及
- 誤差區間重疊
- 公車進站中
- 未發車與停止營運
- 定位過舊
- GPS accuracy 過差
- ETA 過舊
- ETA 缺失
- synthetic/backfill ETA
- 所有邊界值

### Flutter Widget

- 路線詳情只在最近站牌顯示
- 使用者移動後切換目標站牌
- ETA 更新後切換判斷結果
- 附近頁批次顯示結果
- 首頁智慧推薦與 nearby fallback 顯示結果
- 步行 API 失敗時 graceful fallback
- 背景與前景切換不套用過期結果

## 建議實作順序

1. 在 `busapiserver` 建立 Google Routes client、API 契約與測試。
2. 在前端建立 walking route model、service、批次查詢與快取。
3. 建立純 Dart catchability evaluator 與完整單元測試。
4. 先整合路線詳情最近站牌。
5. 整合附近站牌。
6. 整合首頁智慧推薦與附近 fallback。
7. 補上 arrival/departure 結構化狀態。
8. 完成隱私文件、Google attribution、配額與費用告警。
9. 執行前後端完整測試與真機定位驗證。

## 上線前置條件

- Google Cloud 已啟用 Routes API
- Google Cloud 已啟用計費
- 後端已設定限制型 `GOOGLE_ROUTES_API_KEY`
- 已設定每日 quota 與 billing alert
- API Server 新端點已部署
- 隱私說明已更新
- Android、iOS、Web 與桌面 fallback 行為已驗證
