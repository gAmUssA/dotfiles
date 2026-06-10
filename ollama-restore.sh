#!/usr/bin/env bash
# ollama-restore.sh — recreate this machine's Ollama model set on a new box.
#
# Two parts, because `ollama pull` can't restore everything:
#   1. Registry models — pulled by tag, with a retry loop (the registry
#      throttles and DNS hiccups kill long pulls; resume-from-partial makes
#      retries cheap).
#   2. Local variants — models we created with `ollama create` (the -ctx64k
#      builds). These exist only on this machine, so they're recreated from
#      their Modelfile recipe here. A variant shares blobs with its base, so
#      it costs zero extra disk.
#
# Idempotent: already-installed models are skipped. Safe to re-run.
# To refresh the list after adding/removing models, edit `registry_models`
# below (source of truth: `ollama list`).
#
# Usage: ./ollama-restore.sh
# Requires: ollama daemon running.

set -uo pipefail

# Source of truth: `ollama list` on the primary machine (2026-06-10).
# Roles (see ollama-bench.sh + ollama-code-bench.sh for the receipts):
#   qwen2.5-coder:7b   — tmux popup default (best speed/quality balance)
#   mistral:7b         — popup: fastest, terse
#   gemma3:4b          — popup: fast general chat
#   qwen3-coder:30b    — popup second choice + base for the agentic variant
#   qwen3.6:27b        — best local code quality (3/3 on the coding bench)
#   devstral:24b       — 3/3 on coding bench, smallest of the big three
#   mxbai-embed-large  — embeddings
registry_models=(
  "qwen2.5-coder:7b"
  "mistral:7b"
  "gemma3:4b"
  "qwen3-coder:30b"
  "qwen3.6:27b"
  "devstral:24b"
  "mxbai-embed-large:latest"
)

installed() { ollama list 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "$1"; }

pull_retry() {
  local m="$1" tries=8
  for ((i=1; i<=tries; i++)); do
    ollama pull "$m" && return 0
    echo "  pull failed (attempt $i/$tries), retrying in 15s — resumes from partial" >&2
    sleep 15
  done
  echo "  GAVE UP on $m after $tries attempts" >&2
  return 1
}

echo "=== registry models ==="
for m in "${registry_models[@]}"; do
  if installed "$m"; then echo "[skip] $m (already installed)"; continue; fi
  echo "[pull] $m"
  pull_retry "$m"
done

# --- local variants (ollama create; share blobs with their base) ------------
# qwen3-coder:30b-ctx64k — the OpenCode/Pi agentic driver. Ollama defaults to
# 4096 ctx which truncates agent system prompts; this bakes in 64k.
echo
echo "=== local variants ==="
if installed "qwen3-coder:30b-ctx64k"; then
  echo "[skip] qwen3-coder:30b-ctx64k (already installed)"
else
  echo "[create] qwen3-coder:30b-ctx64k"
  tmpfile="$(mktemp /tmp/Modelfile.XXXXXX)"
  printf 'FROM qwen3-coder:30b\nPARAMETER num_ctx 65536\n' > "$tmpfile"
  ollama create qwen3-coder:30b-ctx64k -f "$tmpfile"
  rm -f "$tmpfile"
fi

echo
echo "Done. Current models:"
ollama list
