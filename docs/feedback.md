# 意見回饋補充資訊

登入後仍只需填寫標題與內容。展開「更多資訊（選填）」可提供回饋類型、相關路線／站牌及聯絡方式，後兩項各最多 200 字。未填的選填欄位不會送出。

「附上 App 與顯示資訊」每次進入頁面預設關閉。開啟後會預覽將附上的 App 版本、建置編號、程式版本、平台、語言、畫面尺寸、文字縮放與顯示主題。送出時只有開啟此選項才會加入 `diagnostics`；取消後不附上。收合選填區塊保留已填內容和開關選擇，送出失敗也保留內容供重試。

API 為 `POST /api/v1/feedback`，新增欄位是 `category`、`route_context`、`contact`、`diagnostics`。回饋類型使用 `bug`、`data`、`feature`、`other`。既有的驗證身分與 User-Agent 請求標頭維持原行為。

需要搭配 `busapiserver` 的 API、資料庫升級與管理後台更新；先部署後端再發布 App。後端啟動時自動補上選填欄位，舊版 App 與舊回饋資料繼續相容；舊後端不接受新欄位。

驗證：

```sh
flutter test test/feedback_service_test.dart test/feedback_screen_test.dart
```

後端專案內執行：

```sh
python -m unittest test_feedback_api test_rate_limit
```
