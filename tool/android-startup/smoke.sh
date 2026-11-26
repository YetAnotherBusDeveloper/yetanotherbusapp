#!/usr/bin/env bash
set -euo pipefail

apk=$1
output=$2
install_mode=${3:-clean}
package=tw.avianjay.taiwanbus.flutter
activity="$package/.MainActivity"
mkdir -p "$output"
source tool/mobile-agent-testers/runtime/scripts/android/device.sh
_device_serial=$(timeout 10 adb get-serialno | tr -d '\r')
[[ $_device_serial =~ ^emulator-[0-9]+$ ]]
raw=$(mktemp -d "$RUNNER_TEMP/yabus-startup-raw.XXXXXXXX")
chmod 700 "$raw"
stage=clear-logs
pid=''

collect() {
    local status=$?
    trap - EXIT
    set +e
    # Read while the emulator is still up. Do not upload raw logs or UI XML.
    _device_adb 15 logcat -d -b crash -v threadtime > "$raw/crash.raw" 2>/dev/null
    _device_adb 15 logcat -d -b main -b system -v threadtime \
        AndroidRuntime:E DEBUG:F libc:F flutter:W Flutter:W ActivityTaskManager:I ActivityManager:I '*:S' > "$raw/startup.raw" 2>/dev/null
    _device_adb 15 shell dumpsys activity exit-info "$package" > "$raw/exits.raw" 2>/dev/null
    python3 - "$raw" "$output" "$package" "$pid" <<'PY'
import pathlib
import re
import sys

raw_dir, output = map(pathlib.Path, sys.argv[1:3])
package, pid = sys.argv[3:]
startup = raw_dir.joinpath("startup.raw").read_text(errors="replace")
pids = set(re.findall(r"Start proc (\d+):" + re.escape(package) + r"(?=[\s/:])", startup))
if pid:
    pids.add(pid)
record_pattern = re.compile(r"\S+\s+\S+\s+(\d+)\s+\d+\s+[A-Z]\s+(\S+)\s*:")
crash = raw_dir.joinpath("crash.raw").read_text(errors="replace").splitlines()
# Native tombstones are logged by crash_dump, not by the app's process.
crash_writers = {m[1] for line in crash if package in line and (m := record_pattern.match(line))}
for raw in sorted(raw_dir.glob("*.raw")):
    sanitized = []
    for line in raw.read_text(errors="replace").splitlines():
        if raw.stem in {"startup", "crash"}:
            record = record_pattern.match(line)
            if package not in line and (not record or record[1] not in pids | crash_writers):
                continue
        # Native register values are not needed to identify the crashing frame.
        if re.search(r"\b(?:[rx]\d{1,2}|sp|lr) +[0-9a-f]{8,} +(?:[rx]\d{1,2}|sp|lr) +[0-9a-f]{8,}", line):
            continue
        line = re.sub(r"https?://[^\s<>]+", "[redacted URL]", line)
        line = re.sub(r"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}", "[redacted email]", line)
        line = re.sub(r"(?i)(bearer\s+|(?:token|password|secret|api[_-]?key)\s*[:=]\s*)[^\s,;]+", r"\1[redacted]", line)
        line = re.sub(r"\b(?:AIza[\w-]+|gh[opurs]_[\w-]+|github_pat_[\w-]+)\b", "[redacted key]", line)
        sanitized.append(line)
    output.joinpath(raw.stem + ".txt").write_text("\n".join(sanitized) + "\n")
    raw.unlink()
PY
    local masked=$?
    if (( masked != 0 )); then status=1; fi
    printf 'stage=%s\nexit=%d\nredaction_exit=%d\n' "$stage" "$status" "$masked" > "$output/status.txt"
    if (( status != 0 )); then
        echo "::error::Startup check failed for $(basename "$output") at $stage. See the masked startup artifact."
    fi
    exit "$status"
}
trap collect EXIT

_device_adb 15 logcat -b main -b system -b crash -c
stage=install
if [[ "$install_mode" == upgrade ]]; then
    _device_adb 120 install -r "$apk" > "$raw/install.raw" 2>&1
else
    _device_adb 120 install "$apk" > "$raw/install.raw" 2>&1
fi
grep -Eq '^Success[[:space:]]*$' "$raw/install.raw"
stage=installed-apk
base=$(_device_value pm path "$package")
[[ $base =~ ^package:(/data/app/[a-zA-Z0-9~/._+=-]+/base\.apk)$ ]]
base=${BASH_REMATCH[1]}
read -r wanted _ < <(sha256sum "$apk")
read -r installed _ < <(_device_adb 60 shell sha256sum "$base")
[[ $wanted == "$installed" ]]

stage=launch
_device_adb 15 shell am force-stop "$package"
_device_adb 65 shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n "$activity" > "$raw/launch.raw" 2>&1
grep -Eq '^Status: (ok|timeout)[[:space:]]*$' "$raw/launch.raw"

has_app_window() { _device_launcher_drawn "$activity"; }
app_pid() { _device_value pidof -s "$package"; }
stage=process
pid=$(app_pid)
[[ $pid =~ ^[0-9]+$ ]]
stage=first-frame
for ((attempt = 0; attempt < 22; attempt++)); do
    [[ $(app_pid) == "$pid" ]] || exit 1
    if has_app_window; then break; fi
    sleep 2
done
has_app_window
# A Flutter semantics node confirms UI painted beyond the launch theme.
stage=ui-semantics
_device_adb 25 shell uiautomator dump /sdcard/yabus-window.xml >/dev/null
_device_adb 10 exec-out cat /sdcard/yabus-window.xml | python3 -c '
import sys
import xml.etree.ElementTree as ET

package = sys.argv[1]
nodes = ET.parse(sys.stdin).iter("node")
assert any(node.get("package") == package and
           (node.get("text") or node.get("content-desc")) for node in nodes), "No rendered app semantics"
' "$package"
stage=process-survival
deadline=$((SECONDS + 30))
while (( SECONDS < deadline )); do
    [[ $(app_pid) == "$pid" ]] || exit 1
    has_app_window
    sleep 2
done
[[ $(app_pid) == "$pid" ]]
has_app_window
stage=passed
echo 'App UI rendered and stayed in the foreground with the same process for 30 seconds.' | tee "$output/result.txt"
