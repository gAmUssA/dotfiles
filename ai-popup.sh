#!/usr/bin/env bash
#
# ai-popup.sh <model>
#
# Opens or reattaches a persistent ollama scratch session in a tmux popup.
# Each model gets its own session keyed by model name, so conversation
# history is preserved per-model across invocations.
#
# Invoked from the `prefix + a` display-menu in .tmux.conf.

set -u

MODEL="${1:-qwen2.5:7b}"

# tmux session names can't contain `:` or `/`; mangle for the model→name map
SESSION="ollama-$(echo "$MODEL" | tr ':/' '__')"

# Daemon health check — Ollama.app GUI usually keeps it running, but fail
# loudly if it's not so the popup doesn't open onto a dead `ollama run`.
if ! curl -fsS --max-time 2 http://localhost:11434/api/version >/dev/null 2>&1; then
  tmux display-message -d 4000 "ollama daemon unreachable — open Ollama.app or run: ollama serve"
  exit 1
fi

# Spawn detached if first invocation for this model
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -c "$HOME" "ollama run $MODEL"
fi

# Attach the persistent session inside a popup
tmux display-popup -w 90% -h 90% -E "tmux attach-session -t $SESSION"
