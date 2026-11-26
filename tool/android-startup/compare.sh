#!/usr/bin/env bash
set -euo pipefail

# Use the same framework restart/readiness checks as the Anna persona.
source tool/mobile-agent-testers/runtime/scripts/android/device.sh
_device_serial=$(timeout 10 adb get-serialno | tr -d '\r')
LOCALE=zh-TW
_device_booted
_device_locale
adb shell settings put system font_scale 1.3
adb shell input keyevent KEYCODE_WAKEUP
adb shell wm dismiss-keyguard
apk_dir="$RUNNER_TEMP/yabus-apks"
aapt=$(find "$ANDROID_HOME/build-tools" -type f -name aapt | sort -V | tail -n1)
apksigner="$(dirname "$aapt")/apksigner"
result=0
for label in stable pre-115 post-115 nightly; do
    case "$label" in
        stable|nightly) apk="$apk_dir/$label.apk" ;;
        *) apk="$apk_dir/$label/app-release.apk" ;;
    esac
    output="$RUNNER_TEMP/yabus-startup/$label"
    mkdir -p "$output"
    {
        sha256sum "$apk" | cut -d' ' -f1
        "$aapt" dump badging "$apk" | sed -nE '/^(package:|sdkVersion:|targetSdkVersion:|native-code:)/p'
        "$apksigner" verify --print-certs "$apk" | sed -nE '/^Signer #[0-9]+ certificate SHA-256 digest:/p'
    } | tee "$output/apk.txt"
    adb uninstall tw.avianjay.taiwanbus.flutter >/dev/null 2>&1 || true
    bash tool/android-startup/smoke.sh "$apk" "$output" || result=1
done
exit "$result"
