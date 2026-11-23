#!/usr/bin/env bash
# Sourced from run_agent.sh after check_inputs.py. Call directly in the same
# shell, without xtrace; suppress BOTH output streams (including diagnostics).
# Caller owns the fresh emulator, results/, private AGENT_TMP and the EXIT trap.
# Android setup/recording adapted from mobile-agent-testers (LICENSE.upstream).
_device_adb() { timeout -k 5 "$1" adb -s "$_device_serial" "${@:2}"; }
_device_value() { _device_adb 10 shell "$@" | tr -d '\r'; }

_device_booted() {
  local old_server=${1:-} server until_time=$((SECONDS + 90))
  while (( SECONDS < until_time )); do
    if server=$(_device_value pidof system_server) && [[ -n $server && $server != "$old_server" ]] &&
       [[ $(_device_value getprop sys.boot_completed) == 1 && $(_device_value pm path android) == package:* ]]; then return 0; fi
    sleep 1
  done
  return 1
}

_device_unroot() {
  if [[ $(_device_value id -u) == 2000 ]]; then return 0; fi
  _device_adb 20 unroot && _device_adb 30 wait-for-device && [[ $(_device_value id -u) == 2000 ]]
}

_device_locale() {
  local before changed=0
  if [[ $(_device_value getprop persist.sys.locale) == "$LOCALE" ]]; then _device_unroot; return; fi
  before=$(_device_value pidof system_server) && [[ -n $before ]] || return 1
  _device_adb 20 root || return 1
  if _device_adb 30 wait-for-device && [[ $(_device_value id -u) == 0 ]] &&
     _device_adb 10 shell setprop persist.sys.locale "$LOCALE" &&
     _device_adb 10 shell setprop ctl.restart zygote && _device_booted "$before" &&
     [[ $(_device_value getprop persist.sys.locale) == "$LOCALE" ]]; then changed=1; fi
  # Drop adb root before the agent, even on a pre-rooted emulator.
  _device_unroot && [[ $changed == 1 ]]
}

prepare_device() {
  local sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}} aapt pkg installed base digest local_digest launch activity geo font mode=no
  aapt=$(command -v aapt2) || aapt=$(printf '%s\n' "$sdk"/build-tools/*/aapt2 | sort -V | tail -n 1) || return 1
  pkg=$("$aapt" dump packagename app.apk | tr -d '\r') && [[ $pkg =~ ^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$ ]] || return 1
  local_digest=$(sha256sum < app.apk) || return 1
  timeout 60 adb wait-for-device || return 1
  _device_serial=$(timeout 10 adb get-serialno | tr -d '\r') && [[ $_device_serial =~ ^emulator-[0-9]+$ ]] || return 1
  _device_booted && _device_locale || return 1
  [[ $THEME != dark ]] || mode=yes
  _device_adb 15 shell settings put system font_scale "$FONT_SCALE" || return 1
  font=$(_device_value settings get system font_scale) && [[ $font =~ ^[0-9]+([.][0-9]+)?$ ]] &&
    awk -v got="$font" -v want="$FONT_SCALE" 'BEGIN {exit !(got+0 == want+0)}' || return 1
  _device_adb 15 shell cmd uimode night "$mode" && [[ $(_device_value cmd uimode night) == "Night mode: $mode" ]] || return 1
  geo=$(_device_adb 15 emu geo fix "${GEO#*,}" "${GEO%,*}" | tr -d '\r') && [[ $geo == OK ]] || return 1

  # Reject stale grants/data, then verify installed bytes, not just package presence.
  installed=$(_device_value pm list packages "$pkg") || return 1
  if grep -Fxq "package:$pkg" <<< "$installed"; then return 1; fi
  _device_adb 180 install app.apk || return 1
  base=$(_device_value pm path "$pkg") || return 1
  [[ $base =~ ^package:(/data/app/[a-zA-Z0-9~/._+=-]+/base\.apk)$ ]] || return 1
  digest=$(_device_adb 60 shell sha256sum "${BASH_REMATCH[1]}") && [[ ${digest%% *} == "${local_digest%% *}" ]] || return 1

  local -a launcher=(-a android.intent.action.MAIN -c android.intent.category.LAUNCHER)
  activity=$(_device_value cmd package resolve-activity --brief "${launcher[@]}" -p "$pkg") || return 1
  activity=${activity##*$'\n'}
  [[ $activity == "$pkg/"* && ${activity#*/} =~ ^[A-Za-z0-9_.]+$ ]] || return 1
  launch=$(_device_adb 60 shell am start -W "${launcher[@]}" -n "$activity" | tr -d '\r') || return 1
  grep -Fxq 'Status: ok' <<< "$launch" || return 1
  export APP_ID="$pkg" LAUNCH_COMPONENT="$activity"
}

# Pull one finalized segment at a time into private staging. Only our remote
# child sees the stop sentinel; never glob the device or kill other recorders.
_record_parts() {
  local i name
  for ((i=1; i<=40; i++)); do
    [[ ! -e $AGENT_TMP/stop ]] || break
    _device_adb 195 shell -T sh -s -- "$_rec_dir" < scripts/android/record_part.sh > "$AGENT_TMP/ready" || return 1
    printf -v name '%02d.mp4' "$i"
    _device_adb 60 pull "$_rec_dir/part.mp4" "$AGENT_TMP/part" && [[ -s $AGENT_TMP/part ]] &&
      mv -- "$AGENT_TMP/part" "$AGENT_TMP/video/$name" || return 1
  done
}

_rec_pid='' _rec_dir='' _rec_touches=''
start_recording() {
  local dir i prior
  [[ $RECORD_VIDEO == true ]] || return 0
  mkdir -- "$AGENT_TMP/video" || return 1
  dir=$(_device_value mktemp -d /data/local/tmp/yabus.XXXXXXXXXX) && [[ $dir =~ ^/data/local/tmp/yabus\.[a-zA-Z0-9]{10}$ ]] || return 1
  _rec_dir=$dir
  prior=$(_device_value settings get system show_touches) && [[ $prior =~ ^(null|0|1)$ ]] || return 1
  _rec_touches=$prior
  _device_adb 10 shell settings put system show_touches 1 || return 1
  _record_parts </dev/null >/dev/null 2>&1 & _rec_pid=$!
  for ((i=0; i<15; i++)); do
    grep -Fxq ready "$AGENT_TMP/ready" 2>/dev/null && return 0
    kill -0 "$_rec_pid" 2>/dev/null || return 1
    sleep 1
  done
  return 1
}

stop_recording() {
  local rc=0 out="results/$PERSONA"
  [[ -n $_rec_dir ]] || return 0
  if [[ -n $_rec_pid ]]; then
    touch "$AGENT_TMP/stop" || rc=1
    _device_adb 10 shell touch "$_rec_dir/stop" || rc=1
    wait "$_rec_pid" || rc=1
    _rec_pid=''
    [[ -s $AGENT_TMP/video/01.mp4 && ! -L results && -d $out && ! -L $out && ! -e $out/video && ! -L $out/video ]] &&
      mv -T -- "$AGENT_TMP/video" "$out/video" || rc=1
  fi
  if [[ $_rec_touches == null ]]; then _device_adb 10 shell settings delete system show_touches || rc=1
  elif [[ -n $_rec_touches ]]; then _device_adb 10 shell settings put system show_touches "$_rec_touches" || rc=1; fi
  _device_adb 10 shell rm -f "$_rec_dir/part.mp4" "$_rec_dir/stop" && _device_adb 10 shell rmdir "$_rec_dir" || rc=1
  _rec_dir='' _rec_touches=''
  return "$rc"
}
