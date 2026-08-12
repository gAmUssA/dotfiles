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

# Default: gemma4:26b. Changed 2026-08-11 from qwen2.5-coder:7b on the compile-
# and-run bench (bench-results/m1-max-64gb.md), which grades by actually
# building and executing the output rather than eyeballing it:
#
#   qwen2.5-coder:7b   1/3   49.2 tok/s   fails Kotlin AND Swift
#   gemma4:26b         3/3   58.2 tok/s
#
# It wins on quality and throughput at once. Latency is a wash despite the size
# — 26B total but ~4B active per token (MoE), so kotlin 4.5s vs 4.3s and swift
# 5.0s vs 4.6s. Only Java is slower (16s vs 6.9s). Costs 17 GB resident instead
# of 4.7 GB, which is nothing on 64 GB.
#
# gemma4:12b is the small-footprint alternative: also 3/3, but half the
# throughput (27.8 tok/s) and roughly double the latency.
#
# NOT the right pick for agentic work — that bench is one-shot only and cannot
# see tool use, where Gemma 4 is reported weak. OpenCode/Pi keep
# qwen3-coder:30b-ctx64k.
#
# Override by passing any installed model as the first arg.
MODEL="${1:-gemma4:26b}"

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
