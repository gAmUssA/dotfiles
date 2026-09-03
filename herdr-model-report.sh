#!/bin/sh
# herdr-model-report.sh <claude|codex|copilot>
#
# Report the session's model to herdr as a $model metadata token, shown in the
# agent sidebar (ui.sidebar.agents.rows in herdr/config.toml). Registered as a
# SessionStart-style hook in each agent's own config:
#   claude:  claude/settings.json      (SessionStart + Stop; transcript_path on stdin)
#   codex:   ~/.codex/hooks.json       (SessionStart; transcript_path on stdin)
#   copilot: ~/.copilot/settings.json  (SessionStart; session_id on stdin)
#
# Claude's transcript lacks a model until the first assistant turn, so its
# SessionStart pass often finds nothing — the Stop hook covers it and also
# catches /model switches. Codex writes the model on rollout line 1 and
# copilot emits session.model_change immediately, but both files can lag the
# hook by a moment, so those two retry briefly in a detached background job.
set -eu

agent="${1:-claude}"

[ "${HERDR_ENV:-}" = 1 ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
command -v herdr >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat 2>/dev/null || true)
[ -n "$input" ] || exit 0

case "$agent" in
  claude|codex)
    file=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null) || exit 0
    ;;
  copilot)
    sid=$(printf '%s' "$input" | jq -r '.session_id // .sessionId // empty' 2>/dev/null) || exit 0
    [ -n "$sid" ] || exit 0
    file="$HOME/.copilot/session-state/$sid/events.jsonl"
    ;;
  *) exit 0 ;;
esac
[ -n "$file" ] || exit 0

extract_model() {
  case "$agent" in
    claude)
      tail -100 "$file" | jq -rs '[.[] | .message?.model? // empty] | last // empty'
      ;;
    codex)
      # Prefer the latest turn_context (tracks mid-session switches); fall back
      # to the session_meta provenance stamped on rollout line 1.
      m=$(tail -300 "$file" | jq -rs '[.[] | select(.type == "turn_context") | .payload.model // empty] | last // empty')
      [ -n "$m" ] || m=$(head -1 "$file" | jq -r '.payload.base_instructions.provenance.model // empty')
      printf '%s' "$m"
      ;;
    copilot)
      tail -200 "$file" | jq -rs '[.[] | .data?.newModel? // .data?.model? // empty] | last // empty'
      ;;
  esac
}

if [ "$agent" = "claude" ]; then tries=1; else tries=10; fi

(
  i=0
  while [ "$i" -lt "$tries" ]; do
    i=$((i + 1))
    if [ -f "$file" ]; then
      model=$(extract_model 2>/dev/null) || model=""
      if [ -n "$model" ]; then
        herdr pane report-metadata "$HERDR_PANE_ID" \
          --source custom:model-report \
          --token model="${model#claude-}" >/dev/null 2>&1 || true
        exit 0
      fi
    fi
    [ "$i" -lt "$tries" ] && sleep 2
  done
) </dev/null >/dev/null 2>&1 &

exit 0
