#!/usr/bin/env bash
# gemma4-quant-sweep.sh — pull + code-benchmark each quant of the gemma-4 coder
# GGUF, sequentially, logging clean per-quant results to bench-out/gemma4-sweep.log
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="hf.co/yuxinlu1/gemma-4-12B-coder-fable5-composer2.5-v1-GGUF"
LOG="$HERE/bench-out/gemma4-sweep.log"
mkdir -p "$HERE/bench-out"
: > "$LOG"

quants=( Q2_K Q4_K_M Q6_K Q8_0 )

say() { echo "$@" | tee -a "$LOG"; }

say "=== gemma-4 coder quant sweep — $(date) ==="
for q in "${quants[@]}"; do
  tag="$REPO:$q"
  say ""
  say "######################## $q ($tag) ########################"

  if ollama list 2>/dev/null | grep -q "$REPO:$q"; then
    say "[$q] already present, skipping pull"
  else
    say "[$q] pulling..."
    if ! ollama pull "$tag" >>"$LOG" 2>&1; then
      say "[$q] PULL FAILED — skipping"
      continue
    fi
  fi

  # size on disk for context
  sz=$(ollama list 2>/dev/null | awk -v t="$REPO:$q" '$1==t{print $3" "$4}')
  say "[$q] size: ${sz:-?}"

  # run the single-model benchmark, tee to log
  "$HERE/ollama-code-bench-one.sh" "$tag" 2>&1 | tee -a "$LOG"
done

say ""
say "=== sweep complete — $(date) ==="
