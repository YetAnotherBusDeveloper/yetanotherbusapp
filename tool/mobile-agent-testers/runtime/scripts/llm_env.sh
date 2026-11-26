#!/usr/bin/env bash
# CPA-only adaptation of mobile-agent-testers/scripts/llm_env.sh (MIT).
# Source from the staged runtime root for offline preflight. Executing under
# env -i reads the three settings over a private pipe, never via process argv.
set +x
if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  python3 -I scripts/cpa_config.py || return 1
  return 0
fi

# Never invoke this branch with an inherited CLI environment. run_claude passes
# only its context allowlist, not any login, provider, proxy or Actions settings.
IFS= read -r -d '' LLM_BASE_URL && IFS= read -r -d '' LLM_API_KEY && IFS= read -r -d '' LLM_MODEL || exit 1
exec </dev/null
export LLM_BASE_URL LLM_API_KEY LLM_MODEL
ANTHROPIC_BASE_URL=$(python3 -I scripts/cpa_config.py --sdk-base) || exit 1
export ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN="$LLM_API_KEY"
export ANTHROPIC_MODEL="$LLM_MODEL" ANTHROPIC_DEFAULT_MODEL="$LLM_MODEL"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$LLM_MODEL" ANTHROPIC_DEFAULT_SONNET_MODEL="$LLM_MODEL"
export ANTHROPIC_DEFAULT_OPUS_MODEL="$LLM_MODEL" ANTHROPIC_DEFAULT_FABLE_MODEL="$LLM_MODEL"
export ANTHROPIC_SMALL_FAST_MODEL="$LLM_MODEL" CLAUDE_CODE_SUBAGENT_MODEL="$LLM_MODEL"
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1
export CLAUDE_CODE_DISABLE_MODEL_ACCESS_FALLBACK=1 CLAUDE_CODE_DISABLE_REFUSAL_FALLBACK=1
# Only three builtin tools: no deferred tool lookup or nonstreaming replay.
export ENABLE_TOOL_SEARCH=false CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK=1
export CLAUDE_CODE_DISABLE_CLAUDE_MDS=1 CLAUDE_CODE_DISABLE_AUTO_MEMORY=1
unset LLM_BASE_URL LLM_API_KEY LLM_MODEL
exec claude "$@"
