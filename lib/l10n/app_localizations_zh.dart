// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'YetAnotherBusApp';

  @override
  String get settingsTitle => '設定';

  @override
  String get appearanceSectionTitle => '外觀';

  @override
  String get languageLabel => '語言';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get interfaceScaleLabel => '介面縮放';

  @override
  String get interfaceScaleDescription => '調整文字與介面元素的大小。';

  @override
  String interfaceScaleValue(int percent) {
    return '$percent%';
  }

  @override
  String get themeModeLabel => '主題模式';

  @override
  String get themeModeSystem => '跟隨系統';

  @override
  String get themeModeLight => '淺色';

  @override
  String get themeModeDark => '深色';

  @override
  String get compactModeTitle => '精簡模式';

  @override
  String get compactModeDescription => '首頁與部分卡片減少說明文字顯示；桌面首頁固定維持精簡。';

  @override
  String get showWeatherTitle => '顯示天氣';

  @override
  String get showWeatherDescription => '在首頁標題旁顯示目前氣溫，點一下可開啟完整預報。';

  @override
  String get mapProviderLabel => '地圖提供者';

  @override
  String get personalizationTitle => '個人化';

  @override
  String get personalizationDescription => '配色、背景透明度';

  @override
  String get commonCancel => '取消';

  @override
  String get commonDelete => '刪除';

  @override
  String get commonRetry => '重試';

  @override
  String get commonSettings => '設定';

  @override
  String get commonOpenSettings => '開啓設定';

  @override
  String get commonRefresh => '重新整理';

  @override
  String get commonBack => '返回';

  @override
  String get commonDownload => '下載';

  @override
  String get commonDownloading => '下載中...';

  @override
  String get commonDone => '完成';

  @override
  String get commonLater => '稍後再說';

  @override
  String get commonNotNow => '先不要';

  @override
  String get commonUpdate => '更新';

  @override
  String get commonView => '查看';

  @override
  String get commonReload => '重新載入';

  @override
  String get commonClear => '清除';

  @override
  String get commonCenter => '置中';

  @override
  String commonPercentage(int value) {
    return '$value%';
  }

  @override
  String get errorGeneric => '發生錯誤，請稍後再試。';

  @override
  String get errorNetwork => '網路連線異常，請確認網路後再試。';

  @override
  String get errorTimeout => '連線逾時，請稍後再試。';

  @override
  String get errorRateLimited => '請求次數過多，請稍後再試。';

  @override
  String get transitBus => '公車';

  @override
  String get transitMetro => '捷運';

  @override
  String get transitThsr => '高鐵';

  @override
  String get transitTra => '台鐵';

  @override
  String get transitYouBike => 'YouBike';

  @override
  String get transitBusHomePresence => '公車首頁';

  @override
  String get homeSearchTitle => '搜尋路線';

  @override
  String get homeSearchDescription => '輸入公車號碼、路線名稱或客運路線，直接看即時到站資訊。';

  @override
  String get homeFavoritesTitle => '我的最愛';

  @override
  String get homeFavoritesDescription => '整理常用站牌與群組，快速跳回指定站點。';

  @override
  String get homeNearbyTitle => '附近站牌';

  @override
  String get homeNearbyDescription => '依照你目前位置找附近的公車站牌。';

  @override
  String get homeBusMapTitle => '全公車地圖';

  @override
  String get homeBusMapDescription => '看整個縣市的公車現在開到哪，點一輛就能看它的路線與站牌。';

  @override
  String get homeOverviewTitle => '總覽';

  @override
  String homeSelectedRegions(int count) {
    return '已選 $count 個地區';
  }

  @override
  String get homeOpenSettings => '開啓設定';

  @override
  String get databaseDownloadsTitle => '資料庫與下載';

  @override
  String get announcementsTitle => '公告';

  @override
  String get installAppTooltip => '安裝 App';

  @override
  String get installAppTitle => '要安裝成應用程式嗎？';

  @override
  String get installAppDescription => '把 YABus 安裝成應用程式，之後就能像一般應用程式一樣開啓。';

  @override
  String get installAppLimitation => '功能會比原版應用程式少就是了';

  @override
  String get installAppConfirm => '當然好啊 ＼(^o^)／';

  @override
  String get installRequestSent => '已送出安裝要求。';

  @override
  String get installCancelled => '已取消安裝。';

  @override
  String get installUnavailable => '這個裝置目前無法顯示安裝提示。';

  @override
  String get smartRecommendationsTitle => '智慧推薦';

  @override
  String get smartRecommendationsSubtitle => '根據你的使用習慣推薦路線';

  @override
  String get smartRecommendationsDisabled =>
      '這個功能目前已關閉。開啓後，YABus 會學習你在不同時段最常點開的路線，並在首頁直接推薦。';

  @override
  String get smartRecommendationsGoToSettings => '前往設定';

  @override
  String get smartRecommendationsNeedDatabase =>
      '請先下載本地資料庫。下載完成後，這張卡片才會開始學習你的使用習慣並顯示附近站牌到站時間。';

  @override
  String destinationStopId(int stopId) {
    return '目的地站牌 $stopId';
  }

  @override
  String directionValue(String direction) {
    return '方向：$direction';
  }

  @override
  String destinationValue(String destination) {
    return '目的地：$destination';
  }

  @override
  String approximateDistance(String distance) {
    return '距離你約 $distance';
  }

  @override
  String get tryAgainLater => '請稍後重試。';

  @override
  String get nearbyMapTitle => '附近地圖';

  @override
  String get nearbyMapSubtitle => '今天想去哪搭公車？';

  @override
  String get refreshNearbyStops => '重整附近站牌';

  @override
  String get nearbyNoStopsToDisplay => '附近暫時沒有可顯示的站牌。';

  @override
  String get mapNoLocations => '目前沒有可顯示的站點位置。';

  @override
  String get locationServicesDisabled => '定位服務尚未開啓。';

  @override
  String get locationPermissionDenied => '沒有取得定位權限。';

  @override
  String get searchTitle => '搜尋路線或站牌';

  @override
  String get searchHint => '搜尋公車路線或站牌名稱';

  @override
  String get searchClearTooltip => '清除搜尋';

  @override
  String get searchShowKeypadTooltip => '開啓快捷鍵盤';

  @override
  String get searchErrorTitle => '搜尋撞到貓貓了';

  @override
  String get searchResolvingTitle => '貓貓正在翻站牌';

  @override
  String get searchResolvingMessage => '正在搜尋附近可搭的站牌...';

  @override
  String get searchEmptyTitle => '沒有找到這台貓公車';

  @override
  String get searchEmptyMessage => '試試看少打一點，或換成站牌名稱搜尋。';

  @override
  String get searchEmptyNeedsDatabase => '部分站牌搜尋需要本機資料庫，先更新資料庫後再試一次。';

  @override
  String get searchHistoryEmpty => '還沒有搜尋紀錄。';

  @override
  String get searchRecentTitle => '最近搜尋';

  @override
  String searchNearestStop(String stopName, String distance) {
    return '離你最近：$stopName ($distance)';
  }

  @override
  String get searchKeypadTitle => '路線字首與號碼';

  @override
  String get searchKeypadCollapseTooltip => '收合快捷鍵盤';

  @override
  String get searchKeypadTextTooltip => '切換文字鍵盤';

  @override
  String get searchKeypadBackspaceTooltip => '退格';

  @override
  String get searchKeypadOther => '其他';

  @override
  String get nearbyTitle => '附近站牌';

  @override
  String get nearbyLocationSettings => '定位設定';

  @override
  String get nearbyPermissionSettings => '權限設定';

  @override
  String get nearbyEmpty => '附近沒有找到站牌。';

  @override
  String get favoritesTitle => '我的最愛';

  @override
  String get favoritesUpdating => '正在更新';

  @override
  String get favoritesRealtimeUpdateFailed => '即時資訊更新失敗';

  @override
  String get favoritesNoRealtime => '目前沒有可用的即時資訊';

  @override
  String get favoritesPartialUpdateFailed => '部分即時資訊更新失敗';

  @override
  String get favoritesLoadFailed => '載入失敗';

  @override
  String get favoritesUpdateFailedKeepingData => '更新失敗，保留上一筆資料';

  @override
  String favoriteRemoved(String item, String group) {
    return '已從 $group 移除 $item';
  }

  @override
  String get favoriteTypeRoute => '路線';

  @override
  String get favoriteTypeStation => '整站';

  @override
  String get favoriteTypeBoarding => '站牌';

  @override
  String get favoriteGroupKindMixed => '綜合';

  @override
  String get favoriteNoUpcomingArrivals => '目前沒有即將抵達班次';

  @override
  String favoriteStationSide(String side) {
    return '$side 側';
  }

  @override
  String routeIdFallback(int routeId) {
    return '路線 $routeId';
  }

  @override
  String stopIdFallback(int stopId) {
    return '站牌 $stopId';
  }

  @override
  String get favoriteFetchingRealtime => '正在取得即時資訊';

  @override
  String get favoriteNoSelectableStops => '這條路線目前沒有可選的站牌。';

  @override
  String stopSequence(int number) {
    return '第 $number 站';
  }

  @override
  String favoriteDestinationSet(String stopName) {
    return '已將目的地設為 $stopName';
  }

  @override
  String get favoriteDestinationCleared => '已清除這個最愛的目的地設定';

  @override
  String get favoritesFinishSorting => '完成排序';

  @override
  String get favoritesAdjustSorting => '調整排序';

  @override
  String get favoritesManageGroupsTooltip => '管理最愛群組';

  @override
  String favoritesUpdateCountdown(int seconds) {
    return '$seconds 秒後更新';
  }

  @override
  String get favoritesErrorTitle => '最愛清單卡住了';

  @override
  String get favoritesTryAgain => '再試一次';

  @override
  String get favoritesGroupEmpty => '這個群組目前沒有收藏。';

  @override
  String routeKeyFallback(int routeKey) {
    return 'routeKey $routeKey';
  }

  @override
  String get favoriteDestinationSettings => '目的地設定';

  @override
  String get favoriteSetDestination => '設定目的地';

  @override
  String get favoriteClearDestination => '清除目的地';

  @override
  String get favoritesEmptyMessage => '還沒有任何已收藏的站牌 :(';

  @override
  String get favoritesEmptyTitle => '貓貓還沒有固定站牌';

  @override
  String get favoriteGroupsTitle => '最愛群組';

  @override
  String get favoriteGroupAddTitle => '新增群組';

  @override
  String get favoriteGroupNameLabel => '群組名稱';

  @override
  String get favoriteGroupNameHint => '例如：回家';

  @override
  String get favoriteGroupCategoryLabel => '收藏類別';

  @override
  String get favoriteGroupAddAction => '新增';

  @override
  String get favoriteGroupDuplicate => '已有相同名稱的收藏群組。';

  @override
  String get favoriteGroupsEmpty => '還沒有群組。';

  @override
  String get favoriteGroupDeleteTitle => '刪除群組';

  @override
  String favoriteGroupDeletePrompt(String group) {
    return '確定要刪除「$group」嗎？';
  }

  @override
  String favoriteGroupSummary(String kind, int count) {
    return '$kind · $count 個收藏';
  }

  @override
  String get accountTitle => '帳戶';

  @override
  String get accountSignedOut => '尚未登入。';

  @override
  String accountSignedInAs(String name) {
    return '已登入為 $name';
  }

  @override
  String wearConnectedWatch(String names) {
    return '已連接的手錶：$names';
  }

  @override
  String wearConnectedWatches(String names, int count) {
    return '已連接的手錶：$names 等 $count 台';
  }

  @override
  String get wearSyncTitle => '啓用 Wear OS 同步';

  @override
  String get wearSyncDescription => '將最愛站牌同步到手錶';

  @override
  String get wearNoFavorites => '尚無最愛站牌。請先新增最愛，再進行同步。';

  @override
  String get wearSyncCategory => '同步分類';

  @override
  String get wearAllCategories => '所有分類';

  @override
  String databaseCurrentRegion(String region) {
    return '目前地區：$region';
  }

  @override
  String databaseStartupUpdate(String mode) {
    return '啓動更新：$mode';
  }

  @override
  String databasePendingRegions(int count) {
    return '目前有 $count 個地區可更新';
  }

  @override
  String get databaseOpenPage => '開啓資料庫頁面';

  @override
  String get usageAndUpdatesTitle => '使用與更新';

  @override
  String get alwaysShowSecondsTitle => '強制顯示秒數';

  @override
  String get alwaysShowSecondsDescription => '這個通常不太準';

  @override
  String get hapticFeedbackTitle => '震動回饋';

  @override
  String get hapticFeedbackDescription => '點選及操作時提供觸覺回饋';

  @override
  String get showAdsTitle => '顯示廣告';

  @override
  String get adsLockedMessage => ' 再玩啊哈哈';

  @override
  String get adsEnabledDescription => '把開發者的飯碗搶走。';

  @override
  String get adsPleaOne => '我求你了';

  @override
  String get adsPleaTwo => '我跪著有用嗎';

  @override
  String get adsPleaThree => '你不能這樣對我';

  @override
  String get adsPleaFour => 'QAQ';

  @override
  String get adsDisableTitle => '你確定嗎';

  @override
  String get adsDisableDescription => '我沒有摳摳 :(';

  @override
  String get adsKeepEnabled => '算了不關';

  @override
  String get adsDisableConfirm => '確定關閉';

  @override
  String get smartRecommendationsDescription => '依照你常開啓的時段與路線，在首頁顯示推薦。';

  @override
  String get autoFavoriteTitle => '自動加入常用最愛';

  @override
  String get autoFavoriteDescription => '同一站牌短期內搭乘多次後，自動加入「常用」最愛群組。';

  @override
  String get smartNotificationTitle => '智慧推薦通知';

  @override
  String get smartNotificationDescription => '在常用時段背景提醒你可能想看的路線。';

  @override
  String get smartNotificationPermissionRequired => '需要通知權限才能啓用智慧推薦通知。';

  @override
  String get keepScreenAwakeTitle => '進入公車頁保持亮屏';

  @override
  String get keepScreenAwakeDescription => '在路線詳細頁面維持螢幕常亮。';

  @override
  String get backgroundTripTitle => '背景乘車提醒';

  @override
  String get backgroundTripDescription => '需要通知與定位權限，才能在背景持續提醒搭車狀態。';

  @override
  String get backgroundTripIosDescription => '需要通知與背景定位權限，才能在背景持續提醒搭車狀態。';

  @override
  String get favoriteWidgetRefreshLabel => '最愛小工具背景更新';

  @override
  String get favoriteWidgetRefreshHelper => 'Android 小工具最低更新間隔為 15 分鐘。';

  @override
  String minutesValue(int minutes) {
    return '$minutes 分鐘';
  }

  @override
  String normalUpdateInterval(int seconds) {
    return '一般更新間隔：$seconds 秒';
  }

  @override
  String retryInterval(int seconds) {
    return '錯誤後重試間隔：$seconds 秒';
  }

  @override
  String secondsValue(int seconds) {
    return '$seconds 秒';
  }

  @override
  String get appUpdatesTitle => 'App 更新';

  @override
  String get updateChannelLabel => '更新通道';

  @override
  String get updateCheckOnLaunchLabel => '啓動時檢查';

  @override
  String get updateChannelDeveloper => '開發版';

  @override
  String get updateChannelNightly => 'Nightly';

  @override
  String get updateChannelRelease => 'Release';

  @override
  String get updateChannelDeveloperDescription => '不檢查 app 更新';

  @override
  String get updateChannelNightlyDescription => '比對最新成功建置的 commit';

  @override
  String get updateChannelReleaseDescription => '比對 GitHub 最新發行版';

  @override
  String get updateCheckOff => '關閉';

  @override
  String get updateCheckNotify => '通知';

  @override
  String get updateCheckPopup => '跳窗';

  @override
  String get updateCheckOffDescription => '只在手動檢查時顯示';

  @override
  String get updateCheckNotifyDescription => '啓動後用通知提示';

  @override
  String get updateCheckPopupDescription => '啓動後直接跳出更新視窗';

  @override
  String get appUpdateChecking => '檢查中…';

  @override
  String get appUpdateCheckNow => '立即檢查 App 更新';

  @override
  String appUpdateRecentResult(String result) {
    return '最近結果：$result';
  }

  @override
  String appUpdateAvailableResult(String version) {
    return '有新版本可用：$version';
  }

  @override
  String get appUpdateUpToDateResult => '目前已是最新版本。';

  @override
  String get appUpdateUnavailableResult => '目前無法取得更新資訊。';

  @override
  String get appUpdateNightlyDialogTitle => 'Nightly 更新';

  @override
  String appUpdateReleaseDialogTitle(String version) {
    return 'Release 更新：$version';
  }

  @override
  String appUpdateNightlySummary(String commit) {
    return 'Nightly 建置 $commit 已可下載。';
  }

  @override
  String appUpdateCurrentVersion(String version) {
    return '目前版本：$version';
  }

  @override
  String appUpdateLatestVersion(String version) {
    return '最新版本：$version';
  }

  @override
  String appUpdateFullChangesMarkdown(String range, String url) {
    return '完整變更：[$range]($url)';
  }

  @override
  String appUpdateCommitMarkdown(String commit, String url) {
    return 'Commit：[`$commit`]($url)';
  }

  @override
  String get appUpdateContentsTitle => '更新內容';

  @override
  String get appUpdateDownloadLink => '下載連結';

  @override
  String get appUpdateCopyDownloadLink => '複製下載連結';

  @override
  String get appUpdateDownloadLinkCopied => '下載連結已複製到剪貼簿。';

  @override
  String get appUpdateDownloadAndInstall => '下載並安裝';

  @override
  String get appUpdatePreparing => '準備更新…';

  @override
  String get appUpdateDownloading => '下載更新中…';

  @override
  String get appUpdatePreparingInstaller => '整理安裝檔中…';

  @override
  String get appUpdateLaunchingInstaller => '啓動安裝程式…';

  @override
  String get appUpdatePreparingDesktopInstaller => '準備關閉 App 並啓動安裝程式…';

  @override
  String get appUpdateInstallUnsupported => '這個平台不支援 app 內安裝更新。';

  @override
  String get appUpdateInstallPermissionRequired =>
      '請先允許這個 app 安裝未知應用程式，再重新點一次更新。';

  @override
  String get appUpdateInstallerLaunched => '安裝程式已啓動。';

  @override
  String get appUpdateDesktopInstallerScheduled => '即將關閉 App 並啓動安裝程式。';

  @override
  String appUpdateInstallFailed(String error) {
    return '下載或安裝更新失敗：$error';
  }

  @override
  String get historyPrivacyTitle => '紀錄與隱私';

  @override
  String searchHistoryLimit(int count) {
    return '搜尋紀錄上限：$count 筆';
  }

  @override
  String itemsValue(int count) {
    return '$count 筆';
  }

  @override
  String smartRoutesCount(int count) {
    return '智慧推薦路線：$count 條';
  }

  @override
  String routeSelectionsCount(int count) {
    return '路線選擇紀錄：$count 次';
  }

  @override
  String get clearSearchHistory => '清除搜尋紀錄';

  @override
  String get clearSmartHistory => '清除智慧推薦紀錄';

  @override
  String get clearRouteSelectionHistory => '清除路線選擇紀錄';

  @override
  String get termsOfService => '服務條款';

  @override
  String get privacyPolicy => '隱私權政策';

  @override
  String get onboardingSettingsTitle => '開始流程';

  @override
  String get restartOnboarding => '重新執行開始流程';

  @override
  String get aboutTitle => '關於';

  @override
  String get contributorsTitle => '貢獻者';

  @override
  String get communityTitle => '加入角蛙社群';

  @override
  String get communityDescription => '我的 Discord 伺服器 uwu';

  @override
  String get feedbackTitle => '意見回饋';

  @override
  String get feedbackDescription => '回報問題、提出功能需求或任何想說的話';

  @override
  String get discordOpenFailed => '無法開啓 Discord 社群連結。';

  @override
  String get instagramOpenFailed => '無法開啓 Instagram 頁面。';

  @override
  String githubOpenFailed(String name) {
    return '無法開啓 $name 的 GitHub 頁面。';
  }

  @override
  String get databaseAutoUpdateOff => '不檢查';

  @override
  String get databaseAutoUpdatePopup => '檢查更新並彈窗';

  @override
  String get databaseAutoUpdateNotify => '檢查更新並提示';

  @override
  String get databaseAutoUpdateAlways => '總是自動更新';

  @override
  String get databaseAutoUpdateWifi => '僅 Wi-Fi 自動更新';

  @override
  String get databaseAutoUpdateCellular => '僅行動數據自動更新';

  @override
  String get onboardingLocationServiceDisabled => '定位服務尚未開啓。你仍可手動選擇資料庫。';

  @override
  String get onboardingLocationPermissionDenied => '沒有取得定位權限。請改為手動選擇資料庫。';

  @override
  String get onboardingLocationUnavailable => '定位權限已授權，但暫時無法取得位置。請改為手動選擇資料庫。';

  @override
  String onboardingProviderSelected(String provider) {
    return '已自動選擇最近的資料庫：$provider。';
  }

  @override
  String onboardingLocationFailed(String error) {
    return '定位設定失敗（$error）。請改為手動選擇資料庫。';
  }

  @override
  String get onboardingWelcome => '歡迎來到 YABus';

  @override
  String get onboardingSearchDescription => '輸入公車名稱或號碼，直接打開即時站牌頁。';

  @override
  String get onboardingFavoritesTitle => '收藏站牌';

  @override
  String get onboardingFavoritesDescription => '把常搭的站牌分群保存，下次一鍵回來。';

  @override
  String get onboardingNearbyDescription => '配合定位權限快速找周邊站點。';

  @override
  String get onboardingLegalPrefix => '繼續即代表您同意我們的';

  @override
  String get onboardingLegalAnd => '及';

  @override
  String get onboardingLegalSuffix => '。';

  @override
  String get onboardingStart => '開始設定';

  @override
  String get onboardingLocationTitle => '定位權限';

  @override
  String get onboardingLocationDescription => '我們需要定位權限來取得最近的站牌資訊。';

  @override
  String get onboardingLocationConsent => '允許即代表你同意將定位資訊提供給程式進行處理。（用於取得最近站牌）';

  @override
  String get onboardingLocationServerUse => '僅在無資料庫可用時才會將位置提供給伺服器。';

  @override
  String get onboardingProcessing => '處理中...';

  @override
  String get onboardingAllowContinue => '授權並繼續';

  @override
  String get onboardingChooseManually => '手動選擇資料庫';

  @override
  String get onboardingDownloadTitle => '下載資料庫';

  @override
  String get onboardingDownloadDescription => '可複選要在這台裝置使用的縣市資料庫。';

  @override
  String get onboardingRegionList => '縣市清單';

  @override
  String onboardingNearestSuggestion(String provider) {
    return '最近建議：$provider';
  }

  @override
  String onboardingDefaultSource(String provider) {
    return '預設資料來源：$provider';
  }

  @override
  String onboardingSelectedDatabases(String providers) {
    return '已選資料庫：$providers';
  }

  @override
  String onboardingDatabaseProgress(int downloaded, int total) {
    return '已下載 $downloaded / $total 份資料庫';
  }

  @override
  String onboardingDownloadFailed(String error) {
    return '下載失敗：$error';
  }

  @override
  String shellWebUpdateAvailable(String version, String buildNumber) {
    return '有新版本可用（$version+$buildNumber）';
  }

  @override
  String get shellEnableSyncTitle => '啓用雲端同步？';

  @override
  String get shellEnableSyncDescription =>
      '登入後可以自動同步最愛站牌與偏好設定。之後進入 app 時會自動更新，資料變更後也會稍後自動同步。';

  @override
  String get shellEnableSyncAction => '開啓同步';

  @override
  String get shellSyncEnabled => '已開啓雲端同步。';

  @override
  String get shellSyncSkipped => '已略過自動同步，你之後仍可手動同步。';

  @override
  String shellSyncPreferenceFailed(String error) {
    return '設定同步偏好失敗：$error';
  }

  @override
  String get shellSignInSucceeded => '登入成功。';

  @override
  String shellSignInFailed(String error) {
    return '登入失敗：$error';
  }

  @override
  String shellAccountLinked(String provider) {
    return '已連結 $provider 帳號。';
  }

  @override
  String shellAccountAlreadyLinked(String provider) {
    return '$provider 已在此帳號上。';
  }

  @override
  String shellLinkFailed(String error) {
    return '連結失敗：$error';
  }

  @override
  String get shellMergeAccountsTitle => '合併帳號？';

  @override
  String shellMergeAccountsDescription(String provider) {
    return '「$provider」已經屬於另一個帳號。合併後下列身分與資料會移入目前帳號，來源帳號將被刪除：';
  }

  @override
  String shellActiveDevices(int count) {
    return '來源帳號目前有 $count 台啓用中的裝置。';
  }

  @override
  String get shellMergeAccountsAction => '合併帳號';

  @override
  String shellAccountsMerged(String provider) {
    return '帳號已合併，$provider 已連結到目前帳號。';
  }

  @override
  String shellMergeFailed(String error) {
    return '合併失敗：$error';
  }

  @override
  String get shellDatabaseUpdating => '正在更新資料庫...';

  @override
  String shellDatabaseUpdated(String providers) {
    return '資料庫已更新：$providers';
  }

  @override
  String shellDatabaseAutoUpdateFailed(String error) {
    return '自動更新資料庫失敗：$error';
  }

  @override
  String get shellDatabaseUpdateComplete => '資料庫更新完成。';

  @override
  String shellDatabaseUpdateFailed(String error) {
    return '資料庫更新失敗：$error';
  }

  @override
  String shellDatabaseUpdatesAvailable(String providers) {
    return '資料庫有新版本：$providers';
  }

  @override
  String shellDatabaseCheckFailed(String error) {
    return '檢查資料庫更新失敗：$error';
  }

  @override
  String get shellDatabaseUpdateDeferred => '資料庫更新已延後。';

  @override
  String get etaLoading => '載入中';

  @override
  String get etaArriving => '進站中';

  @override
  String etaSeconds(int seconds) {
    return '$seconds秒';
  }

  @override
  String etaMinutes(int minutes) {
    return '$minutes分';
  }

  @override
  String etaMinutesSeconds(int minutes, int seconds) {
    return '$minutes分\n$seconds秒';
  }

  @override
  String get autoFavoriteFallback => '這個站牌';

  @override
  String autoFavoriteAdded(String label) {
    return '常搭這班車？已自動把「$label」加入常用最愛。';
  }

  @override
  String get commonClose => '關閉';

  @override
  String get commonOkay => '好的';

  @override
  String get commonEnable => '啓用';

  @override
  String get commonUndo => '復原';

  @override
  String get commonAll => '全部';

  @override
  String get commonAddToHomeScreen => '新增到主畫面';

  @override
  String get commonChooseStop => '選擇站牌';

  @override
  String get commonAcknowledge => '知道了';

  @override
  String get directionOutbound => '去程';

  @override
  String get directionInbound => '返程';

  @override
  String directionNumber(int direction) {
    return '方向 $direction';
  }

  @override
  String directionTo(String destination) {
    return '往 $destination';
  }

  @override
  String relativeSecondsAgo(int count) {
    return '$count 秒前';
  }

  @override
  String relativeMinutesAgo(int count) {
    return '$count 分鐘前';
  }

  @override
  String relativeHoursAgo(int count) {
    return '$count 小時前';
  }

  @override
  String relativeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String distanceMetersValue(int meters) {
    return '$meters 公尺';
  }

  @override
  String distanceKilometersValue(String kilometers) {
    return '$kilometers 公里';
  }

  @override
  String speedKilometersPerHour(int speed) {
    return '$speed 公里/小時';
  }

  @override
  String get busStatusNormal => '正常';

  @override
  String get busStatusAccident => '車禍';

  @override
  String get busStatusBreakdown => '故障';

  @override
  String get busStatusTraffic => '塞車';

  @override
  String get busStatusEmergency => '緊急求援';

  @override
  String get busStatusRefueling => '加油';

  @override
  String get busStatusUnclear => '不明';

  @override
  String get busStatusDirectionUnclear => '去回不明';

  @override
  String get busStatusOffRoute => '偏移路線';

  @override
  String get busStatusNotInService => '非營運狀態';

  @override
  String get busStatusFull => '客滿';

  @override
  String get busStatusChartered => '包車出租';

  @override
  String get busStatusUnknown => '未知';

  @override
  String busStatusUnknownCode(int code) {
    return '未知（$code）';
  }

  @override
  String get stationFallbackTitle => '整站';

  @override
  String get stationShortcutRequested => '已送出整站捷徑要求。';

  @override
  String get shortcutUnsupported => '這台裝置不支援主畫面捷徑。';

  @override
  String get stationNotFound => '找不到這一站的整站資料。';

  @override
  String get stationPinTooltip => '將整站新增到主畫面';

  @override
  String get stationNoSides => '這一站目前沒有可顯示的站牌。';

  @override
  String stationSideLabel(String side) {
    return '站牌 $side';
  }

  @override
  String stationSideDirection(String side, String direction) {
    return '$side · $direction';
  }

  @override
  String stationSideNoRoutes(String side) {
    return '站牌 $side 目前沒有經過路線。';
  }

  @override
  String busMapTitle(String region) {
    return '全公車地圖 · $region';
  }

  @override
  String busMapRouteDataLoadFailed(String error) {
    return '無法載入路線資料：$error';
  }

  @override
  String get busMapRouteDetailUnavailable => '這條路線目前沒有可查詢的詳細資料。';

  @override
  String busMapSwitchedRegion(String region) {
    return '已切換至$region';
  }

  @override
  String get busMapCloseFilter => '關閉篩選';

  @override
  String get busMapFilterRoutes => '篩選路線';

  @override
  String get busMapFavoritesOnly => '只看最愛路線';

  @override
  String get busMapLocate => '定位';

  @override
  String get busMapSwitchRegion => '切換縣市';

  @override
  String get busMapFilterHint => '篩選路線名稱或車牌';

  @override
  String get busMapNoData => '目前沒有公車資料';

  @override
  String get busMapLoadingPositions => '正在載入公車位置…';

  @override
  String busMapBusCount(int count) {
    return '$count 輛公車';
  }

  @override
  String busMapBusCountUpdated(int count, String updated) {
    return '$count 輛公車 · $updated';
  }

  @override
  String get busMapZoomForBuses => '放大或點圓圈看個別公車';

  @override
  String busMapShownCount(int shown, int total) {
    return '顯示 $shown／$total 輛，放大看更多';
  }

  @override
  String get busMapNoFavoriteRoutes => '最愛中沒有此縣市的路線';

  @override
  String get busMapNoMatches => '找不到符合的公車';

  @override
  String get busMapDataStale => '資料可能不是最新';

  @override
  String get busMapDataIncomplete => '資料可能不完整';

  @override
  String get busMapUnsupportedTitle => '此縣市暫不支援全公車地圖';

  @override
  String get busMapUnsupportedMessage => '可以從右上角切換其他縣市。';

  @override
  String get busMapRouteStops => '沿途站牌';

  @override
  String get busMapSelectionHint => '點一輛公車就能看到它的路線、方向與沿途站牌。';

  @override
  String busMapClusterCount(int count) {
    return '$count 輛公車';
  }

  @override
  String busMapClusterSemantics(int count) {
    return '此處有 $count 輛公車，點一下放大';
  }

  @override
  String get busMapYourLocation => '你的位置';

  @override
  String get busMapClearSelection => '取消選取';

  @override
  String busMapSameRouteRunning(int count) {
    return '同路線 $count 輛行駛中';
  }

  @override
  String busMapBareRouteCode(String code) {
    return '這輛車的路線代碼是 $code，尚無路線名稱。';
  }

  @override
  String busMapAmbiguousFamily(String family) {
    return '這輛車屬於「$family」路線群，無法判定是哪個區間班次。';
  }

  @override
  String get busMapRouteDetails => '路線詳情';

  @override
  String get busMapShowWholeRoute => '顯示整條路線';

  @override
  String get routeMapRefreshing => '更新中';

  @override
  String routeMapRefreshCountdown(int seconds) {
    return '$seconds 秒後更新';
  }

  @override
  String get routeMapTitle => '公車地圖';

  @override
  String get routeMapToggleBuses => '公車';

  @override
  String get routeMapToggleStops => '站牌';

  @override
  String get routeMapRecenter => '回到你的位置';

  @override
  String get routeMapNoData => '目前沒有可顯示的路線地圖資料';

  @override
  String get routeMapSpeed => '速度';

  @override
  String get routeMapBearing => '方位';

  @override
  String get routeMapUpdated => '更新';

  @override
  String get routeMapPosition => '位置';

  @override
  String get routeMapStopSequence => '站序';

  @override
  String get routeMapArrival => '到站';

  @override
  String get routeMapAngle => '角度';

  @override
  String get routeMapStatus => '狀態';

  @override
  String get routeMapOnRoute => '沿路線';

  @override
  String get routeMapSnappedToRoute => '貼線';

  @override
  String routeMapOffRoute(int meters) {
    return '離線路 ${meters}m';
  }

  @override
  String routeMapOffLine(int meters) {
    return '離線 ${meters}m';
  }

  @override
  String get transferMissingCoordinates => '這個站牌沒有座標資料，無法尋找附近轉乘。';

  @override
  String get transferEmpty => '這個站牌附近暫時沒有可顯示的轉乘方式。';

  @override
  String get transferTitle => '附近轉乘';

  @override
  String transferWalkingRanges(String stopName) {
    return '$stopName\n步行 250 公尺內的公車與 300 公尺內的 YouBike';
  }

  @override
  String transferRouteCount(String distance, int count) {
    return '$distance・$count 條路線';
  }

  @override
  String transferBikeAvailability(int rent, int returns) {
    return '可借 $rent・可還 $returns';
  }

  @override
  String transferBikeAvailabilityDistance(
    String distance,
    int rent,
    int returns,
  ) {
    return '$distance・可借 $rent・可還 $returns';
  }

  @override
  String get routeDetailTitle => '公車資訊';

  @override
  String get routeDetailStatusRefreshing => '正在更新';

  @override
  String get routeDetailStatusLoadingRoute => '正在載入路線資料';

  @override
  String get routeDetailStatusLoadingRealtime => '正在載入即時到站資訊';

  @override
  String get routeDetailStatusRealtimeUnavailable => '即時資訊暫時無法取得';

  @override
  String get routeDetailStatusLoadFailed => '讀取失敗';

  @override
  String get routeDetailStatusLoadingFamily => '正在載入同路線班次';

  @override
  String get routeDetailCancelledToday => '今日取消發車資訊';

  @override
  String routeDetailDirectionHeading(String direction) {
    return '$direction：';
  }

  @override
  String get routeDetailOperationsNotice => '營運通知';

  @override
  String get routeDetailViewRoutePresence => '查看路線';

  @override
  String get routeDetailBackgroundPromptTitle => '啓用背景乘車提醒？';

  @override
  String get routeDetailBackgroundPromptMessage =>
      'YABus 可以在你把 app 丟到背景後繼續追蹤這條路線，並在接近目的地下車前提醒你。';

  @override
  String get routeDetailBackgroundNotificationPermission =>
      '背景乘車提醒需要通知權限，否則提醒可能不會跳出。';

  @override
  String get routeDetailOppoPromptTitle => '提示';

  @override
  String get routeDetailOppoPromptMessage =>
      '你的系統可能支援流體雲功能，但你需要在 YABus 的通知設定裡啓用它。';

  @override
  String get routeDetailSamsungPromptTitle => 'Samsung Now Bar 顯示設定';

  @override
  String get routeDetailSamsungPromptMessage =>
      '如果背景乘車資訊沒有出現在 Now Bar，請啓用 Samsung 的即時通知測試選項。';

  @override
  String get routeDetailSamsungDeveloperSteps =>
      '尚未啓用開發人員選項：\n設定 → 關於手機 → 軟體資訊 → 連點「版本號碼」7 次';

  @override
  String get routeDetailSamsungLiveSteps =>
      '接著前往：\n設定 → 開發人員選項 → 捲到最底部 → More settings → Live notifications for all apps';

  @override
  String get routeDetailOpenSettingsFailed => '無法開啓系統設定，請依照提示中的路徑手動前往。';

  @override
  String get routeDetailTripPaused => '已暫時停止背景乘車提醒';

  @override
  String get routeDetailTripResumed => '已恢復背景乘車提醒';

  @override
  String get routeDetailLocationServiceRequired => '要使用背景乘車提醒，請先開啓定位服務。';

  @override
  String get routeDetailLocationPermissionRequired => '要使用背景乘車提醒，必須先允許定位權限。';

  @override
  String get routeDetailNotificationPermissionRequired =>
      '要使用乘車到站提醒，必須先允許通知權限。';

  @override
  String get routeDetailBackgroundLocationFallback =>
      '未啓用「一律允許」定位，背景乘車提醒會改用最後一次定位與公車到站資訊繼續運作。';

  @override
  String get routeDetailBackgroundLocationTitle => '允許背景定位';

  @override
  String get routeDetailBackgroundLocationIos =>
      '要在把 app 丟到背景後持續更新下車提醒和靈動島，iPhone 需要將定位權限設為「永遠」。';

  @override
  String get routeDetailBackgroundLocationAndroid =>
      '要在把 app 丟到背景後繼續提醒，Android 需要將定位權限設為「永遠允許」。';

  @override
  String get routeDetailAlwaysLocationTitle => '要把定位權限改為一律允許嗎？';

  @override
  String get routeDetailAlwaysLocationMessage =>
      'YABus 需要一律允許才可以在背景偵測你是否上車或到站。';

  @override
  String get routeDetailEnableAction => '去開啓';

  @override
  String get routeDetailDestinationPromptTitle => '要設定下車提醒嗎？';

  @override
  String get routeDetailDestinationPromptMessage =>
      '選一個你要下車的站牌，YABus 會在快到站時提醒你。';

  @override
  String get routeDetailSetBoardingStop => '設定上車站';

  @override
  String get routeDetailChangeBoardingStop => '變更上車站';

  @override
  String get routeDetailSetDestinationAlert => '設定下車提醒';

  @override
  String get routeDetailBlockedDestination => '這個站已設為下車站';

  @override
  String get routeDetailBlockedBoarding => '這個站已設為上車站';

  @override
  String get routeDetailSameBoardingDestination => '上車站不能同時設為下車站。';

  @override
  String routeDetailBoardingStopSet(String stopName) {
    return '已將 $stopName 設為上車站。';
  }

  @override
  String routeDetailDestinationSet(String stopName) {
    return '已將 $stopName 設為下車提醒。';
  }

  @override
  String get routeDetailManualBoardingCleared => '已清除手動上車站，之後拿到定位會再自動判斷。';

  @override
  String get routeDetailUsingCurrentLocation => '已改回使用目前位置判斷上車站。';

  @override
  String get routeDetailTripActive => '背景乘車提醒進行中';

  @override
  String get routeDetailBusApproaching => '公車即將進站';

  @override
  String routeDetailBusStopsAway(int count) {
    return '公車還有 $count 站';
  }

  @override
  String routeDetailNearestStopValue(String stopName) {
    return '最近站牌 $stopName';
  }

  @override
  String get routeDetailNotBoarded => '尚未上車';

  @override
  String routeDetailBoardingStopValue(String stopName) {
    return '上車站 $stopName';
  }

  @override
  String routeDetailDestinationValue(String stopName) {
    return '目的地 $stopName';
  }

  @override
  String get routeDetailWaitingForLocation => '等待目前位置';

  @override
  String get routeDetailLocating => '定位中';

  @override
  String get routeDetailWaitingToBoard => '等待上車';

  @override
  String get routeDetailNearestStop => '最近站牌';

  @override
  String get routeDetailDestinationNotSet => '尚未設定下車站';

  @override
  String get routeDetailBoarded => '已上車';

  @override
  String get routeDetailEtaNotDeparted => '未發車';

  @override
  String get routeDetailEtaLastBusPassed => '末班已過';

  @override
  String routeDetailEtaApproxMinutesSeconds(int minutes, int seconds) {
    return '約 $minutes 分 $seconds 秒';
  }

  @override
  String routeDetailEtaApproxMinutes(int minutes) {
    return '約 $minutes 分鐘';
  }

  @override
  String get routeDetailFavoriteStop => '收藏此站牌';

  @override
  String get routeDetailFavoriteStation => '收藏整站';

  @override
  String get routeDetailFavoriteGroupDuplicate => '已有相同名稱的收藏群組。';

  @override
  String routeDetailFavoriteLimit(int count) {
    return '我的最愛已達上限 $count 項，無法再加入';
  }

  @override
  String routeDetailRouteAdded(String group) {
    return '已將路線加入 $group';
  }

  @override
  String get routeDetailStationIdMissing => '這個站牌缺少可解析的識別碼，無法對應到整站。';

  @override
  String get routeDetailStationNotSynced => '伺服器還沒同步這一站的整站資料。';

  @override
  String routeDetailStationAdded(String station, String group) {
    return '已將$station加入 $group';
  }

  @override
  String routeDetailFavoriteAdded(String group) {
    return '已加入 $group';
  }

  @override
  String routeDetailFavoriteAddedWithDestination(
    String group,
    String destination,
  ) {
    return '已加入 $group，目的地：$destination';
  }

  @override
  String get routeDetailFavoriteDestinationTitle => '設定最愛目的地？';

  @override
  String get routeDetailFavoriteDestinationMessage =>
      '下次從最愛或小工具開啓時，會自動幫你套用下車提醒。';

  @override
  String get routeDetailNoSelectableStops => '這個方向目前沒有可選擇的站牌。';

  @override
  String get routeDetailShortcutRequested => '已送出主畫面捷徑要求。';

  @override
  String get routeDetailRouteShortcutRequested => '已送出路線捷徑要求。';

  @override
  String get routeDetailDestinationCleared => '已清除下車提醒。';

  @override
  String get routeDetailGoogleMapsFailed => '無法開啓 Google Maps。';

  @override
  String get routeDetailRealtimeLoading => '讀取即時資料中…';

  @override
  String get routeDetailNoRealtime => '無即時資料';

  @override
  String get routeDetailSelectFavoriteGroup => '選擇最愛群組';

  @override
  String get routeDetailNewGroup => '新增群組';

  @override
  String get routeDetailForumFailed => '無法開啓 TWBusforum。';

  @override
  String get routeDetailBackgroundDrawerTitle => '背景乘車提醒';

  @override
  String get routeDetailBackgroundDrawerMessage => '把背景追蹤與下車提醒控制集中在這裡。';

  @override
  String get routeDetailPauseBackground => '暫時停止背景乘車提醒';

  @override
  String get routeDetailResumeBackground => '恢復背景乘車提醒';

  @override
  String get routeDetailPauseBackgroundMessage => '保留設定，但先停止背景追蹤與提醒。';

  @override
  String get routeDetailResumeBackgroundMessage => '重新開始背景追蹤與提醒。';

  @override
  String routeDetailCurrentStop(String stopName) {
    return '目前站點：$stopName';
  }

  @override
  String get routeDetailBoardingStopHint => '沒定位時也可以手動選一個站牌當上車站。';

  @override
  String get routeDetailDestinationHint => '選擇一個站牌作為下車提醒。';

  @override
  String get routeDetailClearManualBoarding => '清除手動上車站';

  @override
  String get routeDetailReturnToCurrentLocation => '改回目前位置';

  @override
  String get routeDetailClearManualBoardingHint => '先保留背景提醒，之後拿到定位再自動判斷上車站。';

  @override
  String get routeDetailCurrentLocationHint => '重新跟著目前最近的站牌自動判斷上車站。';

  @override
  String get routeDetailClearDestinationAlert => '清除下車提醒';

  @override
  String get routeDetailVehicleBackfill => '回灌補點';

  @override
  String get routeDetailVehicleRealtime => '即時定位';

  @override
  String get routeDetailVehicleSource => '來源';

  @override
  String get routeDetailVehicleEta => '本站 ETA';

  @override
  String get routeDetailVehicleNotes => '備註';

  @override
  String get routeDetailVehicleCondition => '車況';

  @override
  String get routeDetailVehicleFull => '客滿';

  @override
  String get routeDetailVehicleAtStop => '目前在站';

  @override
  String get routeDetailVehicleType => '車型';

  @override
  String get routeDetailVehicleElectric => '電動公車';

  @override
  String get routeDetailVehicleEquipment => '設備';

  @override
  String get routeDetailVehicleAccessible => '低地板 / 無障礙';

  @override
  String get routeDetailViewOnMap => '在地圖中查看';

  @override
  String get routeDetailSearchForum => '搜尋 TWBusforum';

  @override
  String get routeDetailVehicleElectricShort => '電動車';

  @override
  String get routeDetailVehicleAccessibleShort => '無障礙';

  @override
  String get routeDetailVehicleFullShort => '滿載';

  @override
  String get routeDetailDestinationStop => '下車站';

  @override
  String get routeDetailNoDirectionsTitle => '這條路線還沒有方向資料';

  @override
  String get routeDetailNoDirectionsMessage => '貓貓翻不到去程或返程，稍後再試試看。';

  @override
  String get routeDetailNoStopsTitle => '這個方向沒有站牌';

  @override
  String get routeDetailNoStopsMessage => '可能是資料還沒同步完成，等一下再更新。';

  @override
  String get routeDetailNoMapData => '目前沒有可顯示的地圖資料';

  @override
  String get routeDetailRouteNotice => '路線公告';

  @override
  String get routeDetailNoticeUpdate => '目前有營運資訊更新';

  @override
  String get routeDetailCancelledDepartures => '今日取消發車';

  @override
  String routeDetailAdditionalNotices(String message, int count) {
    return '$message（另有 $count 則）';
  }

  @override
  String get routeDetailErrorTitle => '公車資訊被貓貓壓住了';

  @override
  String get routeDetailErrorMessage => '目前無法載入公車資訊，稍後再更新一次。';

  @override
  String get routeDetailHideMap => '隱藏地圖';

  @override
  String get routeDetailShowMap => '顯示地圖';

  @override
  String get routeDetailJumpToNearestStop => '跳到最近站牌';

  @override
  String get routeDetailScheduleTooltip => '同路線時刻表';

  @override
  String get routeInfoActions => '路線動作';

  @override
  String get routeInfoFavoriteRoute => '收藏路線';

  @override
  String routeInfoLoadFailed(String error) {
    return '載入失敗：$error';
  }

  @override
  String get routeInfoOperators => '營運業者';

  @override
  String get routeInfoFamilySchedule => '同路線時刻表';

  @override
  String get routeInfoRelatedRoutes => '相關路線';

  @override
  String get routeInfoShareLink => '分享連結';

  @override
  String get routeInfoLinkCopied => '已複製連結';

  @override
  String routeInfoPhone(String phone) {
    return '電話：$phone';
  }

  @override
  String routeInfoWebsite(String url) {
    return '網站：$url';
  }

  @override
  String get scheduleWeekdayMon => '一';

  @override
  String get scheduleWeekdayTue => '二';

  @override
  String get scheduleWeekdayWed => '三';

  @override
  String get scheduleWeekdayThu => '四';

  @override
  String get scheduleWeekdayFri => '五';

  @override
  String get scheduleWeekdaySat => '六';

  @override
  String get scheduleWeekdaySun => '日';

  @override
  String scheduleDateLabel(int month, int day, String weekday) {
    return '$month/$day（$weekday）';
  }

  @override
  String scheduleHolidayDateLabel(int month, int day, String weekday) {
    return '$month/$day（$weekday・假日）';
  }

  @override
  String get scheduleChooseDate => '選擇日期';

  @override
  String get scheduleNoServiceDay => '這天沒有發車資訊';

  @override
  String get scheduleUnavailable => '目前沒有時刻表資料';

  @override
  String get scheduleNoDepartureTimes => '無發車時間資料';

  @override
  String stopScheduleSubtitle(String routeName) {
    return '$routeName・預計時刻';
  }

  @override
  String get stopScheduleDisclaimer => '依時刻表推算，實際以現場為準';

  @override
  String get stopScheduleNoTimetable => '這條路線沒有時刻表資料';

  @override
  String get stopScheduleNoStopTimes => '這個站點在當天沒有對應的發車時刻';

  @override
  String get stopScheduleFrequency => '行駛班距';

  @override
  String get stopScheduleEstimatedArrival => '預計到站時間';

  @override
  String get stopScheduleIncludesEstimates => '含推算';

  @override
  String get stopScheduleEstimateFootnote => '※ 標示「含推算」的時間由班距與行駛時間推算，僅供參考';

  @override
  String get relatedRoutesLoadFailed => '載入站牌經過路線時發生錯誤';

  @override
  String relatedRoutesEmpty(String stopName) {
    return '找不到「$stopName」的路線';
  }

  @override
  String get relatedRoutesTitle => '站牌經過路線';

  @override
  String get stopActionSetDestination => '設為下車提醒';

  @override
  String get stopActionSchedule => '本站發車/到站時刻';

  @override
  String get stopActionRelatedRoutes => '站牌經過路線';

  @override
  String get stopActionTransfers => '附近轉乘方式';

  @override
  String get stopActionOpenGoogleMaps => '在 Google Maps 開啓';

  @override
  String get linkOpenFailed => '無法開啓連結。';

  @override
  String get announcementsSyncFailed => '公告同步失敗';

  @override
  String get announcementsEmpty => '目前沒有公告。';

  @override
  String get announcementNotFound => '找不到這則公告。';

  @override
  String get announcementResync => '重新同步公告';

  @override
  String get announcementEmbeddedContent => '嵌入內容';

  @override
  String get announcementSound => '提示音';

  @override
  String get announcementReaction => '反應';

  @override
  String get announcementAddReaction => '新增表情符號反應';

  @override
  String get announcementFirstReaction => '成為第一個反應的人';

  @override
  String get announcementReactionUpdateFailed => '無法更新反應，請稍後再試。';

  @override
  String get announcementReactionSignInRequired => '請先登入才能新增反應';

  @override
  String get legalDocumentUpdateFailed => '文件更新失敗';

  @override
  String get legalDocumentReload => '重新載入文件';

  @override
  String get accountSignIn => '登入';

  @override
  String get accountSignInDescription => '登入來備份你的最愛站牌與設定！';

  @override
  String get accountLoginPageOpenFailed => '無法開啓登入頁面。';

  @override
  String accountLoginFailed(String error) {
    return '登入失敗：$error';
  }

  @override
  String get accountLinkPageOpenFailed => '無法開啓連結頁面。';

  @override
  String accountLinkFailed(String error) {
    return '連結失敗：$error';
  }

  @override
  String accountRefreshFailed(String error) {
    return '重新整理帳號失敗：$error';
  }

  @override
  String get accountAutoSyncEnabled => '已開啓自動同步。';

  @override
  String get accountAutoSyncDisabled => '已關閉自動同步。';

  @override
  String accountSyncSettingsFailed(String error) {
    return '更新同步設定失敗：$error';
  }

  @override
  String get accountRouteHistoryPromptTitle => '同步路線紀錄？';

  @override
  String get accountRouteHistoryPromptDescription =>
      '開啓後，最近搜尋的路線與智慧推薦使用紀錄會上傳至你的帳號，讓其他裝置也能使用。這不包含定位資料，且可隨時關閉並移除本裝置上傳的紀錄。';

  @override
  String get accountEnableSync => '開啓同步';

  @override
  String get accountRouteHistoryEnabled => '已開啓路線紀錄同步。';

  @override
  String get accountRouteHistoryDisabled => '已關閉路線紀錄同步。';

  @override
  String accountRouteHistoryUpdateFailed(String error) {
    return '更新路線紀錄同步失敗：$error';
  }

  @override
  String get accountSyncComplete => '同步完成。';

  @override
  String accountSyncFailed(String error) {
    return '同步失敗：$error';
  }

  @override
  String get accountSyncConflictTitle => '同步發生衝突';

  @override
  String accountSyncConflictFallback(String namespace) {
    return '$namespace同步時發生衝突。';
  }

  @override
  String get accountSyncNamespaceFavorites => '最愛站牌與分類';

  @override
  String get accountSyncNamespacePreferences => '偏好設定';

  @override
  String get accountUseCloud => '使用雲端';

  @override
  String get accountTryMerge => '嘗試合併';

  @override
  String get accountOverwriteCloud => '覆蓋雲端';

  @override
  String accountSyncConflictFailed(String error) {
    return '處理同步衝突失敗：$error';
  }

  @override
  String get accountLoggedOut => '已登出。';

  @override
  String get accountLogout => '登出';

  @override
  String get accountSignedIn => '已登入';

  @override
  String get accountDefaultDisplayName => 'Ciallo～(∠・ω< )⌒☆';

  @override
  String get accountContinueDescription => '使用 Discord 或 Google 繼續以建立或連結你的帳戶。';

  @override
  String get accountLoadedFromCurrentToken => '從目前的登入令牌載入';

  @override
  String get accountNoLinkedProviders => '尚未載入任何連結的提供者詳細資訊。';

  @override
  String accountLinkProvider(String provider) {
    return '連結 $provider';
  }

  @override
  String get accountCloudSync => '雲端同步';

  @override
  String get accountEnableCloudSync => '啓用雲端同步';

  @override
  String accountLastSync(String date) {
    return '最後同步時間：$date';
  }

  @override
  String get accountSyncDisabled => '同步已關閉。';

  @override
  String get accountSyncRouteHistory => '同步路線紀錄';

  @override
  String get accountRouteHistoryDeletionPending => '已關閉，正在移除本裝置的雲端路線紀錄。';

  @override
  String get accountRouteHistorySyncDescription => '最近搜尋與智慧推薦使用紀錄會同步；不包含定位資料。';

  @override
  String get accountRouteHistoryWaitingForCloudSync => '已允許同步，開啓雲端同步後才會上傳。';

  @override
  String get accountRouteHistoryOptional => '選擇性功能，預設關閉。';

  @override
  String get accountSyncNow => '立即同步';

  @override
  String accountContinueWithProvider(String provider) {
    return '使用 $provider 繼續';
  }

  @override
  String get accountNeverSynced => '尚未同步';

  @override
  String get feedbackSubmitted => '意見回饋已送出，感謝你幫助我們改進。';

  @override
  String get feedbackSessionExpired => '登入已失效，請重新登入後再送出。';

  @override
  String get feedbackSignInRequired => '請先登入';

  @override
  String get feedbackGoToSignIn => '前往登入';

  @override
  String get feedbackSubjectLabel => '標題';

  @override
  String get feedbackSubjectHint => '例如：收藏站牌同步失敗';

  @override
  String get feedbackSubjectRequired => '請輸入標題';

  @override
  String feedbackSubjectTooLong(int max) {
    return '標題最多 $max 個字';
  }

  @override
  String get feedbackContentLabel => '內容';

  @override
  String get feedbackContentHint => '描述發生了什麼、你原本預期看到什麼，以及重現步驟。';

  @override
  String get feedbackContentRequired => '請輸入內容';

  @override
  String feedbackContentTooLong(int max) {
    return '內文最多 $max 個字';
  }

  @override
  String get feedbackSubmitting => '送出中…';

  @override
  String get feedbackSubmit => '送出回饋';

  @override
  String get feedbackInvalidFormat => '送出資料格式不正確。';

  @override
  String get feedbackSubmitFailed => '意見回饋送出失敗，請稍後再試。';

  @override
  String get databaseUpToDate => '目前資料庫已是最新版本。';

  @override
  String databaseUpdateAvailable(String provider, int version) {
    return '$provider 有新版本 $version';
  }

  @override
  String databaseCheckFailed(String error) {
    return '檢查資料庫更新失敗：$error';
  }

  @override
  String get databaseNoUpdatesAvailable => '目前沒有可更新的資料庫。';

  @override
  String databaseDownloadFailed(String error) {
    return '下載資料庫失敗：$error';
  }

  @override
  String get databaseStartupUpdateTitle => '啓動時更新';

  @override
  String get databaseAutoUpdateModeLabel => '自動更新模式';

  @override
  String get databaseAutoUpdateOffDescription => '啓動時不主動檢查資料庫更新。';

  @override
  String get databaseAutoUpdatePopupDescription => '啓動時檢查更新，若有新版本就彈出提示。';

  @override
  String get databaseAutoUpdateNotifyDescription => '啓動時檢查更新，若有新版本就顯示提示。';

  @override
  String get databaseAutoUpdateAlwaysDescription => '啓動時有新版本就直接下載並更新。';

  @override
  String get databaseAutoUpdateWifiDescription => '僅在 Wi-Fi 連線時自動更新，其他網路只保留提示。';

  @override
  String get databaseAutoUpdateCellularDescription =>
      '僅在行動數據連線時自動更新，其他網路只保留提示。';

  @override
  String databaseRegionVersion(String provider, int version) {
    return '$provider v$version';
  }

  @override
  String get databaseCheckNow => '立即檢查更新';

  @override
  String get databaseAllUpdatesDownloaded => '已更新所有有新版本的資料庫。';

  @override
  String get databaseDownloadUpdates => '更新可用更新';

  @override
  String get databaseRouteDatabaseTitle => '路線資料庫';

  @override
  String get databaseDownloaded => '已下載';

  @override
  String get databaseNotDownloadedYet => '尚未下載';

  @override
  String get databaseDataSourceTitle => '資料來源';

  @override
  String get databaseDefaultRegionLabel => '預設顯示地區';

  @override
  String get databaseSelectLocalRegions => '選取要保留在本機的縣市資料庫。';

  @override
  String get databaseSelectedRegionsDownloaded => '已下載選取地區的資料庫。';

  @override
  String get databaseDownloadSelectedRegions => '下載已選地區資料庫';

  @override
  String get databaseDiscordPresenceSection => 'Discord Rich Presence';

  @override
  String get databaseDiscordPresenceTitle => '啓用 Discord Rich Presence';

  @override
  String get databaseDiscordPresenceDescription =>
      '分享你正在看的公車給朋友 (⁠ ⁠/⁠^⁠ω⁠^⁠)⁠/⁠⁠';

  @override
  String get databasePresenceCurrentPage => '目前頁面';

  @override
  String get databasePresenceRegion => '地區';

  @override
  String get databasePresenceRouteName => '路線名稱';

  @override
  String databaseVersionAvailable(int version) {
    return '可更新 v$version';
  }

  @override
  String get databaseNotDownloaded => '未下載';

  @override
  String get databaseLocalVersionNotDownloaded => '本機版本：未下載';

  @override
  String databaseLocalVersion(int version) {
    return '本機版本：$version';
  }

  @override
  String databaseRegionUpdated(String provider) {
    return '$provider資料庫已更新。';
  }

  @override
  String get databaseRedownload => '重新下載';

  @override
  String databaseRegionDeleted(String provider) {
    return '$provider資料庫已刪除。';
  }

  @override
  String databaseDeleteFailed(String error) {
    return '刪除資料庫失敗：$error';
  }

  @override
  String get regionKeelung => '基隆市';

  @override
  String get regionTaipei => '台北市';

  @override
  String get regionNewTaipei => '新北市';

  @override
  String get regionIntercity => '公路客運';

  @override
  String get regionTaoyuan => '桃園市';

  @override
  String get regionHsinchuCity => '新竹市';

  @override
  String get regionHsinchuCounty => '新竹縣';

  @override
  String get regionMiaoli => '苗栗縣';

  @override
  String get regionTaichung => '台中市';

  @override
  String get regionChanghua => '彰化縣';

  @override
  String get regionNantou => '南投縣';

  @override
  String get regionYunlin => '雲林縣';

  @override
  String get regionChiayiCity => '嘉義市';

  @override
  String get regionChiayiCounty => '嘉義縣';

  @override
  String get regionTainan => '台南市';

  @override
  String get regionKaohsiung => '高雄市';

  @override
  String get regionPingtung => '屏東縣';

  @override
  String get regionYilan => '宜蘭縣';

  @override
  String get regionHualien => '花蓮縣';

  @override
  String get regionTaitung => '台東縣';

  @override
  String get regionPenghu => '澎湖縣';

  @override
  String get regionKinmen => '金門縣';

  @override
  String get regionLienchiang => '連江縣';

  @override
  String get personalizationColorScheme => '配色';

  @override
  String get personalizationDarkMode => '深色模式';

  @override
  String get personalizationAmoledTitle => '純黑 (AMOLED) 深色主題';

  @override
  String get personalizationAmoledDescription => '深色模式下使用純黑背景，可省電並提升對比';

  @override
  String get personalizationHomeGradient => '主頁漸層';

  @override
  String get personalizationHomeGradientDescription => '調整主頁漸層背景的透明度';

  @override
  String get personalizationGradientOpacity => '漸層透明度';

  @override
  String get personalizationBackgroundImage => '背景圖片';

  @override
  String get personalizationBackgroundImageDescription =>
      '設定各頁面的背景圖片，首頁背景會同時套用於公車、捷運、高鐵、台鐵、YouBike 等首頁分頁。';

  @override
  String get personalizationChooseImage => '選擇圖片';

  @override
  String get personalizationBackgroundOpacity => '背景透明度';

  @override
  String get personalizationPerPageSettings => '各頁面設定';

  @override
  String get personalizationPerPageDescription => '分別設定每個頁面的背景圖片';

  @override
  String get personalizationOverlayOpacityTitle => '覆蓋層透明度';

  @override
  String get personalizationOverlay => '覆蓋層';

  @override
  String get personalizationColorSystem => '系統';

  @override
  String get personalizationColorAutomaticBackground => '自動（背景圖片）';

  @override
  String get personalizationColorSourceDescription =>
      '「自動」會依背景圖片取色；「系統」會使用裝置的動態配色。';

  @override
  String get personalizationColorAutomatic => '自動';

  @override
  String get personalizationColorCustom => '自訂';

  @override
  String get personalizationChooseColor => '選擇顏色';

  @override
  String get personalizationHue => '色相';

  @override
  String get personalizationSaturation => '飽和';

  @override
  String get personalizationBrightness => '明度';

  @override
  String get personalizationPerPageBackgroundTitle => '各頁面背景設定';

  @override
  String get personalizationGlobalHomeDescription =>
      '同時套用於公車、捷運、高鐵、台鐵、YouBike 首頁';

  @override
  String get personalizationPageGlobalHome => '全域首頁';

  @override
  String get personalizationPageSearch => '搜尋';

  @override
  String get personalizationPageNearby => '附近';

  @override
  String get personalizationPreviewAmoled => 'AMOLED 純黑';

  @override
  String get personalizationAppearancePreview => '外觀預覽';

  @override
  String get personalizationPreviewSearchDescription => '快速查詢即時到站資訊';

  @override
  String get personalizationPreviewFavoritesDescription => '常用站牌與群組';

  @override
  String get personalizationReplaceImage => '更換';

  @override
  String get personalizationRemoveImage => '移除';

  @override
  String get announcementDismissForever => '不再顯示';

  @override
  String get announcementViewDetails => '查看公告';

  @override
  String get databaseUpdatesDialogTitle => '資料庫有新版本';

  @override
  String get databaseUpdatesDialogDescription => '已檢查到以下地區有資料庫更新：';

  @override
  String databaseVersion(int version) {
    return '版本 $version';
  }

  @override
  String get databaseUpdateNow => '立即更新';

  @override
  String get accountProviderDiscord => 'Discord';

  @override
  String get accountProviderGoogle => 'Google';

  @override
  String get accountProviderOAuth => 'OAuth';

  @override
  String get personalizationPreviewAppName => 'YABus';

  @override
  String get personalizationGifBadge => 'GIF';

  @override
  String announcementReactionCount(String emoji, int count) {
    return '$emoji $count';
  }

  @override
  String get weatherTitle => '天氣';

  @override
  String temperatureCelsius(int temperature) {
    return '$temperature°C';
  }

  @override
  String temperatureDegrees(int temperature) {
    return '$temperature°';
  }

  @override
  String get weatherHourly => '逐時';

  @override
  String get weatherWeekly => '一週';

  @override
  String weatherHighLow(int high, int low) {
    return '最高 $high° · 最低 $low°';
  }

  @override
  String get weatherFeelsLike => '體感';

  @override
  String get weatherHumidity => '濕度';

  @override
  String get weatherWindSpeed => '風速';

  @override
  String get weatherPrecipitation => '降雨';

  @override
  String get weatherNow => '現在';

  @override
  String weatherHour(int hour) {
    return '$hour時';
  }

  @override
  String get weatherSunrise => '日出';

  @override
  String get weatherSunset => '日落';

  @override
  String weatherSourceUpdated(String time) {
    return '資料來源：中央氣象署 · 更新於 $time';
  }

  @override
  String get weatherLocationUnavailable => '無法取得目前位置，因此無法顯示天氣。請確認定位服務與定位權限已開啟。';

  @override
  String get weatherLoadFailed => '無法載入天氣資料，請稍後再試。';

  @override
  String get weatherToday => '今天';

  @override
  String get weatherTomorrow => '明天';

  @override
  String weatherWeekday(String weekday) {
    return '週$weekday';
  }

  @override
  String weatherCurrentSemantics(String condition, int temperature) {
    return '目前天氣 $condition，$temperature 度';
  }

  @override
  String weatherViewTooltip(String condition) {
    return '$condition · 查看天氣';
  }

  @override
  String get youBikeLocationUnavailable => '目前無法取得定位，請稍後再試。';

  @override
  String youBikeUsingDefaultArea(String message) {
    return '$message 已改為顯示預設區域。';
  }

  @override
  String get youBikeNearbyStations => '附近站點';

  @override
  String youBikeStationCount(int count) {
    return '$count 站';
  }

  @override
  String get youBikeNoNearbyStations => '附近沒有站點';

  @override
  String get youBikeGeneralBike => '一般車';

  @override
  String get youBikeElectricBike => '2.0E 電輔';

  @override
  String get youBikeReturnSlots => '可還';

  @override
  String youBikeDistance(String distance) {
    return '距離 $distance';
  }

  @override
  String get youBikeStationInfo => '站點資訊';

  @override
  String get youBikeSelectStationHint => '按一下左側站點或地圖上的標記後，這裡就會顯示可借、可還與距離資訊。';

  @override
  String get youBikeLocationAcquired => '已取得目前位置';

  @override
  String get youBikeRelocate => '重新定位';

  @override
  String get youBikeBackToLocation => '回到目前位置';

  @override
  String youBikeAvailability(int general, int electric, int returns) {
    return '一般 $general · 2.0E $electric · 可還 $returns';
  }

  @override
  String get metroSystem => '捷運系統';

  @override
  String get metroNoLineSelected => '尚未選擇路線';

  @override
  String get metroUpdateEta => '更新 ETA';

  @override
  String get metroNoLines => '這個捷運系統目前沒有可用路線。';

  @override
  String get metroTimetableEstimate => '目前改用時刻表推估到站。';

  @override
  String get metroFrequencyOnly => '目前只有班距資訊。';

  @override
  String metroFrequencyEstimate(int min, int max) {
    return '目前以班距估算，約 $min-$max 分鐘。';
  }

  @override
  String get metroEtaUnknown => '目前 ETA 來源未標示。';

  @override
  String get metroLiveArrivals => '即時到站';

  @override
  String get metroStationMap => '站點地圖';

  @override
  String get metroChooseLine => '先選一條捷運路線。';

  @override
  String get metroNoStationSequence => '這條路線目前沒有站序資料。';

  @override
  String get metroRouteMap => '路線地圖';

  @override
  String get metroViewEta => '看 ETA';

  @override
  String get metroNoCoordinates => '這條捷運路線目前沒有可用站點座標。';

  @override
  String get metroTravelDirection => '行駛方向';

  @override
  String metroDirectionHeading(String destination) {
    return '往 $destination';
  }

  @override
  String metroHeadway(int min, int max) {
    return '班距 $min-$max 分';
  }

  @override
  String get metroNoLiveArrivals => '這個車站目前沒有可顯示的即時班次。';

  @override
  String metroFrequencyOnlyEstimate(int min, int max) {
    return '目前僅提供班距估算，約 $min-$max 分鐘。';
  }

  @override
  String metroDestination(String destination) {
    return '往 $destination';
  }

  @override
  String get railOperatingNotices => '營運公告';

  @override
  String get railAllStations => '全部車站';

  @override
  String get railOtherStations => '其他';

  @override
  String railShowDeparted(int count) {
    return '顯示已開出的 $count 班';
  }

  @override
  String railHideDeparted(int count) {
    return '收合已開出的 $count 班';
  }

  @override
  String get railPickerNoMatches => '找不到符合的車站';

  @override
  String get railPickerNoNearby => '找不到附近的車站。';

  @override
  String railPickerNearest(String station, String distance) {
    return '最近的車站：$station（約 $distance）';
  }

  @override
  String get railLocationUnavailable => '目前無法取得定位，請稍後再試。';

  @override
  String get railPickerSearchHint => '搜尋車站名稱或代碼';

  @override
  String get railUseCurrentLocation => '使用目前位置';

  @override
  String get railChooseStation => '選擇車站';

  @override
  String railChooseNamedStation(String station) {
    return '選擇 $station';
  }

  @override
  String get railSameStationExcluded => '這一站已經是另一端的車站';

  @override
  String get railOrigin => '出發站';

  @override
  String get railDestination => '到達站';

  @override
  String get railChooseOrigin => '選擇出發站';

  @override
  String get railChooseDestination => '選擇到達站';

  @override
  String get railSwapStations => '對調出發站與到達站';

  @override
  String get railDeparted => '已開出';

  @override
  String railDelayedMinutes(int minutes) {
    return '晚 $minutes 分';
  }

  @override
  String get railOnTime => '準點';

  @override
  String railDepartsAt(String time) {
    return '$time 發車';
  }

  @override
  String railMinutesUntilDeparture(int minutes) {
    return '$minutes 分後';
  }

  @override
  String railDurationHoursMinutes(int hours, int minutes) {
    return '$hours 小時 $minutes 分';
  }

  @override
  String railDurationMinutes(int minutes) {
    return '$minutes 分';
  }

  @override
  String railTrainSemantics(String trainNo, String trainType, String headline) {
    return '$trainNo 次 $trainType，$headline';
  }

  @override
  String railTrainSemanticsWithStatus(
    String trainNo,
    String trainType,
    String headline,
    String status,
  ) {
    return '$trainNo 次 $trainType，$headline，$status';
  }

  @override
  String railRouteWithTimes(
    String origin,
    String departure,
    String destination,
    String arrival,
  ) {
    return '$origin $departure → $destination $arrival';
  }

  @override
  String railStationRange(String origin, String destination) {
    return '$origin → $destination';
  }

  @override
  String railTimeRange(String departure, String arrival) {
    return '$departure → $arrival';
  }

  @override
  String get traServices => '班次';

  @override
  String get traStationMap => '車站地圖';

  @override
  String get traSelectDifferentStations => '出發站和到達站不能一樣。';

  @override
  String get traUseLocationOrigin => '用目前位置選出發站';

  @override
  String get traSelectionPrompt => '選好出發站和到達站，就會顯示今天還搭得到的班次。';

  @override
  String get traSearching => '查詢中…';

  @override
  String get traNoDirectServices => '這兩站之間今天沒有直達班次，可能需要轉車。';

  @override
  String traRemainingServices(int count) {
    return '還有 $count 班可搭';
  }

  @override
  String traAllServicesDeparted(String origin, String destination) {
    return '今天從 $origin 到 $destination 的班次都開完了。';
  }

  @override
  String get traViewTomorrow => '看明天的班次';

  @override
  String get traViewServices => '看班次';

  @override
  String get traMapHint => '點站牌可設為出發站或到達站，點紅色列車標記看估算中的列車位置。';

  @override
  String get traMapNoCoordinates => '台鐵站點目前沒有可用座標。';

  @override
  String get traSetOrigin => '設為出發站';

  @override
  String get traSetDestination => '設為到達站';

  @override
  String traPositionArrived(String station) {
    return '已到 $station';
  }

  @override
  String traPositionStopped(String station) {
    return '停靠 $station';
  }

  @override
  String get traTrainPositionEstimate => '列車位置估算';

  @override
  String traEstimatedBetween(String current, String next) {
    return '目前估算在 $current 與 $next 之間';
  }

  @override
  String traEstimatedArrived(String station) {
    return '目前估算已到達 $station';
  }

  @override
  String traEstimatedStopped(String station) {
    return '目前估算停靠在 $station';
  }

  @override
  String traSegmentProgress(int percent) {
    return '路段進度 $percent%';
  }

  @override
  String traDataUpdated(String time) {
    return '資料更新 $time';
  }

  @override
  String get thsrSeatOverview => '座位即時概況';

  @override
  String get thsrObservedStation => '觀察車站';

  @override
  String get thsrChooseStation => '選擇車站';

  @override
  String get thsrSelectStationForSeats => '先選一個車站，再看最近幾班高鐵的座位狀況。';

  @override
  String thsrNoStationSeats(String station) {
    return '目前沒有 $station 的座位即時資料。';
  }

  @override
  String get thsrSearchServices => '查詢班次';

  @override
  String get thsrNotSearched => '尚未查詢班次';

  @override
  String thsrServicesSummary(int upcoming, int total) {
    return '還有 $upcoming 班可搭（共 $total 班）';
  }

  @override
  String get thsrQueryPrompt => '選好起訖站與日期後，就能看高鐵班次。';

  @override
  String get thsrDayDeparted => '這一天的班次都開完了。';

  @override
  String get thsrSeatTitle => '自由座與商務車座位';

  @override
  String get thsrQueryStation => '查詢站點';

  @override
  String get thsrSelectStationSeats => '先選一個站，再看各班次座位餘量。';

  @override
  String get thsrNoSeatData => '目前沒有可顯示的座位資料。';

  @override
  String get thsrMapTitle => '站點地圖';

  @override
  String get thsrViewSeats => '看座位';

  @override
  String get thsrMapNoCoordinates => '高鐵站點目前沒有可用座標。';

  @override
  String get thsrTimetable => '班次查詢';

  @override
  String get thsrSeats => '座位資訊';

  @override
  String get thsrTrainLabel => '高鐵';

  @override
  String thsrNoSeatField(String station) {
    return '這班車目前沒有 $station 的座位欄位。';
  }

  @override
  String get thsrStandardCar => '標準車';

  @override
  String get thsrBusinessCar => '商務車';

  @override
  String get thsrNotProvided => '未提供';

  @override
  String get thsrStationNoSeats => '這個站目前沒有可顯示的座位資料。';

  @override
  String thsrDepartureTime(String time) {
    return '$time 發車';
  }
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'YetAnotherBusApp';

  @override
  String get settingsTitle => '設定';

  @override
  String get appearanceSectionTitle => '外觀';

  @override
  String get languageLabel => '語言';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get interfaceScaleLabel => '介面縮放';

  @override
  String get interfaceScaleDescription => '調整文字與介面元素的大小。';

  @override
  String interfaceScaleValue(int percent) {
    return '$percent%';
  }

  @override
  String get themeModeLabel => '主題模式';

  @override
  String get themeModeSystem => '跟隨系統';

  @override
  String get themeModeLight => '淺色';

  @override
  String get themeModeDark => '深色';

  @override
  String get compactModeTitle => '精簡模式';

  @override
  String get compactModeDescription => '首頁與部分卡片減少說明文字顯示；桌面首頁固定維持精簡。';

  @override
  String get showWeatherTitle => '顯示天氣';

  @override
  String get showWeatherDescription => '在首頁標題旁顯示目前氣溫，點一下可開啟完整預報。';

  @override
  String get mapProviderLabel => '地圖提供者';

  @override
  String get personalizationTitle => '個人化';

  @override
  String get personalizationDescription => '配色、背景透明度';

  @override
  String get commonCancel => '取消';

  @override
  String get commonDelete => '刪除';

  @override
  String get commonRetry => '重試';

  @override
  String get commonSettings => '設定';

  @override
  String get commonOpenSettings => '開啓設定';

  @override
  String get commonRefresh => '重新整理';

  @override
  String get commonBack => '返回';

  @override
  String get commonDownload => '下載';

  @override
  String get commonDownloading => '下載中...';

  @override
  String get commonDone => '完成';

  @override
  String get commonLater => '稍後再說';

  @override
  String get commonNotNow => '先不要';

  @override
  String get commonUpdate => '更新';

  @override
  String get commonView => '查看';

  @override
  String get commonReload => '重新載入';

  @override
  String get commonClear => '清除';

  @override
  String get commonCenter => '置中';

  @override
  String commonPercentage(int value) {
    return '$value%';
  }

  @override
  String get errorGeneric => '發生錯誤，請稍後再試。';

  @override
  String get errorNetwork => '網路連線異常，請確認網路後再試。';

  @override
  String get errorTimeout => '連線逾時，請稍後再試。';

  @override
  String get errorRateLimited => '請求次數過多，請稍後再試。';

  @override
  String get transitBus => '公車';

  @override
  String get transitMetro => '捷運';

  @override
  String get transitThsr => '高鐵';

  @override
  String get transitTra => '台鐵';

  @override
  String get transitYouBike => 'YouBike';

  @override
  String get transitBusHomePresence => '公車首頁';

  @override
  String get homeSearchTitle => '搜尋路線';

  @override
  String get homeSearchDescription => '輸入公車號碼、路線名稱或客運路線，直接看即時到站資訊。';

  @override
  String get homeFavoritesTitle => '我的最愛';

  @override
  String get homeFavoritesDescription => '整理常用站牌與群組，快速跳回指定站點。';

  @override
  String get homeNearbyTitle => '附近站牌';

  @override
  String get homeNearbyDescription => '依照你目前位置找附近的公車站牌。';

  @override
  String get homeBusMapTitle => '全公車地圖';

  @override
  String get homeBusMapDescription => '看整個縣市的公車現在開到哪，點一輛就能看它的路線與站牌。';

  @override
  String get homeOverviewTitle => '總覽';

  @override
  String homeSelectedRegions(int count) {
    return '已選 $count 個地區';
  }

  @override
  String get homeOpenSettings => '開啓設定';

  @override
  String get databaseDownloadsTitle => '資料庫與下載';

  @override
  String get announcementsTitle => '公告';

  @override
  String get installAppTooltip => '安裝 App';

  @override
  String get installAppTitle => '要安裝成應用程式嗎？';

  @override
  String get installAppDescription => '把 YABus 安裝成應用程式，之後就能像一般應用程式一樣開啓。';

  @override
  String get installAppLimitation => '功能會比原版應用程式少就是了';

  @override
  String get installAppConfirm => '當然好啊 ＼(^o^)／';

  @override
  String get installRequestSent => '已送出安裝要求。';

  @override
  String get installCancelled => '已取消安裝。';

  @override
  String get installUnavailable => '這個裝置目前無法顯示安裝提示。';

  @override
  String get smartRecommendationsTitle => '智慧推薦';

  @override
  String get smartRecommendationsSubtitle => '根據你的使用習慣推薦路線';

  @override
  String get smartRecommendationsDisabled =>
      '這個功能目前已關閉。開啓後，YABus 會學習你在不同時段最常點開的路線，並在首頁直接推薦。';

  @override
  String get smartRecommendationsGoToSettings => '前往設定';

  @override
  String get smartRecommendationsNeedDatabase =>
      '請先下載本地資料庫。下載完成後，這張卡片才會開始學習你的使用習慣並顯示附近站牌到站時間。';

  @override
  String destinationStopId(int stopId) {
    return '目的地站牌 $stopId';
  }

  @override
  String directionValue(String direction) {
    return '方向：$direction';
  }

  @override
  String destinationValue(String destination) {
    return '目的地：$destination';
  }

  @override
  String approximateDistance(String distance) {
    return '距離你約 $distance';
  }

  @override
  String get tryAgainLater => '請稍後重試。';

  @override
  String get nearbyMapTitle => '附近地圖';

  @override
  String get nearbyMapSubtitle => '今天想去哪搭公車？';

  @override
  String get refreshNearbyStops => '重整附近站牌';

  @override
  String get nearbyNoStopsToDisplay => '附近暫時沒有可顯示的站牌。';

  @override
  String get mapNoLocations => '目前沒有可顯示的站點位置。';

  @override
  String get locationServicesDisabled => '定位服務尚未開啓。';

  @override
  String get locationPermissionDenied => '沒有取得定位權限。';

  @override
  String get searchTitle => '搜尋路線或站牌';

  @override
  String get searchHint => '搜尋公車路線或站牌名稱';

  @override
  String get searchClearTooltip => '清除搜尋';

  @override
  String get searchShowKeypadTooltip => '開啓快捷鍵盤';

  @override
  String get searchErrorTitle => '搜尋撞到貓貓了';

  @override
  String get searchResolvingTitle => '貓貓正在翻站牌';

  @override
  String get searchResolvingMessage => '正在搜尋附近可搭的站牌...';

  @override
  String get searchEmptyTitle => '沒有找到這台貓公車';

  @override
  String get searchEmptyMessage => '試試看少打一點，或換成站牌名稱搜尋。';

  @override
  String get searchEmptyNeedsDatabase => '部分站牌搜尋需要本機資料庫，先更新資料庫後再試一次。';

  @override
  String get searchHistoryEmpty => '還沒有搜尋紀錄。';

  @override
  String get searchRecentTitle => '最近搜尋';

  @override
  String searchNearestStop(String stopName, String distance) {
    return '離你最近：$stopName ($distance)';
  }

  @override
  String get searchKeypadTitle => '路線字首與號碼';

  @override
  String get searchKeypadCollapseTooltip => '收合快捷鍵盤';

  @override
  String get searchKeypadTextTooltip => '切換文字鍵盤';

  @override
  String get searchKeypadBackspaceTooltip => '退格';

  @override
  String get searchKeypadOther => '其他';

  @override
  String get nearbyTitle => '附近站牌';

  @override
  String get nearbyLocationSettings => '定位設定';

  @override
  String get nearbyPermissionSettings => '權限設定';

  @override
  String get nearbyEmpty => '附近沒有找到站牌。';

  @override
  String get favoritesTitle => '我的最愛';

  @override
  String get favoritesUpdating => '正在更新';

  @override
  String get favoritesRealtimeUpdateFailed => '即時資訊更新失敗';

  @override
  String get favoritesNoRealtime => '目前沒有可用的即時資訊';

  @override
  String get favoritesPartialUpdateFailed => '部分即時資訊更新失敗';

  @override
  String get favoritesLoadFailed => '載入失敗';

  @override
  String get favoritesUpdateFailedKeepingData => '更新失敗，保留上一筆資料';

  @override
  String favoriteRemoved(String item, String group) {
    return '已從 $group 移除 $item';
  }

  @override
  String get favoriteTypeRoute => '路線';

  @override
  String get favoriteTypeStation => '整站';

  @override
  String get favoriteTypeBoarding => '站牌';

  @override
  String get favoriteGroupKindMixed => '綜合';

  @override
  String get favoriteNoUpcomingArrivals => '目前沒有即將抵達班次';

  @override
  String favoriteStationSide(String side) {
    return '$side 側';
  }

  @override
  String routeIdFallback(int routeId) {
    return '路線 $routeId';
  }

  @override
  String stopIdFallback(int stopId) {
    return '站牌 $stopId';
  }

  @override
  String get favoriteFetchingRealtime => '正在取得即時資訊';

  @override
  String get favoriteNoSelectableStops => '這條路線目前沒有可選的站牌。';

  @override
  String stopSequence(int number) {
    return '第 $number 站';
  }

  @override
  String favoriteDestinationSet(String stopName) {
    return '已將目的地設為 $stopName';
  }

  @override
  String get favoriteDestinationCleared => '已清除這個最愛的目的地設定';

  @override
  String get favoritesFinishSorting => '完成排序';

  @override
  String get favoritesAdjustSorting => '調整排序';

  @override
  String get favoritesManageGroupsTooltip => '管理最愛群組';

  @override
  String favoritesUpdateCountdown(int seconds) {
    return '$seconds 秒後更新';
  }

  @override
  String get favoritesErrorTitle => '最愛清單卡住了';

  @override
  String get favoritesTryAgain => '再試一次';

  @override
  String get favoritesGroupEmpty => '這個群組目前沒有收藏。';

  @override
  String routeKeyFallback(int routeKey) {
    return 'routeKey $routeKey';
  }

  @override
  String get favoriteDestinationSettings => '目的地設定';

  @override
  String get favoriteSetDestination => '設定目的地';

  @override
  String get favoriteClearDestination => '清除目的地';

  @override
  String get favoritesEmptyMessage => '還沒有任何已收藏的站牌 :(';

  @override
  String get favoritesEmptyTitle => '貓貓還沒有固定站牌';

  @override
  String get favoriteGroupsTitle => '最愛群組';

  @override
  String get favoriteGroupAddTitle => '新增群組';

  @override
  String get favoriteGroupNameLabel => '群組名稱';

  @override
  String get favoriteGroupNameHint => '例如：回家';

  @override
  String get favoriteGroupCategoryLabel => '收藏類別';

  @override
  String get favoriteGroupAddAction => '新增';

  @override
  String get favoriteGroupDuplicate => '已有相同名稱的收藏群組。';

  @override
  String get favoriteGroupsEmpty => '還沒有群組。';

  @override
  String get favoriteGroupDeleteTitle => '刪除群組';

  @override
  String favoriteGroupDeletePrompt(String group) {
    return '確定要刪除「$group」嗎？';
  }

  @override
  String favoriteGroupSummary(String kind, int count) {
    return '$kind · $count 個收藏';
  }

  @override
  String get accountTitle => '帳戶';

  @override
  String get accountSignedOut => '尚未登入。';

  @override
  String accountSignedInAs(String name) {
    return '已登入為 $name';
  }

  @override
  String wearConnectedWatch(String names) {
    return '已連接的手錶：$names';
  }

  @override
  String wearConnectedWatches(String names, int count) {
    return '已連接的手錶：$names 等 $count 台';
  }

  @override
  String get wearSyncTitle => '啓用 Wear OS 同步';

  @override
  String get wearSyncDescription => '將最愛站牌同步到手錶';

  @override
  String get wearNoFavorites => '尚無最愛站牌。請先新增最愛，再進行同步。';

  @override
  String get wearSyncCategory => '同步分類';

  @override
  String get wearAllCategories => '所有分類';

  @override
  String databaseCurrentRegion(String region) {
    return '目前地區：$region';
  }

  @override
  String databaseStartupUpdate(String mode) {
    return '啓動更新：$mode';
  }

  @override
  String databasePendingRegions(int count) {
    return '目前有 $count 個地區可更新';
  }

  @override
  String get databaseOpenPage => '開啓資料庫頁面';

  @override
  String get usageAndUpdatesTitle => '使用與更新';

  @override
  String get alwaysShowSecondsTitle => '強制顯示秒數';

  @override
  String get alwaysShowSecondsDescription => '這個通常不太準';

  @override
  String get hapticFeedbackTitle => '震動回饋';

  @override
  String get hapticFeedbackDescription => '點選及操作時提供觸覺回饋';

  @override
  String get showAdsTitle => '顯示廣告';

  @override
  String get adsLockedMessage => ' 再玩啊哈哈';

  @override
  String get adsEnabledDescription => '把開發者的飯碗搶走。';

  @override
  String get adsPleaOne => '我求你了';

  @override
  String get adsPleaTwo => '我跪著有用嗎';

  @override
  String get adsPleaThree => '你不能這樣對我';

  @override
  String get adsPleaFour => 'QAQ';

  @override
  String get adsDisableTitle => '你確定嗎';

  @override
  String get adsDisableDescription => '我沒有摳摳 :(';

  @override
  String get adsKeepEnabled => '算了不關';

  @override
  String get adsDisableConfirm => '確定關閉';

  @override
  String get smartRecommendationsDescription => '依照你常開啓的時段與路線，在首頁顯示推薦。';

  @override
  String get autoFavoriteTitle => '自動加入常用最愛';

  @override
  String get autoFavoriteDescription => '同一站牌短期內搭乘多次後，自動加入「常用」最愛群組。';

  @override
  String get smartNotificationTitle => '智慧推薦通知';

  @override
  String get smartNotificationDescription => '在常用時段背景提醒你可能想看的路線。';

  @override
  String get smartNotificationPermissionRequired => '需要通知權限才能啓用智慧推薦通知。';

  @override
  String get keepScreenAwakeTitle => '進入公車頁保持亮屏';

  @override
  String get keepScreenAwakeDescription => '在路線詳細頁面維持螢幕常亮。';

  @override
  String get backgroundTripTitle => '背景乘車提醒';

  @override
  String get backgroundTripDescription => '需要通知與定位權限，才能在背景持續提醒搭車狀態。';

  @override
  String get backgroundTripIosDescription => '需要通知與背景定位權限，才能在背景持續提醒搭車狀態。';

  @override
  String get favoriteWidgetRefreshLabel => '最愛小工具背景更新';

  @override
  String get favoriteWidgetRefreshHelper => 'Android 小工具最低更新間隔為 15 分鐘。';

  @override
  String minutesValue(int minutes) {
    return '$minutes 分鐘';
  }

  @override
  String normalUpdateInterval(int seconds) {
    return '一般更新間隔：$seconds 秒';
  }

  @override
  String retryInterval(int seconds) {
    return '錯誤後重試間隔：$seconds 秒';
  }

  @override
  String secondsValue(int seconds) {
    return '$seconds 秒';
  }

  @override
  String get appUpdatesTitle => 'App 更新';

  @override
  String get updateChannelLabel => '更新通道';

  @override
  String get updateCheckOnLaunchLabel => '啓動時檢查';

  @override
  String get updateChannelDeveloper => '開發版';

  @override
  String get updateChannelNightly => 'Nightly';

  @override
  String get updateChannelRelease => 'Release';

  @override
  String get updateChannelDeveloperDescription => '不檢查 app 更新';

  @override
  String get updateChannelNightlyDescription => '比對最新成功建置的 commit';

  @override
  String get updateChannelReleaseDescription => '比對 GitHub 最新發行版';

  @override
  String get updateCheckOff => '關閉';

  @override
  String get updateCheckNotify => '通知';

  @override
  String get updateCheckPopup => '跳窗';

  @override
  String get updateCheckOffDescription => '只在手動檢查時顯示';

  @override
  String get updateCheckNotifyDescription => '啓動後用通知提示';

  @override
  String get updateCheckPopupDescription => '啓動後直接跳出更新視窗';

  @override
  String get appUpdateChecking => '檢查中…';

  @override
  String get appUpdateCheckNow => '立即檢查 App 更新';

  @override
  String appUpdateRecentResult(String result) {
    return '最近結果：$result';
  }

  @override
  String appUpdateAvailableResult(String version) {
    return '有新版本可用：$version';
  }

  @override
  String get appUpdateUpToDateResult => '目前已是最新版本。';

  @override
  String get appUpdateUnavailableResult => '目前無法取得更新資訊。';

  @override
  String get appUpdateNightlyDialogTitle => 'Nightly 更新';

  @override
  String appUpdateReleaseDialogTitle(String version) {
    return 'Release 更新：$version';
  }

  @override
  String appUpdateNightlySummary(String commit) {
    return 'Nightly 建置 $commit 已可下載。';
  }

  @override
  String appUpdateCurrentVersion(String version) {
    return '目前版本：$version';
  }

  @override
  String appUpdateLatestVersion(String version) {
    return '最新版本：$version';
  }

  @override
  String appUpdateFullChangesMarkdown(String range, String url) {
    return '完整變更：[$range]($url)';
  }

  @override
  String appUpdateCommitMarkdown(String commit, String url) {
    return 'Commit：[`$commit`]($url)';
  }

  @override
  String get appUpdateContentsTitle => '更新內容';

  @override
  String get appUpdateDownloadLink => '下載連結';

  @override
  String get appUpdateCopyDownloadLink => '複製下載連結';

  @override
  String get appUpdateDownloadLinkCopied => '下載連結已複製到剪貼簿。';

  @override
  String get appUpdateDownloadAndInstall => '下載並安裝';

  @override
  String get appUpdatePreparing => '準備更新…';

  @override
  String get appUpdateDownloading => '下載更新中…';

  @override
  String get appUpdatePreparingInstaller => '整理安裝檔中…';

  @override
  String get appUpdateLaunchingInstaller => '啓動安裝程式…';

  @override
  String get appUpdatePreparingDesktopInstaller => '準備關閉 App 並啓動安裝程式…';

  @override
  String get appUpdateInstallUnsupported => '這個平台不支援 app 內安裝更新。';

  @override
  String get appUpdateInstallPermissionRequired =>
      '請先允許這個 app 安裝未知應用程式，再重新點一次更新。';

  @override
  String get appUpdateInstallerLaunched => '安裝程式已啓動。';

  @override
  String get appUpdateDesktopInstallerScheduled => '即將關閉 App 並啓動安裝程式。';

  @override
  String appUpdateInstallFailed(String error) {
    return '下載或安裝更新失敗：$error';
  }

  @override
  String get historyPrivacyTitle => '紀錄與隱私';

  @override
  String searchHistoryLimit(int count) {
    return '搜尋紀錄上限：$count 筆';
  }

  @override
  String itemsValue(int count) {
    return '$count 筆';
  }

  @override
  String smartRoutesCount(int count) {
    return '智慧推薦路線：$count 條';
  }

  @override
  String routeSelectionsCount(int count) {
    return '路線選擇紀錄：$count 次';
  }

  @override
  String get clearSearchHistory => '清除搜尋紀錄';

  @override
  String get clearSmartHistory => '清除智慧推薦紀錄';

  @override
  String get clearRouteSelectionHistory => '清除路線選擇紀錄';

  @override
  String get termsOfService => '服務條款';

  @override
  String get privacyPolicy => '隱私權政策';

  @override
  String get onboardingSettingsTitle => '開始流程';

  @override
  String get restartOnboarding => '重新執行開始流程';

  @override
  String get aboutTitle => '關於';

  @override
  String get contributorsTitle => '貢獻者';

  @override
  String get communityTitle => '加入角蛙社群';

  @override
  String get communityDescription => '我的 Discord 伺服器 uwu';

  @override
  String get feedbackTitle => '意見回饋';

  @override
  String get feedbackDescription => '回報問題、提出功能需求或任何想說的話';

  @override
  String get discordOpenFailed => '無法開啓 Discord 社群連結。';

  @override
  String get instagramOpenFailed => '無法開啓 Instagram 頁面。';

  @override
  String githubOpenFailed(String name) {
    return '無法開啓 $name 的 GitHub 頁面。';
  }

  @override
  String get databaseAutoUpdateOff => '不檢查';

  @override
  String get databaseAutoUpdatePopup => '檢查更新並彈窗';

  @override
  String get databaseAutoUpdateNotify => '檢查更新並提示';

  @override
  String get databaseAutoUpdateAlways => '總是自動更新';

  @override
  String get databaseAutoUpdateWifi => '僅 Wi-Fi 自動更新';

  @override
  String get databaseAutoUpdateCellular => '僅行動數據自動更新';

  @override
  String get onboardingLocationServiceDisabled => '定位服務尚未開啓。你仍可手動選擇資料庫。';

  @override
  String get onboardingLocationPermissionDenied => '沒有取得定位權限。請改為手動選擇資料庫。';

  @override
  String get onboardingLocationUnavailable => '定位權限已授權，但暫時無法取得位置。請改為手動選擇資料庫。';

  @override
  String onboardingProviderSelected(String provider) {
    return '已自動選擇最近的資料庫：$provider。';
  }

  @override
  String onboardingLocationFailed(String error) {
    return '定位設定失敗（$error）。請改為手動選擇資料庫。';
  }

  @override
  String get onboardingWelcome => '歡迎來到 YABus';

  @override
  String get onboardingSearchDescription => '輸入公車名稱或號碼，直接打開即時站牌頁。';

  @override
  String get onboardingFavoritesTitle => '收藏站牌';

  @override
  String get onboardingFavoritesDescription => '把常搭的站牌分群保存，下次一鍵回來。';

  @override
  String get onboardingNearbyDescription => '配合定位權限快速找周邊站點。';

  @override
  String get onboardingLegalPrefix => '繼續即代表您同意我們的';

  @override
  String get onboardingLegalAnd => '及';

  @override
  String get onboardingLegalSuffix => '。';

  @override
  String get onboardingStart => '開始設定';

  @override
  String get onboardingLocationTitle => '定位權限';

  @override
  String get onboardingLocationDescription => '我們需要定位權限來取得最近的站牌資訊。';

  @override
  String get onboardingLocationConsent => '允許即代表你同意將定位資訊提供給程式進行處理。（用於取得最近站牌）';

  @override
  String get onboardingLocationServerUse => '僅在無資料庫可用時才會將位置提供給伺服器。';

  @override
  String get onboardingProcessing => '處理中...';

  @override
  String get onboardingAllowContinue => '授權並繼續';

  @override
  String get onboardingChooseManually => '手動選擇資料庫';

  @override
  String get onboardingDownloadTitle => '下載資料庫';

  @override
  String get onboardingDownloadDescription => '可複選要在這台裝置使用的縣市資料庫。';

  @override
  String get onboardingRegionList => '縣市清單';

  @override
  String onboardingNearestSuggestion(String provider) {
    return '最近建議：$provider';
  }

  @override
  String onboardingDefaultSource(String provider) {
    return '預設資料來源：$provider';
  }

  @override
  String onboardingSelectedDatabases(String providers) {
    return '已選資料庫：$providers';
  }

  @override
  String onboardingDatabaseProgress(int downloaded, int total) {
    return '已下載 $downloaded / $total 份資料庫';
  }

  @override
  String onboardingDownloadFailed(String error) {
    return '下載失敗：$error';
  }

  @override
  String shellWebUpdateAvailable(String version, String buildNumber) {
    return '有新版本可用（$version+$buildNumber）';
  }

  @override
  String get shellEnableSyncTitle => '啓用雲端同步？';

  @override
  String get shellEnableSyncDescription =>
      '登入後可以自動同步最愛站牌與偏好設定。之後進入 app 時會自動更新，資料變更後也會稍後自動同步。';

  @override
  String get shellEnableSyncAction => '開啓同步';

  @override
  String get shellSyncEnabled => '已開啓雲端同步。';

  @override
  String get shellSyncSkipped => '已略過自動同步，你之後仍可手動同步。';

  @override
  String shellSyncPreferenceFailed(String error) {
    return '設定同步偏好失敗：$error';
  }

  @override
  String get shellSignInSucceeded => '登入成功。';

  @override
  String shellSignInFailed(String error) {
    return '登入失敗：$error';
  }

  @override
  String shellAccountLinked(String provider) {
    return '已連結 $provider 帳號。';
  }

  @override
  String shellAccountAlreadyLinked(String provider) {
    return '$provider 已在此帳號上。';
  }

  @override
  String shellLinkFailed(String error) {
    return '連結失敗：$error';
  }

  @override
  String get shellMergeAccountsTitle => '合併帳號？';

  @override
  String shellMergeAccountsDescription(String provider) {
    return '「$provider」已經屬於另一個帳號。合併後下列身分與資料會移入目前帳號，來源帳號將被刪除：';
  }

  @override
  String shellActiveDevices(int count) {
    return '來源帳號目前有 $count 台啓用中的裝置。';
  }

  @override
  String get shellMergeAccountsAction => '合併帳號';

  @override
  String shellAccountsMerged(String provider) {
    return '帳號已合併，$provider 已連結到目前帳號。';
  }

  @override
  String shellMergeFailed(String error) {
    return '合併失敗：$error';
  }

  @override
  String get shellDatabaseUpdating => '正在更新資料庫...';

  @override
  String shellDatabaseUpdated(String providers) {
    return '資料庫已更新：$providers';
  }

  @override
  String shellDatabaseAutoUpdateFailed(String error) {
    return '自動更新資料庫失敗：$error';
  }

  @override
  String get shellDatabaseUpdateComplete => '資料庫更新完成。';

  @override
  String shellDatabaseUpdateFailed(String error) {
    return '資料庫更新失敗：$error';
  }

  @override
  String shellDatabaseUpdatesAvailable(String providers) {
    return '資料庫有新版本：$providers';
  }

  @override
  String shellDatabaseCheckFailed(String error) {
    return '檢查資料庫更新失敗：$error';
  }

  @override
  String get shellDatabaseUpdateDeferred => '資料庫更新已延後。';

  @override
  String get etaLoading => '載入中';

  @override
  String get etaArriving => '進站中';

  @override
  String etaSeconds(int seconds) {
    return '$seconds秒';
  }

  @override
  String etaMinutes(int minutes) {
    return '$minutes分';
  }

  @override
  String etaMinutesSeconds(int minutes, int seconds) {
    return '$minutes分\n$seconds秒';
  }

  @override
  String get autoFavoriteFallback => '這個站牌';

  @override
  String autoFavoriteAdded(String label) {
    return '常搭這班車？已自動把「$label」加入常用最愛。';
  }

  @override
  String get commonClose => '關閉';

  @override
  String get commonOkay => '好的';

  @override
  String get commonEnable => '啓用';

  @override
  String get commonUndo => '復原';

  @override
  String get commonAll => '全部';

  @override
  String get commonAddToHomeScreen => '新增到主畫面';

  @override
  String get commonChooseStop => '選擇站牌';

  @override
  String get commonAcknowledge => '知道了';

  @override
  String get directionOutbound => '去程';

  @override
  String get directionInbound => '返程';

  @override
  String directionNumber(int direction) {
    return '方向 $direction';
  }

  @override
  String directionTo(String destination) {
    return '往 $destination';
  }

  @override
  String relativeSecondsAgo(int count) {
    return '$count 秒前';
  }

  @override
  String relativeMinutesAgo(int count) {
    return '$count 分鐘前';
  }

  @override
  String relativeHoursAgo(int count) {
    return '$count 小時前';
  }

  @override
  String relativeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String distanceMetersValue(int meters) {
    return '$meters 公尺';
  }

  @override
  String distanceKilometersValue(String kilometers) {
    return '$kilometers 公里';
  }

  @override
  String speedKilometersPerHour(int speed) {
    return '$speed 公里/小時';
  }

  @override
  String get busStatusNormal => '正常';

  @override
  String get busStatusAccident => '車禍';

  @override
  String get busStatusBreakdown => '故障';

  @override
  String get busStatusTraffic => '塞車';

  @override
  String get busStatusEmergency => '緊急求援';

  @override
  String get busStatusRefueling => '加油';

  @override
  String get busStatusUnclear => '不明';

  @override
  String get busStatusDirectionUnclear => '去回不明';

  @override
  String get busStatusOffRoute => '偏移路線';

  @override
  String get busStatusNotInService => '非營運狀態';

  @override
  String get busStatusFull => '客滿';

  @override
  String get busStatusChartered => '包車出租';

  @override
  String get busStatusUnknown => '未知';

  @override
  String busStatusUnknownCode(int code) {
    return '未知（$code）';
  }

  @override
  String get stationFallbackTitle => '整站';

  @override
  String get stationShortcutRequested => '已送出整站捷徑要求。';

  @override
  String get shortcutUnsupported => '這台裝置不支援主畫面捷徑。';

  @override
  String get stationNotFound => '找不到這一站的整站資料。';

  @override
  String get stationPinTooltip => '將整站新增到主畫面';

  @override
  String get stationNoSides => '這一站目前沒有可顯示的站牌。';

  @override
  String stationSideLabel(String side) {
    return '站牌 $side';
  }

  @override
  String stationSideDirection(String side, String direction) {
    return '$side · $direction';
  }

  @override
  String stationSideNoRoutes(String side) {
    return '站牌 $side 目前沒有經過路線。';
  }

  @override
  String busMapTitle(String region) {
    return '全公車地圖 · $region';
  }

  @override
  String busMapRouteDataLoadFailed(String error) {
    return '無法載入路線資料：$error';
  }

  @override
  String get busMapRouteDetailUnavailable => '這條路線目前沒有可查詢的詳細資料。';

  @override
  String busMapSwitchedRegion(String region) {
    return '已切換至$region';
  }

  @override
  String get busMapCloseFilter => '關閉篩選';

  @override
  String get busMapFilterRoutes => '篩選路線';

  @override
  String get busMapFavoritesOnly => '只看最愛路線';

  @override
  String get busMapLocate => '定位';

  @override
  String get busMapSwitchRegion => '切換縣市';

  @override
  String get busMapFilterHint => '篩選路線名稱或車牌';

  @override
  String get busMapNoData => '目前沒有公車資料';

  @override
  String get busMapLoadingPositions => '正在載入公車位置…';

  @override
  String busMapBusCount(int count) {
    return '$count 輛公車';
  }

  @override
  String busMapBusCountUpdated(int count, String updated) {
    return '$count 輛公車 · $updated';
  }

  @override
  String get busMapZoomForBuses => '放大或點圓圈看個別公車';

  @override
  String busMapShownCount(int shown, int total) {
    return '顯示 $shown／$total 輛，放大看更多';
  }

  @override
  String get busMapNoFavoriteRoutes => '最愛中沒有此縣市的路線';

  @override
  String get busMapNoMatches => '找不到符合的公車';

  @override
  String get busMapDataStale => '資料可能不是最新';

  @override
  String get busMapDataIncomplete => '資料可能不完整';

  @override
  String get busMapUnsupportedTitle => '此縣市暫不支援全公車地圖';

  @override
  String get busMapUnsupportedMessage => '可以從右上角切換其他縣市。';

  @override
  String get busMapRouteStops => '沿途站牌';

  @override
  String get busMapSelectionHint => '點一輛公車就能看到它的路線、方向與沿途站牌。';

  @override
  String busMapClusterCount(int count) {
    return '$count 輛公車';
  }

  @override
  String busMapClusterSemantics(int count) {
    return '此處有 $count 輛公車，點一下放大';
  }

  @override
  String get busMapYourLocation => '你的位置';

  @override
  String get busMapClearSelection => '取消選取';

  @override
  String busMapSameRouteRunning(int count) {
    return '同路線 $count 輛行駛中';
  }

  @override
  String busMapBareRouteCode(String code) {
    return '這輛車的路線代碼是 $code，尚無路線名稱。';
  }

  @override
  String busMapAmbiguousFamily(String family) {
    return '這輛車屬於「$family」路線群，無法判定是哪個區間班次。';
  }

  @override
  String get busMapRouteDetails => '路線詳情';

  @override
  String get busMapShowWholeRoute => '顯示整條路線';

  @override
  String get routeMapRefreshing => '更新中';

  @override
  String routeMapRefreshCountdown(int seconds) {
    return '$seconds 秒後更新';
  }

  @override
  String get routeMapTitle => '公車地圖';

  @override
  String get routeMapToggleBuses => '公車';

  @override
  String get routeMapToggleStops => '站牌';

  @override
  String get routeMapRecenter => '回到你的位置';

  @override
  String get routeMapNoData => '目前沒有可顯示的路線地圖資料';

  @override
  String get routeMapSpeed => '速度';

  @override
  String get routeMapBearing => '方位';

  @override
  String get routeMapUpdated => '更新';

  @override
  String get routeMapPosition => '位置';

  @override
  String get routeMapStopSequence => '站序';

  @override
  String get routeMapArrival => '到站';

  @override
  String get routeMapAngle => '角度';

  @override
  String get routeMapStatus => '狀態';

  @override
  String get routeMapOnRoute => '沿路線';

  @override
  String get routeMapSnappedToRoute => '貼線';

  @override
  String routeMapOffRoute(int meters) {
    return '離線路 ${meters}m';
  }

  @override
  String routeMapOffLine(int meters) {
    return '離線 ${meters}m';
  }

  @override
  String get transferMissingCoordinates => '這個站牌沒有座標資料，無法尋找附近轉乘。';

  @override
  String get transferEmpty => '這個站牌附近暫時沒有可顯示的轉乘方式。';

  @override
  String get transferTitle => '附近轉乘';

  @override
  String transferWalkingRanges(String stopName) {
    return '$stopName\n步行 250 公尺內的公車與 300 公尺內的 YouBike';
  }

  @override
  String transferRouteCount(String distance, int count) {
    return '$distance・$count 條路線';
  }

  @override
  String transferBikeAvailability(int rent, int returns) {
    return '可借 $rent・可還 $returns';
  }

  @override
  String transferBikeAvailabilityDistance(
    String distance,
    int rent,
    int returns,
  ) {
    return '$distance・可借 $rent・可還 $returns';
  }

  @override
  String get routeDetailTitle => '公車資訊';

  @override
  String get routeDetailStatusRefreshing => '正在更新';

  @override
  String get routeDetailStatusLoadingRoute => '正在載入路線資料';

  @override
  String get routeDetailStatusLoadingRealtime => '正在載入即時到站資訊';

  @override
  String get routeDetailStatusRealtimeUnavailable => '即時資訊暫時無法取得';

  @override
  String get routeDetailStatusLoadFailed => '讀取失敗';

  @override
  String get routeDetailStatusLoadingFamily => '正在載入同路線班次';

  @override
  String get routeDetailCancelledToday => '今日取消發車資訊';

  @override
  String routeDetailDirectionHeading(String direction) {
    return '$direction：';
  }

  @override
  String get routeDetailOperationsNotice => '營運通知';

  @override
  String get routeDetailViewRoutePresence => '查看路線';

  @override
  String get routeDetailBackgroundPromptTitle => '啓用背景乘車提醒？';

  @override
  String get routeDetailBackgroundPromptMessage =>
      'YABus 可以在你把 app 丟到背景後繼續追蹤這條路線，並在接近目的地下車前提醒你。';

  @override
  String get routeDetailBackgroundNotificationPermission =>
      '背景乘車提醒需要通知權限，否則提醒可能不會跳出。';

  @override
  String get routeDetailOppoPromptTitle => '提示';

  @override
  String get routeDetailOppoPromptMessage =>
      '你的系統可能支援流體雲功能，但你需要在 YABus 的通知設定裡啓用它。';

  @override
  String get routeDetailSamsungPromptTitle => 'Samsung Now Bar 顯示設定';

  @override
  String get routeDetailSamsungPromptMessage =>
      '如果背景乘車資訊沒有出現在 Now Bar，請啓用 Samsung 的即時通知測試選項。';

  @override
  String get routeDetailSamsungDeveloperSteps =>
      '尚未啓用開發人員選項：\n設定 → 關於手機 → 軟體資訊 → 連點「版本號碼」7 次';

  @override
  String get routeDetailSamsungLiveSteps =>
      '接著前往：\n設定 → 開發人員選項 → 捲到最底部 → More settings → Live notifications for all apps';

  @override
  String get routeDetailOpenSettingsFailed => '無法開啓系統設定，請依照提示中的路徑手動前往。';

  @override
  String get routeDetailTripPaused => '已暫時停止背景乘車提醒';

  @override
  String get routeDetailTripResumed => '已恢復背景乘車提醒';

  @override
  String get routeDetailLocationServiceRequired => '要使用背景乘車提醒，請先開啓定位服務。';

  @override
  String get routeDetailLocationPermissionRequired => '要使用背景乘車提醒，必須先允許定位權限。';

  @override
  String get routeDetailNotificationPermissionRequired =>
      '要使用乘車到站提醒，必須先允許通知權限。';

  @override
  String get routeDetailBackgroundLocationFallback =>
      '未啓用「一律允許」定位，背景乘車提醒會改用最後一次定位與公車到站資訊繼續運作。';

  @override
  String get routeDetailBackgroundLocationTitle => '允許背景定位';

  @override
  String get routeDetailBackgroundLocationIos =>
      '要在把 app 丟到背景後持續更新下車提醒和靈動島，iPhone 需要將定位權限設為「永遠」。';

  @override
  String get routeDetailBackgroundLocationAndroid =>
      '要在把 app 丟到背景後繼續提醒，Android 需要將定位權限設為「永遠允許」。';

  @override
  String get routeDetailAlwaysLocationTitle => '要把定位權限改為一律允許嗎？';

  @override
  String get routeDetailAlwaysLocationMessage =>
      'YABus 需要一律允許才可以在背景偵測你是否上車或到站。';

  @override
  String get routeDetailEnableAction => '去開啓';

  @override
  String get routeDetailDestinationPromptTitle => '要設定下車提醒嗎？';

  @override
  String get routeDetailDestinationPromptMessage =>
      '選一個你要下車的站牌，YABus 會在快到站時提醒你。';

  @override
  String get routeDetailSetBoardingStop => '設定上車站';

  @override
  String get routeDetailChangeBoardingStop => '變更上車站';

  @override
  String get routeDetailSetDestinationAlert => '設定下車提醒';

  @override
  String get routeDetailBlockedDestination => '這個站已設為下車站';

  @override
  String get routeDetailBlockedBoarding => '這個站已設為上車站';

  @override
  String get routeDetailSameBoardingDestination => '上車站不能同時設為下車站。';

  @override
  String routeDetailBoardingStopSet(String stopName) {
    return '已將 $stopName 設為上車站。';
  }

  @override
  String routeDetailDestinationSet(String stopName) {
    return '已將 $stopName 設為下車提醒。';
  }

  @override
  String get routeDetailManualBoardingCleared => '已清除手動上車站，之後拿到定位會再自動判斷。';

  @override
  String get routeDetailUsingCurrentLocation => '已改回使用目前位置判斷上車站。';

  @override
  String get routeDetailTripActive => '背景乘車提醒進行中';

  @override
  String get routeDetailBusApproaching => '公車即將進站';

  @override
  String routeDetailBusStopsAway(int count) {
    return '公車還有 $count 站';
  }

  @override
  String routeDetailNearestStopValue(String stopName) {
    return '最近站牌 $stopName';
  }

  @override
  String get routeDetailNotBoarded => '尚未上車';

  @override
  String routeDetailBoardingStopValue(String stopName) {
    return '上車站 $stopName';
  }

  @override
  String routeDetailDestinationValue(String stopName) {
    return '目的地 $stopName';
  }

  @override
  String get routeDetailWaitingForLocation => '等待目前位置';

  @override
  String get routeDetailLocating => '定位中';

  @override
  String get routeDetailWaitingToBoard => '等待上車';

  @override
  String get routeDetailNearestStop => '最近站牌';

  @override
  String get routeDetailDestinationNotSet => '尚未設定下車站';

  @override
  String get routeDetailBoarded => '已上車';

  @override
  String get routeDetailEtaNotDeparted => '未發車';

  @override
  String get routeDetailEtaLastBusPassed => '末班已過';

  @override
  String routeDetailEtaApproxMinutesSeconds(int minutes, int seconds) {
    return '約 $minutes 分 $seconds 秒';
  }

  @override
  String routeDetailEtaApproxMinutes(int minutes) {
    return '約 $minutes 分鐘';
  }

  @override
  String get routeDetailFavoriteStop => '收藏此站牌';

  @override
  String get routeDetailFavoriteStation => '收藏整站';

  @override
  String get routeDetailFavoriteGroupDuplicate => '已有相同名稱的收藏群組。';

  @override
  String routeDetailFavoriteLimit(int count) {
    return '我的最愛已達上限 $count 項，無法再加入';
  }

  @override
  String routeDetailRouteAdded(String group) {
    return '已將路線加入 $group';
  }

  @override
  String get routeDetailStationIdMissing => '這個站牌缺少可解析的識別碼，無法對應到整站。';

  @override
  String get routeDetailStationNotSynced => '伺服器還沒同步這一站的整站資料。';

  @override
  String routeDetailStationAdded(String station, String group) {
    return '已將$station加入 $group';
  }

  @override
  String routeDetailFavoriteAdded(String group) {
    return '已加入 $group';
  }

  @override
  String routeDetailFavoriteAddedWithDestination(
    String group,
    String destination,
  ) {
    return '已加入 $group，目的地：$destination';
  }

  @override
  String get routeDetailFavoriteDestinationTitle => '設定最愛目的地？';

  @override
  String get routeDetailFavoriteDestinationMessage =>
      '下次從最愛或小工具開啓時，會自動幫你套用下車提醒。';

  @override
  String get routeDetailNoSelectableStops => '這個方向目前沒有可選擇的站牌。';

  @override
  String get routeDetailShortcutRequested => '已送出主畫面捷徑要求。';

  @override
  String get routeDetailRouteShortcutRequested => '已送出路線捷徑要求。';

  @override
  String get routeDetailDestinationCleared => '已清除下車提醒。';

  @override
  String get routeDetailGoogleMapsFailed => '無法開啓 Google Maps。';

  @override
  String get routeDetailRealtimeLoading => '讀取即時資料中…';

  @override
  String get routeDetailNoRealtime => '無即時資料';

  @override
  String get routeDetailSelectFavoriteGroup => '選擇最愛群組';

  @override
  String get routeDetailNewGroup => '新增群組';

  @override
  String get routeDetailForumFailed => '無法開啓 TWBusforum。';

  @override
  String get routeDetailBackgroundDrawerTitle => '背景乘車提醒';

  @override
  String get routeDetailBackgroundDrawerMessage => '把背景追蹤與下車提醒控制集中在這裡。';

  @override
  String get routeDetailPauseBackground => '暫時停止背景乘車提醒';

  @override
  String get routeDetailResumeBackground => '恢復背景乘車提醒';

  @override
  String get routeDetailPauseBackgroundMessage => '保留設定，但先停止背景追蹤與提醒。';

  @override
  String get routeDetailResumeBackgroundMessage => '重新開始背景追蹤與提醒。';

  @override
  String routeDetailCurrentStop(String stopName) {
    return '目前站點：$stopName';
  }

  @override
  String get routeDetailBoardingStopHint => '沒定位時也可以手動選一個站牌當上車站。';

  @override
  String get routeDetailDestinationHint => '選擇一個站牌作為下車提醒。';

  @override
  String get routeDetailClearManualBoarding => '清除手動上車站';

  @override
  String get routeDetailReturnToCurrentLocation => '改回目前位置';

  @override
  String get routeDetailClearManualBoardingHint => '先保留背景提醒，之後拿到定位再自動判斷上車站。';

  @override
  String get routeDetailCurrentLocationHint => '重新跟著目前最近的站牌自動判斷上車站。';

  @override
  String get routeDetailClearDestinationAlert => '清除下車提醒';

  @override
  String get routeDetailVehicleBackfill => '回灌補點';

  @override
  String get routeDetailVehicleRealtime => '即時定位';

  @override
  String get routeDetailVehicleSource => '來源';

  @override
  String get routeDetailVehicleEta => '本站 ETA';

  @override
  String get routeDetailVehicleNotes => '備註';

  @override
  String get routeDetailVehicleCondition => '車況';

  @override
  String get routeDetailVehicleFull => '客滿';

  @override
  String get routeDetailVehicleAtStop => '目前在站';

  @override
  String get routeDetailVehicleType => '車型';

  @override
  String get routeDetailVehicleElectric => '電動公車';

  @override
  String get routeDetailVehicleEquipment => '設備';

  @override
  String get routeDetailVehicleAccessible => '低地板 / 無障礙';

  @override
  String get routeDetailViewOnMap => '在地圖中查看';

  @override
  String get routeDetailSearchForum => '搜尋 TWBusforum';

  @override
  String get routeDetailVehicleElectricShort => '電動車';

  @override
  String get routeDetailVehicleAccessibleShort => '無障礙';

  @override
  String get routeDetailVehicleFullShort => '滿載';

  @override
  String get routeDetailDestinationStop => '下車站';

  @override
  String get routeDetailNoDirectionsTitle => '這條路線還沒有方向資料';

  @override
  String get routeDetailNoDirectionsMessage => '貓貓翻不到去程或返程，稍後再試試看。';

  @override
  String get routeDetailNoStopsTitle => '這個方向沒有站牌';

  @override
  String get routeDetailNoStopsMessage => '可能是資料還沒同步完成，等一下再更新。';

  @override
  String get routeDetailNoMapData => '目前沒有可顯示的地圖資料';

  @override
  String get routeDetailRouteNotice => '路線公告';

  @override
  String get routeDetailNoticeUpdate => '目前有營運資訊更新';

  @override
  String get routeDetailCancelledDepartures => '今日取消發車';

  @override
  String routeDetailAdditionalNotices(String message, int count) {
    return '$message（另有 $count 則）';
  }

  @override
  String get routeDetailErrorTitle => '公車資訊被貓貓壓住了';

  @override
  String get routeDetailErrorMessage => '目前無法載入公車資訊，稍後再更新一次。';

  @override
  String get routeDetailHideMap => '隱藏地圖';

  @override
  String get routeDetailShowMap => '顯示地圖';

  @override
  String get routeDetailJumpToNearestStop => '跳到最近站牌';

  @override
  String get routeDetailScheduleTooltip => '同路線時刻表';

  @override
  String get routeInfoActions => '路線動作';

  @override
  String get routeInfoFavoriteRoute => '收藏路線';

  @override
  String routeInfoLoadFailed(String error) {
    return '載入失敗：$error';
  }

  @override
  String get routeInfoOperators => '營運業者';

  @override
  String get routeInfoFamilySchedule => '同路線時刻表';

  @override
  String get routeInfoRelatedRoutes => '相關路線';

  @override
  String get routeInfoShareLink => '分享連結';

  @override
  String get routeInfoLinkCopied => '已複製連結';

  @override
  String routeInfoPhone(String phone) {
    return '電話：$phone';
  }

  @override
  String routeInfoWebsite(String url) {
    return '網站：$url';
  }

  @override
  String get scheduleWeekdayMon => '一';

  @override
  String get scheduleWeekdayTue => '二';

  @override
  String get scheduleWeekdayWed => '三';

  @override
  String get scheduleWeekdayThu => '四';

  @override
  String get scheduleWeekdayFri => '五';

  @override
  String get scheduleWeekdaySat => '六';

  @override
  String get scheduleWeekdaySun => '日';

  @override
  String scheduleDateLabel(int month, int day, String weekday) {
    return '$month/$day（$weekday）';
  }

  @override
  String scheduleHolidayDateLabel(int month, int day, String weekday) {
    return '$month/$day（$weekday・假日）';
  }

  @override
  String get scheduleChooseDate => '選擇日期';

  @override
  String get scheduleNoServiceDay => '這天沒有發車資訊';

  @override
  String get scheduleUnavailable => '目前沒有時刻表資料';

  @override
  String get scheduleNoDepartureTimes => '無發車時間資料';

  @override
  String stopScheduleSubtitle(String routeName) {
    return '$routeName・預計時刻';
  }

  @override
  String get stopScheduleDisclaimer => '依時刻表推算，實際以現場為準';

  @override
  String get stopScheduleNoTimetable => '這條路線沒有時刻表資料';

  @override
  String get stopScheduleNoStopTimes => '這個站點在當天沒有對應的發車時刻';

  @override
  String get stopScheduleFrequency => '行駛班距';

  @override
  String get stopScheduleEstimatedArrival => '預計到站時間';

  @override
  String get stopScheduleIncludesEstimates => '含推算';

  @override
  String get stopScheduleEstimateFootnote => '※ 標示「含推算」的時間由班距與行駛時間推算，僅供參考';

  @override
  String get relatedRoutesLoadFailed => '載入站牌經過路線時發生錯誤';

  @override
  String relatedRoutesEmpty(String stopName) {
    return '找不到「$stopName」的路線';
  }

  @override
  String get relatedRoutesTitle => '站牌經過路線';

  @override
  String get stopActionSetDestination => '設為下車提醒';

  @override
  String get stopActionSchedule => '本站發車/到站時刻';

  @override
  String get stopActionRelatedRoutes => '站牌經過路線';

  @override
  String get stopActionTransfers => '附近轉乘方式';

  @override
  String get stopActionOpenGoogleMaps => '在 Google Maps 開啓';

  @override
  String get linkOpenFailed => '無法開啓連結。';

  @override
  String get announcementsSyncFailed => '公告同步失敗';

  @override
  String get announcementsEmpty => '目前沒有公告。';

  @override
  String get announcementNotFound => '找不到這則公告。';

  @override
  String get announcementResync => '重新同步公告';

  @override
  String get announcementEmbeddedContent => '嵌入內容';

  @override
  String get announcementSound => '提示音';

  @override
  String get announcementReaction => '反應';

  @override
  String get announcementAddReaction => '新增表情符號反應';

  @override
  String get announcementFirstReaction => '成為第一個反應的人';

  @override
  String get announcementReactionUpdateFailed => '無法更新反應，請稍後再試。';

  @override
  String get announcementReactionSignInRequired => '請先登入才能新增反應';

  @override
  String get legalDocumentUpdateFailed => '文件更新失敗';

  @override
  String get legalDocumentReload => '重新載入文件';

  @override
  String get accountSignIn => '登入';

  @override
  String get accountSignInDescription => '登入來備份你的最愛站牌與設定！';

  @override
  String get accountLoginPageOpenFailed => '無法開啓登入頁面。';

  @override
  String accountLoginFailed(String error) {
    return '登入失敗：$error';
  }

  @override
  String get accountLinkPageOpenFailed => '無法開啓連結頁面。';

  @override
  String accountLinkFailed(String error) {
    return '連結失敗：$error';
  }

  @override
  String accountRefreshFailed(String error) {
    return '重新整理帳號失敗：$error';
  }

  @override
  String get accountAutoSyncEnabled => '已開啓自動同步。';

  @override
  String get accountAutoSyncDisabled => '已關閉自動同步。';

  @override
  String accountSyncSettingsFailed(String error) {
    return '更新同步設定失敗：$error';
  }

  @override
  String get accountRouteHistoryPromptTitle => '同步路線紀錄？';

  @override
  String get accountRouteHistoryPromptDescription =>
      '開啓後，最近搜尋的路線與智慧推薦使用紀錄會上傳至你的帳號，讓其他裝置也能使用。這不包含定位資料，且可隨時關閉並移除本裝置上傳的紀錄。';

  @override
  String get accountEnableSync => '開啓同步';

  @override
  String get accountRouteHistoryEnabled => '已開啓路線紀錄同步。';

  @override
  String get accountRouteHistoryDisabled => '已關閉路線紀錄同步。';

  @override
  String accountRouteHistoryUpdateFailed(String error) {
    return '更新路線紀錄同步失敗：$error';
  }

  @override
  String get accountSyncComplete => '同步完成。';

  @override
  String accountSyncFailed(String error) {
    return '同步失敗：$error';
  }

  @override
  String get accountSyncConflictTitle => '同步發生衝突';

  @override
  String accountSyncConflictFallback(String namespace) {
    return '$namespace同步時發生衝突。';
  }

  @override
  String get accountSyncNamespaceFavorites => '最愛站牌與分類';

  @override
  String get accountSyncNamespacePreferences => '偏好設定';

  @override
  String get accountUseCloud => '使用雲端';

  @override
  String get accountTryMerge => '嘗試合併';

  @override
  String get accountOverwriteCloud => '覆蓋雲端';

  @override
  String accountSyncConflictFailed(String error) {
    return '處理同步衝突失敗：$error';
  }

  @override
  String get accountLoggedOut => '已登出。';

  @override
  String get accountLogout => '登出';

  @override
  String get accountSignedIn => '已登入';

  @override
  String get accountDefaultDisplayName => 'Ciallo～(∠・ω< )⌒☆';

  @override
  String get accountContinueDescription => '使用 Discord 或 Google 繼續以建立或連結你的帳戶。';

  @override
  String get accountLoadedFromCurrentToken => '從目前的登入令牌載入';

  @override
  String get accountNoLinkedProviders => '尚未載入任何連結的提供者詳細資訊。';

  @override
  String accountLinkProvider(String provider) {
    return '連結 $provider';
  }

  @override
  String get accountCloudSync => '雲端同步';

  @override
  String get accountEnableCloudSync => '啓用雲端同步';

  @override
  String accountLastSync(String date) {
    return '最後同步時間：$date';
  }

  @override
  String get accountSyncDisabled => '同步已關閉。';

  @override
  String get accountSyncRouteHistory => '同步路線紀錄';

  @override
  String get accountRouteHistoryDeletionPending => '已關閉，正在移除本裝置的雲端路線紀錄。';

  @override
  String get accountRouteHistorySyncDescription => '最近搜尋與智慧推薦使用紀錄會同步；不包含定位資料。';

  @override
  String get accountRouteHistoryWaitingForCloudSync => '已允許同步，開啓雲端同步後才會上傳。';

  @override
  String get accountRouteHistoryOptional => '選擇性功能，預設關閉。';

  @override
  String get accountSyncNow => '立即同步';

  @override
  String accountContinueWithProvider(String provider) {
    return '使用 $provider 繼續';
  }

  @override
  String get accountNeverSynced => '尚未同步';

  @override
  String get feedbackSubmitted => '意見回饋已送出，感謝你幫助我們改進。';

  @override
  String get feedbackSessionExpired => '登入已失效，請重新登入後再送出。';

  @override
  String get feedbackSignInRequired => '請先登入';

  @override
  String get feedbackGoToSignIn => '前往登入';

  @override
  String get feedbackSubjectLabel => '標題';

  @override
  String get feedbackSubjectHint => '例如：收藏站牌同步失敗';

  @override
  String get feedbackSubjectRequired => '請輸入標題';

  @override
  String feedbackSubjectTooLong(int max) {
    return '標題最多 $max 個字';
  }

  @override
  String get feedbackContentLabel => '內容';

  @override
  String get feedbackContentHint => '描述發生了什麼、你原本預期看到什麼，以及重現步驟。';

  @override
  String get feedbackContentRequired => '請輸入內容';

  @override
  String feedbackContentTooLong(int max) {
    return '內文最多 $max 個字';
  }

  @override
  String get feedbackSubmitting => '送出中…';

  @override
  String get feedbackSubmit => '送出回饋';

  @override
  String get feedbackInvalidFormat => '送出資料格式不正確。';

  @override
  String get feedbackSubmitFailed => '意見回饋送出失敗，請稍後再試。';

  @override
  String get databaseUpToDate => '目前資料庫已是最新版本。';

  @override
  String databaseUpdateAvailable(String provider, int version) {
    return '$provider 有新版本 $version';
  }

  @override
  String databaseCheckFailed(String error) {
    return '檢查資料庫更新失敗：$error';
  }

  @override
  String get databaseNoUpdatesAvailable => '目前沒有可更新的資料庫。';

  @override
  String databaseDownloadFailed(String error) {
    return '下載資料庫失敗：$error';
  }

  @override
  String get databaseStartupUpdateTitle => '啓動時更新';

  @override
  String get databaseAutoUpdateModeLabel => '自動更新模式';

  @override
  String get databaseAutoUpdateOffDescription => '啓動時不主動檢查資料庫更新。';

  @override
  String get databaseAutoUpdatePopupDescription => '啓動時檢查更新，若有新版本就彈出提示。';

  @override
  String get databaseAutoUpdateNotifyDescription => '啓動時檢查更新，若有新版本就顯示提示。';

  @override
  String get databaseAutoUpdateAlwaysDescription => '啓動時有新版本就直接下載並更新。';

  @override
  String get databaseAutoUpdateWifiDescription => '僅在 Wi-Fi 連線時自動更新，其他網路只保留提示。';

  @override
  String get databaseAutoUpdateCellularDescription =>
      '僅在行動數據連線時自動更新，其他網路只保留提示。';

  @override
  String databaseRegionVersion(String provider, int version) {
    return '$provider v$version';
  }

  @override
  String get databaseCheckNow => '立即檢查更新';

  @override
  String get databaseAllUpdatesDownloaded => '已更新所有有新版本的資料庫。';

  @override
  String get databaseDownloadUpdates => '更新可用更新';

  @override
  String get databaseRouteDatabaseTitle => '路線資料庫';

  @override
  String get databaseDownloaded => '已下載';

  @override
  String get databaseNotDownloadedYet => '尚未下載';

  @override
  String get databaseDataSourceTitle => '資料來源';

  @override
  String get databaseDefaultRegionLabel => '預設顯示地區';

  @override
  String get databaseSelectLocalRegions => '選取要保留在本機的縣市資料庫。';

  @override
  String get databaseSelectedRegionsDownloaded => '已下載選取地區的資料庫。';

  @override
  String get databaseDownloadSelectedRegions => '下載已選地區資料庫';

  @override
  String get databaseDiscordPresenceSection => 'Discord Rich Presence';

  @override
  String get databaseDiscordPresenceTitle => '啓用 Discord Rich Presence';

  @override
  String get databaseDiscordPresenceDescription =>
      '分享你正在看的公車給朋友 (⁠ ⁠/⁠^⁠ω⁠^⁠)⁠/⁠⁠';

  @override
  String get databasePresenceCurrentPage => '目前頁面';

  @override
  String get databasePresenceRegion => '地區';

  @override
  String get databasePresenceRouteName => '路線名稱';

  @override
  String databaseVersionAvailable(int version) {
    return '可更新 v$version';
  }

  @override
  String get databaseNotDownloaded => '未下載';

  @override
  String get databaseLocalVersionNotDownloaded => '本機版本：未下載';

  @override
  String databaseLocalVersion(int version) {
    return '本機版本：$version';
  }

  @override
  String databaseRegionUpdated(String provider) {
    return '$provider資料庫已更新。';
  }

  @override
  String get databaseRedownload => '重新下載';

  @override
  String databaseRegionDeleted(String provider) {
    return '$provider資料庫已刪除。';
  }

  @override
  String databaseDeleteFailed(String error) {
    return '刪除資料庫失敗：$error';
  }

  @override
  String get regionKeelung => '基隆市';

  @override
  String get regionTaipei => '台北市';

  @override
  String get regionNewTaipei => '新北市';

  @override
  String get regionIntercity => '公路客運';

  @override
  String get regionTaoyuan => '桃園市';

  @override
  String get regionHsinchuCity => '新竹市';

  @override
  String get regionHsinchuCounty => '新竹縣';

  @override
  String get regionMiaoli => '苗栗縣';

  @override
  String get regionTaichung => '台中市';

  @override
  String get regionChanghua => '彰化縣';

  @override
  String get regionNantou => '南投縣';

  @override
  String get regionYunlin => '雲林縣';

  @override
  String get regionChiayiCity => '嘉義市';

  @override
  String get regionChiayiCounty => '嘉義縣';

  @override
  String get regionTainan => '台南市';

  @override
  String get regionKaohsiung => '高雄市';

  @override
  String get regionPingtung => '屏東縣';

  @override
  String get regionYilan => '宜蘭縣';

  @override
  String get regionHualien => '花蓮縣';

  @override
  String get regionTaitung => '台東縣';

  @override
  String get regionPenghu => '澎湖縣';

  @override
  String get regionKinmen => '金門縣';

  @override
  String get regionLienchiang => '連江縣';

  @override
  String get personalizationColorScheme => '配色';

  @override
  String get personalizationDarkMode => '深色模式';

  @override
  String get personalizationAmoledTitle => '純黑 (AMOLED) 深色主題';

  @override
  String get personalizationAmoledDescription => '深色模式下使用純黑背景，可省電並提升對比';

  @override
  String get personalizationHomeGradient => '主頁漸層';

  @override
  String get personalizationHomeGradientDescription => '調整主頁漸層背景的透明度';

  @override
  String get personalizationGradientOpacity => '漸層透明度';

  @override
  String get personalizationBackgroundImage => '背景圖片';

  @override
  String get personalizationBackgroundImageDescription =>
      '設定各頁面的背景圖片，首頁背景會同時套用於公車、捷運、高鐵、台鐵、YouBike 等首頁分頁。';

  @override
  String get personalizationChooseImage => '選擇圖片';

  @override
  String get personalizationBackgroundOpacity => '背景透明度';

  @override
  String get personalizationPerPageSettings => '各頁面設定';

  @override
  String get personalizationPerPageDescription => '分別設定每個頁面的背景圖片';

  @override
  String get personalizationOverlayOpacityTitle => '覆蓋層透明度';

  @override
  String get personalizationOverlay => '覆蓋層';

  @override
  String get personalizationColorSystem => '系統';

  @override
  String get personalizationColorAutomaticBackground => '自動（背景圖片）';

  @override
  String get personalizationColorSourceDescription =>
      '「自動」會依背景圖片取色；「系統」會使用裝置的動態配色。';

  @override
  String get personalizationColorAutomatic => '自動';

  @override
  String get personalizationColorCustom => '自訂';

  @override
  String get personalizationChooseColor => '選擇顏色';

  @override
  String get personalizationHue => '色相';

  @override
  String get personalizationSaturation => '飽和';

  @override
  String get personalizationBrightness => '明度';

  @override
  String get personalizationPerPageBackgroundTitle => '各頁面背景設定';

  @override
  String get personalizationGlobalHomeDescription =>
      '同時套用於公車、捷運、高鐵、台鐵、YouBike 首頁';

  @override
  String get personalizationPageGlobalHome => '全域首頁';

  @override
  String get personalizationPageSearch => '搜尋';

  @override
  String get personalizationPageNearby => '附近';

  @override
  String get personalizationPreviewAmoled => 'AMOLED 純黑';

  @override
  String get personalizationAppearancePreview => '外觀預覽';

  @override
  String get personalizationPreviewSearchDescription => '快速查詢即時到站資訊';

  @override
  String get personalizationPreviewFavoritesDescription => '常用站牌與群組';

  @override
  String get personalizationReplaceImage => '更換';

  @override
  String get personalizationRemoveImage => '移除';

  @override
  String get announcementDismissForever => '不再顯示';

  @override
  String get announcementViewDetails => '查看公告';

  @override
  String get databaseUpdatesDialogTitle => '資料庫有新版本';

  @override
  String get databaseUpdatesDialogDescription => '已檢查到以下地區有資料庫更新：';

  @override
  String databaseVersion(int version) {
    return '版本 $version';
  }

  @override
  String get databaseUpdateNow => '立即更新';

  @override
  String get accountProviderDiscord => 'Discord';

  @override
  String get accountProviderGoogle => 'Google';

  @override
  String get accountProviderOAuth => 'OAuth';

  @override
  String get personalizationPreviewAppName => 'YABus';

  @override
  String get personalizationGifBadge => 'GIF';

  @override
  String announcementReactionCount(String emoji, int count) {
    return '$emoji $count';
  }

  @override
  String get weatherTitle => '天氣';

  @override
  String temperatureCelsius(int temperature) {
    return '$temperature°C';
  }

  @override
  String temperatureDegrees(int temperature) {
    return '$temperature°';
  }

  @override
  String get weatherHourly => '逐時';

  @override
  String get weatherWeekly => '一週';

  @override
  String weatherHighLow(int high, int low) {
    return '最高 $high° · 最低 $low°';
  }

  @override
  String get weatherFeelsLike => '體感';

  @override
  String get weatherHumidity => '濕度';

  @override
  String get weatherWindSpeed => '風速';

  @override
  String get weatherPrecipitation => '降雨';

  @override
  String get weatherNow => '現在';

  @override
  String weatherHour(int hour) {
    return '$hour時';
  }

  @override
  String get weatherSunrise => '日出';

  @override
  String get weatherSunset => '日落';

  @override
  String weatherSourceUpdated(String time) {
    return '資料來源：中央氣象署 · 更新於 $time';
  }

  @override
  String get weatherLocationUnavailable => '無法取得目前位置，因此無法顯示天氣。請確認定位服務與定位權限已開啟。';

  @override
  String get weatherLoadFailed => '無法載入天氣資料，請稍後再試。';

  @override
  String get weatherToday => '今天';

  @override
  String get weatherTomorrow => '明天';

  @override
  String weatherWeekday(String weekday) {
    return '週$weekday';
  }

  @override
  String weatherCurrentSemantics(String condition, int temperature) {
    return '目前天氣 $condition，$temperature 度';
  }

  @override
  String weatherViewTooltip(String condition) {
    return '$condition · 查看天氣';
  }

  @override
  String get youBikeLocationUnavailable => '目前無法取得定位，請稍後再試。';

  @override
  String youBikeUsingDefaultArea(String message) {
    return '$message 已改為顯示預設區域。';
  }

  @override
  String get youBikeNearbyStations => '附近站點';

  @override
  String youBikeStationCount(int count) {
    return '$count 站';
  }

  @override
  String get youBikeNoNearbyStations => '附近沒有站點';

  @override
  String get youBikeGeneralBike => '一般車';

  @override
  String get youBikeElectricBike => '2.0E 電輔';

  @override
  String get youBikeReturnSlots => '可還';

  @override
  String youBikeDistance(String distance) {
    return '距離 $distance';
  }

  @override
  String get youBikeStationInfo => '站點資訊';

  @override
  String get youBikeSelectStationHint => '按一下左側站點或地圖上的標記後，這裡就會顯示可借、可還與距離資訊。';

  @override
  String get youBikeLocationAcquired => '已取得目前位置';

  @override
  String get youBikeRelocate => '重新定位';

  @override
  String get youBikeBackToLocation => '回到目前位置';

  @override
  String youBikeAvailability(int general, int electric, int returns) {
    return '一般 $general · 2.0E $electric · 可還 $returns';
  }

  @override
  String get metroSystem => '捷運系統';

  @override
  String get metroNoLineSelected => '尚未選擇路線';

  @override
  String get metroUpdateEta => '更新 ETA';

  @override
  String get metroNoLines => '這個捷運系統目前沒有可用路線。';

  @override
  String get metroTimetableEstimate => '目前改用時刻表推估到站。';

  @override
  String get metroFrequencyOnly => '目前只有班距資訊。';

  @override
  String metroFrequencyEstimate(int min, int max) {
    return '目前以班距估算，約 $min-$max 分鐘。';
  }

  @override
  String get metroEtaUnknown => '目前 ETA 來源未標示。';

  @override
  String get metroLiveArrivals => '即時到站';

  @override
  String get metroStationMap => '站點地圖';

  @override
  String get metroChooseLine => '先選一條捷運路線。';

  @override
  String get metroNoStationSequence => '這條路線目前沒有站序資料。';

  @override
  String get metroRouteMap => '路線地圖';

  @override
  String get metroViewEta => '看 ETA';

  @override
  String get metroNoCoordinates => '這條捷運路線目前沒有可用站點座標。';

  @override
  String get metroTravelDirection => '行駛方向';

  @override
  String metroDirectionHeading(String destination) {
    return '往 $destination';
  }

  @override
  String metroHeadway(int min, int max) {
    return '班距 $min-$max 分';
  }

  @override
  String get metroNoLiveArrivals => '這個車站目前沒有可顯示的即時班次。';

  @override
  String metroFrequencyOnlyEstimate(int min, int max) {
    return '目前僅提供班距估算，約 $min-$max 分鐘。';
  }

  @override
  String metroDestination(String destination) {
    return '往 $destination';
  }

  @override
  String get railOperatingNotices => '營運公告';

  @override
  String get railAllStations => '全部車站';

  @override
  String get railOtherStations => '其他';

  @override
  String railShowDeparted(int count) {
    return '顯示已開出的 $count 班';
  }

  @override
  String railHideDeparted(int count) {
    return '收合已開出的 $count 班';
  }

  @override
  String get railPickerNoMatches => '找不到符合的車站';

  @override
  String get railPickerNoNearby => '找不到附近的車站。';

  @override
  String railPickerNearest(String station, String distance) {
    return '最近的車站：$station（約 $distance）';
  }

  @override
  String get railLocationUnavailable => '目前無法取得定位，請稍後再試。';

  @override
  String get railPickerSearchHint => '搜尋車站名稱或代碼';

  @override
  String get railUseCurrentLocation => '使用目前位置';

  @override
  String get railChooseStation => '選擇車站';

  @override
  String railChooseNamedStation(String station) {
    return '選擇 $station';
  }

  @override
  String get railSameStationExcluded => '這一站已經是另一端的車站';

  @override
  String get railOrigin => '出發站';

  @override
  String get railDestination => '到達站';

  @override
  String get railChooseOrigin => '選擇出發站';

  @override
  String get railChooseDestination => '選擇到達站';

  @override
  String get railSwapStations => '對調出發站與到達站';

  @override
  String get railDeparted => '已開出';

  @override
  String railDelayedMinutes(int minutes) {
    return '晚 $minutes 分';
  }

  @override
  String get railOnTime => '準點';

  @override
  String railDepartsAt(String time) {
    return '$time 發車';
  }

  @override
  String railMinutesUntilDeparture(int minutes) {
    return '$minutes 分後';
  }

  @override
  String railDurationHoursMinutes(int hours, int minutes) {
    return '$hours 小時 $minutes 分';
  }

  @override
  String railDurationMinutes(int minutes) {
    return '$minutes 分';
  }

  @override
  String railTrainSemantics(String trainNo, String trainType, String headline) {
    return '$trainNo 次 $trainType，$headline';
  }

  @override
  String railTrainSemanticsWithStatus(
    String trainNo,
    String trainType,
    String headline,
    String status,
  ) {
    return '$trainNo 次 $trainType，$headline，$status';
  }

  @override
  String railRouteWithTimes(
    String origin,
    String departure,
    String destination,
    String arrival,
  ) {
    return '$origin $departure → $destination $arrival';
  }

  @override
  String railStationRange(String origin, String destination) {
    return '$origin → $destination';
  }

  @override
  String railTimeRange(String departure, String arrival) {
    return '$departure → $arrival';
  }

  @override
  String get traServices => '班次';

  @override
  String get traStationMap => '車站地圖';

  @override
  String get traSelectDifferentStations => '出發站和到達站不能一樣。';

  @override
  String get traUseLocationOrigin => '用目前位置選出發站';

  @override
  String get traSelectionPrompt => '選好出發站和到達站，就會顯示今天還搭得到的班次。';

  @override
  String get traSearching => '查詢中…';

  @override
  String get traNoDirectServices => '這兩站之間今天沒有直達班次，可能需要轉車。';

  @override
  String traRemainingServices(int count) {
    return '還有 $count 班可搭';
  }

  @override
  String traAllServicesDeparted(String origin, String destination) {
    return '今天從 $origin 到 $destination 的班次都開完了。';
  }

  @override
  String get traViewTomorrow => '看明天的班次';

  @override
  String get traViewServices => '看班次';

  @override
  String get traMapHint => '點站牌可設為出發站或到達站，點紅色列車標記看估算中的列車位置。';

  @override
  String get traMapNoCoordinates => '台鐵站點目前沒有可用座標。';

  @override
  String get traSetOrigin => '設為出發站';

  @override
  String get traSetDestination => '設為到達站';

  @override
  String traPositionArrived(String station) {
    return '已到 $station';
  }

  @override
  String traPositionStopped(String station) {
    return '停靠 $station';
  }

  @override
  String get traTrainPositionEstimate => '列車位置估算';

  @override
  String traEstimatedBetween(String current, String next) {
    return '目前估算在 $current 與 $next 之間';
  }

  @override
  String traEstimatedArrived(String station) {
    return '目前估算已到達 $station';
  }

  @override
  String traEstimatedStopped(String station) {
    return '目前估算停靠在 $station';
  }

  @override
  String traSegmentProgress(int percent) {
    return '路段進度 $percent%';
  }

  @override
  String traDataUpdated(String time) {
    return '資料更新 $time';
  }

  @override
  String get thsrSeatOverview => '座位即時概況';

  @override
  String get thsrObservedStation => '觀察車站';

  @override
  String get thsrChooseStation => '選擇車站';

  @override
  String get thsrSelectStationForSeats => '先選一個車站，再看最近幾班高鐵的座位狀況。';

  @override
  String thsrNoStationSeats(String station) {
    return '目前沒有 $station 的座位即時資料。';
  }

  @override
  String get thsrSearchServices => '查詢班次';

  @override
  String get thsrNotSearched => '尚未查詢班次';

  @override
  String thsrServicesSummary(int upcoming, int total) {
    return '還有 $upcoming 班可搭（共 $total 班）';
  }

  @override
  String get thsrQueryPrompt => '選好起訖站與日期後，就能看高鐵班次。';

  @override
  String get thsrDayDeparted => '這一天的班次都開完了。';

  @override
  String get thsrSeatTitle => '自由座與商務車座位';

  @override
  String get thsrQueryStation => '查詢站點';

  @override
  String get thsrSelectStationSeats => '先選一個站，再看各班次座位餘量。';

  @override
  String get thsrNoSeatData => '目前沒有可顯示的座位資料。';

  @override
  String get thsrMapTitle => '站點地圖';

  @override
  String get thsrViewSeats => '看座位';

  @override
  String get thsrMapNoCoordinates => '高鐵站點目前沒有可用座標。';

  @override
  String get thsrTimetable => '班次查詢';

  @override
  String get thsrSeats => '座位資訊';

  @override
  String get thsrTrainLabel => '高鐵';

  @override
  String thsrNoSeatField(String station) {
    return '這班車目前沒有 $station 的座位欄位。';
  }

  @override
  String get thsrStandardCar => '標準車';

  @override
  String get thsrBusinessCar => '商務車';

  @override
  String get thsrNotProvided => '未提供';

  @override
  String get thsrStationNoSeats => '這個站目前沒有可顯示的座位資料。';

  @override
  String thsrDepartureTime(String time) {
    return '$time 發車';
  }
}
