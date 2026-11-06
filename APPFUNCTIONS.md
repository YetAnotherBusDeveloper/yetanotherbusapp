# Android assistant integration

YABus exposes device-local favorites through Jetpack AppFunctions (Android MCP).
This complements the busapiserver remote MCP: Android reads this phone's saved
favorites, while remote ChatGPT/Claude/Gemini connections read cloud-synced data.

## Functions

| Function | Behavior |
| --- | --- |
| `listFavoriteGroups` | List local group names, including unsynced changes |
| `listFavorites` | Paginated route, station and boarding favorites, with opaque IDs |
| `openFavorite` | Return an immutable PendingIntent opening the saved destination |
| `openFavoriteGroup` | Return an immutable PendingIntent opening its arrival board |

The functions reuse the same favorite parser as the Android home-screen widget and
the existing Flutter launch bridge. Legacy boarding favorites and current v2
favorites are both supported. Opening a boarding favorite preserves the direction,
boarding stop and saved destination. Local account tokens are never returned.
Only the Android system can bind the generated service using
`android.permission.BIND_APP_FUNCTION_SERVICE`. Assistants need the OS's execution
permission and authorization. The app does not grant this permission to itself.

These are read-only queries and user-visible open actions. They do not start an
Activity in the background or automatically edit favorites. The saved list does
not contain arrival predictions: the open action leads to the existing live board.

## Build and compatibility

* Flutter **3.44.0** or newer compatible stable release; CI pins 3.44.0.
* Android Gradle Plugin **9.1.0**, Gradle **9.3.1**, compile SDK **37**.
* JDK **21** for the Android 16 Robolectric tests; Java/Kotlin bytecode still targets 17.
* Kotlin **2.2.20**, KSP **2.2.20-2.0.4**, Jetpack AppFunctions **1.0.0-rc01**.
* `google_mobile_ads` **9.2.0** replaces 5.x, whose Gradle script uses configuration
  APIs removed in Gradle 9. The existing banner and initialization APIs are retained.
* Keep `android.builtInKotlin=false` and `android.newDsl=false` while Flutter plugins
  use the legacy Kotlin/AGP DSL. The application's minimum Android version is unchanged.
  The root build applies Kotlin explicitly to the pinned Firebase Analytics plugin,
  which otherwise skips it on AGP 9 even when built-in Kotlin is disabled.
* AppFunctions execution requires Android 16+ and compatible system support. The
  generated service is only loaded when the system invokes it on a supported OS.

KSP generates `YabusAppFunctionService` and `assets/yabus_app_functions.xml`.
The manifest references the generated schema and `yabus_app_metadata.xml` supplies
assistant instructions. Verify both generated assets are present in a built APK.

```powershell
flutter pub get
flutter build apk --debug
python scripts/verify_appfunctions_apk.py build/app/outputs/flutter-apk/app-debug.apk
cd android
./gradlew.bat :app:testDebugUnitTest --tests '*YabusAppFunctionsTest'
```

The Robolectric tests check device-local reads, v1/v2 decoding, pagination,
group-sensitive IDs, removed favorites, input validation, and destination intents.
They do not establish access to the Gemini app's preview program.

## Device and Gemini verification

After installing on an Android 16+ test device, inspect the OS command syntax and
registered functions:

```text
adb shell cmd app_function help
adb shell cmd app_function list-app-functions
```

Use the exact generated function IDs from that output with the device's
`execute-app-function` command. First invoke `listFavoriteGroups`, then
`listFavorites` with a real group. Test both after editing favorites and after
restarting the process. Present an `openFavorite` PendingIntent and verify that
the expected direction and destination open in Flutter.

Google currently restricts end-to-end Gemini AppFunctions access through its
early access program. Implementing/indexing the functions does not automatically
make the app available to every Gemini account. Enrollment and public release
remain platform steps, independent of this PR.

References: [AppFunctions overview](https://developer.android.com/ai/appfunctions),
[integration](https://developer.android.com/ai/appfunctions/add-appfunctions),
[releases](https://developer.android.com/jetpack/androidx/releases/appfunctions),
[Flutter AGP compatibility](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers).
