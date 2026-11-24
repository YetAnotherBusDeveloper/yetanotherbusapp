#!/usr/bin/env bash
# Adapted from pierridotite/mobile-agent-testers, scripts/android/run_agent.sh
# (MIT, Copyright (c) 2026 Pierre Raffalli). Run from the staged runtime root.
set +x
set -euo pipefail
umask 077

stage=preflight
AGENT_TMP=''
recording_started=false
finish() {
  local code=$?
  trap - EXIT INT TERM HUP
  set +e
  if [[ $recording_started == true ]]; then stop_recording >/dev/null 2>&1; fi
  # Never print provider text, even if the diagnostic file is malformed.
  if [[ $stage == agent && -f $AGENT_TMP/agent-status ]]; then
    local label=''
    IFS= read -r -n 32 label < "$AGENT_TMP/agent-status"
    case "$label" in
      auth|quota|rate_limit|overloaded|max_turns|cli_error|invalid_response) stage="agent: $label" ;;
    esac
  fi
  if [[ -n $AGENT_TMP ]]; then rm -rf -- "$AGENT_TMP"; fi
  if (( code != 0 )); then printf 'Android agent failed (%s, exit %d).\n' "$stage" "$code" >&2; fi
  exit "$code"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# Do not pipe the agent through tee or print any output from the device or CLI.
# Stage labels below are constants, not provider-, app- or model-supplied text.
source scripts/llm_env.sh >/dev/null 2>&1 || exit $?
python3 -B scripts/android/check_inputs.py >/dev/null 2>&1 || exit $?
python3 -B -c 'from PIL import Image' >/dev/null 2>&1 || exit $?
for cmd in adb claude; do command -v "$cmd" >/dev/null; done
AGENT_TMP=$(mktemp -d)
source scripts/android/device.sh
source scripts/android/run_claude.sh
# Reject leftovers (including a dangling symlink) rather than passing on stale evidence.
[[ ! -L results ]]
mkdir -p results
mkdir -- "results/$PERSONA" 2>/dev/null

stage=device-setup
prepare_device >/dev/null 2>&1 || exit $?
printf 'Android APK installed, digest verified and launcher activity started.\n'
stage=recording
recording_started=true
start_recording >/dev/null 2>&1 || exit $?
stage=agent
printf 'Starting Android UI tester.\n'
run_claude >/dev/null 2>&1 || exit $?
stage=recording
stop_recording >/dev/null 2>&1 || exit $?
recording_started=false
stage=evidence
# Each attempted UI command consumes one byte in the controller's ledger. An
# initial observation and at least one subsequent screen per action are required.
actions=0
if [[ -f $AGENT_TMP/ui-actions ]]; then actions=$(stat -c %s "$AGENT_TMP/ui-actions"); fi
python3 -B scripts/android/check_results.py "$PERSONA" "$((actions + 1))" >/dev/null 2>&1 || exit $?
printf 'Android agent completed (%d UI actions); evidence validated.\n' "$actions"
