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
    badging=$("$aapt" dump badging "$apk")
    signer=$("$apksigner" verify --print-certs "$apk" | sed -nE '/^(V[0-9.]+ )?Signer([[:space:]:]|$).*certificate SHA-256 digest: /s/.*: ([A-Fa-f0-9]{64})$/\1/p' | tr '[:upper:]' '[:lower:]' | sort -u)
    [[ $signer =~ ^[A-Fa-f0-9]{64}$ ]] || { echo "::error::No single verified signer for $label"; exit 1; }
    version=$(sed -nE "/^package: /s/.*versionCode='([0-9]+)'.*/\1/p" <<< "$badging")
    [[ $version =~ ^[0-9]+$ ]]
    printf '%s\n' "$signer" > "$output/signer.txt"
    printf '%s\n' "$version" > "$output/version.txt"
    {
        sha256sum "$apk" | cut -d' ' -f1
        sed -nE '/^(package:|sdkVersion:|targetSdkVersion:|native-code:)/p' <<< "$badging"
        printf 'Signer SHA-256: %s\n' "$signer"
    } | tee "$output/apk.txt"
    adb uninstall tw.avianjay.taiwanbus.flutter >/dev/null 2>&1 || true
    bash tool/android-startup/smoke.sh "$apk" "$output" || result=1
done
evidence="$RUNNER_TEMP/yabus-startup"
# This is a same-version signed replacement, not a versionCode increase.
# Do not force a downgrade from the published stable versionCode 23.
if cmp -s "$evidence/pre-115/signer.txt" "$evidence/nightly/signer.txt" &&
    (( $(<"$evidence/pre-115/version.txt") <= $(<"$evidence/nightly/version.txt") )); then
    adb uninstall tw.avianjay.taiwanbus.flutter >/dev/null 2>&1 || true
    if bash tool/android-startup/smoke.sh "$apk_dir/pre-115/app-release.apk" "$evidence/replace-baseline"; then
        bash tool/android-startup/smoke.sh "$apk_dir/nightly.apk" "$evidence/replace-nightly" upgrade || result=1
    else
        result=1
    fi
else
    echo 'Signed replacement skipped: incompatible signer or versionCode.' | tee "$evidence/nightly/replacement.txt"
    result=1
fi
exit "$result"
