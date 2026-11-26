#!/usr/bin/env bash
# Called by android-emulator-runner after boot. The model's tools do NOT run as
# the passwordless-sudo Actions user. Android SDK and CLI are installed globally.
set -euo pipefail
if [[ -f $HOME/.emulator_console_auth_token ]]; then
  sudo install -m 600 -o yabus-agent "$HOME/.emulator_console_auth_token" /home/yabus-agent/.emulator_console_auth_token
fi
cd /opt/yabus-session
sudo --preserve-env=ANDROID_HOME,ANDROID_SERIAL,PERSONA,DEVICE,FONT_SCALE,THEME,LOCALE,GEO,BRIEF,MAX_ACTIONS,RECORD_VIDEO,LLM_API_KEY,LLM_BASE_URL,LLM_MODEL \
  -H -u yabus-agent env PATH="/opt/yabus-cli/bin:$ANDROID_HOME/platform-tools:/usr/bin:/bin:/usr/local/bin" \
  bash scripts/android/run_agent.sh
