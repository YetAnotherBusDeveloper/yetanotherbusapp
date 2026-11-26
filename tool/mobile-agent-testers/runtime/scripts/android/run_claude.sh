# shellcheck shell=bash
# Adapted from mobile-agent-testers/scripts/android/run_agent.sh (MIT).
# Caller owns device setup, a fresh results/$PERSONA, and final AGENT_TMP cleanup.
run_claude() (
  set +x
  exec 3>&- # never let CLI/tools write to the runner's saved public log descriptor
  umask 077
  source scripts/llm_env.sh || return 1
  [[ ${AGENT_TMP:-} == /* && -d $AGENT_TMP && ! -L $AGENT_TMP &&
     ${PERSONA:-} =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ &&
     ${MAX_ACTIONS:-} =~ ^([1-9]|[1-3][0-9]|40)$ && -n ${APP_ID:-} &&
     -d results/$PERSONA && ! -L results && ! -L results/$PERSONA ]] || return 1
  local private rc=0 out="results/$PERSONA" cli adb python path prompt
  private=$(mktemp -d -- "$AGENT_TMP/claude.XXXXXXXX") || return 1
  trap 'rm -rf -- "$private"' EXIT
  mkdir -m 700 -- "$private/home" "$private/tmp" || return 1
  # Resolve only the trusted, installed executables' directories. Never copy
  # the entire runner PATH, the caller's HOME, or any Actions environment files.
  cli=$(type -P claude) || return 127
  adb=$(type -P adb) || return 127
  python=$(type -P python3) || return 127
  [[ $cli == /* && $adb == /* && $python == /* ]] || return 1
  path="${cli%/*}:${adb%/*}:${python%/*}:/usr/local/bin:/usr/bin:/bin"
  local -a context=("PATH=$path" "HOME=$private/home" "TMPDIR=$private/tmp" LANG=C.UTF-8
                    SHELL=/bin/bash "PERSONA=$PERSONA" PYTHONDONTWRITEBYTECODE=1
                    "MAX_ACTIONS=$MAX_ACTIONS" "APP_ID=$APP_ID" "LAUNCH_COMPONENT=${LAUNCH_COMPONENT:?}"
                    "BRIEF=$BRIEF" "AGENT_STATE_DIR=$AGENT_TMP")
  [[ -z ${ANDROID_HOME:-} ]] || context+=("ANDROID_HOME=$ANDROID_HOME")
  [[ -z ${ANDROID_SERIAL:-} ]] || context+=("ANDROID_SERIAL=$ANDROID_SERIAL")

  prompt="Read AGENT_BRIEF.md, $BRIEF and your entry in personas.json. PERSONA=$PERSONA PLATFORM=android APP_ID=$APP_ID. Device: $DEVICE, font scale $FONT_SCALE, theme $THEME, language $LOCALE. MAX_ACTIONS=$MAX_ACTIONS is a hard budget on UI actions, not screenshots or report writing. Use only python3 scripts/android/action.py for actions; never use adb directly. Start with python3 scripts/android/screen.py $out 01, then capture and Read each numbered PNG after every action. Write $out/report.md and $out/findings.json before finishing. For each issue include nonempty steps (array of reproduction-step strings) and screens (array of existing two-digit screenshot numbers without .png). Report untested or blocked scenarios honestly."
  # One UI action + its screen.py + its image Read can each take a turn.
  # 12 additional turns cover opening the brief/persona, initial view and report.
  local turns=$((3 * MAX_ACTIONS + 12))
  # Claude checks the Write tool against Edit(path), NOT Write(path). The
  # --tools list still excludes the Edit tool and all other file mutators.
  local -a allow=("Bash(python3 scripts/android/action.py *)" "Bash(python3 scripts/android/screen.py $out *)"
                  "Read(/AGENT_BRIEF.md)" "Read(/briefs/yabus.md)" "Read(/$BRIEF)" "Read(/personas.json)" "Read(/$out/*.png)"
                  "Read(/$out/report.md)" "Read(/$out/findings.json)"
                  "Edit(/$out/report.md)" "Edit(/$out/findings.json)")
  # env -i is the allowlist, not a blacklist of today's known provider/GitHub
  # variables. A Bash builtin writes secrets to stdin without exposing them in
  # ps. The launcher consumes all three fields and closes stdin before exec.
  env -i "${context[@]}" /bin/bash --noprofile --norc scripts/llm_env.sh \
      -p "$prompt" --max-turns "$turns" --output-format json --permission-mode dontAsk \
      --restricted --setting-sources '' --settings '{"disableAllHooks":true}' --disable-slash-commands \
      --strict-mcp-config --no-session-persistence --tools 'Bash,Read,Write' \
      --allowedTools "${allow[@]}" \
      < <(printf '%s\0' "$LLM_BASE_URL" "$LLM_API_KEY" "$LLM_MODEL") \
      >"$private/result.json" 2>"$private/stderr" || rc=$?
  # CLI exit wins, even if stdout looks successful or status parsing fails.
  local status=0
  "$python" -I scripts/agent_status.py "$private/result.json" "$private/stderr" "$rc" "$AGENT_TMP/agent-status" || status=$?
  (( rc == 0 )) || return "$rc"
  # The parent runs check_results.py once after recording has stopped.
  return "$status"
)
