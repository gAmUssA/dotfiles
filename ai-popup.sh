#!/usr/bin/env bash
#
# ai-popup.sh <model>
#
# Opens or reattaches a persistent ollama scratch session in a tmux popup.
# Each model gets its own session keyed by model name, so conversation
# history is preserved per-model across invocations.
#
# When ollama exits (`/bye` or Ctrl-D), the conversation pane is captured
# and copied to the macOS clipboard via pbcopy — so you can immediately
# paste the thread into Slack, a doc, or another Claude session. Disable
# by setting AI_POPUP_CLIPBOARD=0.
#
# Invoked from the `prefix + a` display-menu in .tmux.conf.

set -u

MODEL="${1:-gemma3:4b}"

# tmux session names can't contain `:`, `/`, or `.`; mangle for the model→name
# map. (claude-dev.sh hits the same restriction with project paths.)
SESSION="ollama-$(echo "$MODEL" | tr ':/.' '___')"

# Daemon health check — Ollama.app GUI usually keeps it running, but fail
# loudly if it's not so the popup doesn't open onto a dead `ollama run`.
if ! curl -fsS --max-time 2 http://localhost:11434/api/version >/dev/null 2>&1; then
  tmux display-message -d 4000 "ollama daemon unreachable — open Ollama.app or run: ollama serve"
  exit 1
fi

# Build the session command: ollama run + optional clipboard capture chain.
# The capture step runs INSIDE the session's pane after ollama exits, so
# capture-pane sees the conversation text before the session is torn down.
# If we tried to capture from the parent script after display-popup returns,
# the session would already be dead (ollama was the session's only command).
CMD="ollama run $MODEL"
if [[ "${AI_POPUP_CLIPBOARD:-1}" == "1" ]] && command -v pbcopy >/dev/null 2>&1; then
  CMD="$CMD; tmux capture-pane -p -S -5000 | pbcopy && tmux display-message -d 2000 'chat copied to clipboard'"
fi

# Spawn detached if first invocation for this model
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -c "$HOME" "$CMD"
fi

# Attach the persistent session inside a popup
tmux display-popup -w 90% -h 90% -E "tmux attach-session -t $SESSION"
