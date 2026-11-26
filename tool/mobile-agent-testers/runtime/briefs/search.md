# YABus focus: does a stop search open the stop I chose?

Read `briefs/yabus.md` first. Its read-only rules, first-run choices, action cap, screenshot-after-each-action rule and **both** final report formats apply. Only the journey changes: spend the budget on one search-to-stop handoff instead of touring the app.

1. Keep 台北市 (Taipei). For the no-GPS path tap 授權並繼續, then **Don't allow** on the actual Android location dialog if offered. Note whether permission was denied, skipped or already set; don't reset it. Defer the database download and record existing download state. From 公車 → 搜尋路線, capture the initial route keypad/recent searches.
2. Tap 切換文字鍵盤 and enter `City Hall` in the focused field. If you can use the on-screen Chinese IME within budget, 市政府 is an alternative, not a required second query. Check the actual field text; wait for a settled result. The same box finds route names **and** routes serving matching stops. Select a row that identifies a **stop match**, not just a route-number hit. Capture its stop, route number, region and direction/destination as displayed.
3. Tap the row and capture the loaded route and indicated stop/direction. Could this rider tell which side to wait on and whether the ETA is live, loading or unavailable? A changing ETA alone is not a discrepancy. Go Back; note what query/results remain.
4. If the stop lookup was unavailable, record the exact empty, partial-results or error message, then try **one** route-keypad lookup (e.g. `307`) as a control. A route-only success doesn't verify stop search. If the handoff succeeded and actions remain, try `zzzznohit` then clear it; old matches should not masquerade as new ones. No more retries, DB installs or network changes.

In the coverage section, pair the actual result-list screenshot with the detail screenshot, or give the last reachable screen and why the handoff remains unverified. Report only what happened on this build.
