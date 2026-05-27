#!/usr/bin/env bash
# Ollama benchmark — multi-prompt suite, per-model timings + full responses.
#
# Each model is unloaded first, so prompt #1 (CANARY) measures a TRUE COLD
# start (worst case = first popup invocation after restart). Prompts #2-5 run
# warm against the now-loaded model, so their LOAD is ~0 and their TOK/S
# reflects steady-state generation speed.
#
# Prompts cover the dimensions that matter for a quick shell/coding popup:
#   1 CANARY      — trivial one-liner; the cold-start latency canary
#   2 PIPELINE    — multi-step shell reasoning (still one-shot)
#   3 CODEGEN     — small stdlib code task; exposes tiny-model quality limits
#   4 DEBUG       — find+fix a classic bug; closest to a real scratch session
#   5 PORTABILITY — BSD-vs-GNU trap; macOS-correctness as a scored dimension
#
# Metrics per prompt: LOAD, TTFT, TOK/S, TOTAL (seconds). Full responses are
# printed so you can judge answer quality, not just speed.
#
# `think:false` is sent so reasoning models (qwen3.x, deepseek-r1) emit an
# answer instead of burning the token budget inside a <think> block.
#
# Usage: ./ollama-bench.sh
# Requires: ollama daemon running (curl http://localhost:11434/api/version)

# --- Prompt suite (parallel arrays; macOS ships bash 3.2, no assoc arrays) ---
labels=(
  "1 CANARY"
  "2 PIPELINE"
  "3 CODEGEN"
  "4 DEBUG"
  "5 PORTABILITY"
)
prompts=(
  'One-line bash command to find the 5 largest files recursively in the current directory and print their sizes. Output ONLY the command — no explanation, no markdown fences, no preamble.'
  'Single macOS-compatible shell command (BSD userland, no GNU coreutils) that lists every file under the current directory larger than 10MB, newest first, with human-readable sizes. Output ONLY the command.'
  'Write a Python function get_with_retry(url) that performs an HTTP GET and retries up to 5 times with exponential backoff, using only the standard library. Output only the code, no explanation.'
  $'This bash loop breaks on filenames with spaces:\n\n  for f in $(ls *.txt); do echo "$f"; done\n\nExplain the bug in one sentence, then give a corrected version.'
  'Give a single command that works on macOS (BSD userland, NOT GNU coreutils) to print the size in bytes of the file /etc/hosts. Output ONLY the command.'
)

# Per-prompt token budget. CANARY/PORTABILITY are one-liners; the rest need room.
num_predicts=(96 128 384 256 96)

# Chat-capable models suitable for a quick shell/coding popup.
models=(
  "gemma3:4b"
  "qwen2.5-coder:7b"
  "mistral:7b"
  "qwen3-coder:30b"
)

unload() {
  curl -s http://localhost:11434/api/generate \
    -d "{\"model\":\"$1\",\"keep_alive\":0}" >/dev/null 2>&1
}

for m in "${models[@]}"; do
  unload "$m"                       # guarantee a cold start for prompt #1
  printf '\n########## %s ##########\n' "$m"

  for i in "${!prompts[@]}"; do
    np="${num_predicts[$i]}"
    resp=$(timeout 200 curl -s --max-time 190 http://localhost:11434/api/generate -d "$(jq -n \
      --arg model "$m" --arg prompt "${prompts[$i]}" --argjson np "$np" \
      '{model:$model, prompt:$prompt, stream:false, think:false,
        options:{num_predict:$np, temperature:0.2}}')")

    if [[ -z "$resp" ]] || ! echo "$resp" | jq -e '.eval_count' >/dev/null 2>&1; then
      printf '\n[%s]  (timeout or error)\n' "${labels[$i]}"
      continue
    fi

    load_ns=$(echo "$resp" | jq -r '.load_duration // 0')
    prompt_ns=$(echo "$resp" | jq -r '.prompt_eval_duration // 0')
    eval_ns=$(echo "$resp" | jq -r '.eval_duration // 0')
    eval_count=$(echo "$resp" | jq -r '.eval_count // 0')
    total_ns=$(echo "$resp" | jq -r '.total_duration // 0')
    text=$(echo "$resp" | jq -r '.response' | sed -e 's/[[:space:]]*$//' -e '/./,$!d')

    stats=$(awk -v l="$load_ns" -v p="$prompt_ns" -v e="$eval_ns" \
                -v c="$eval_count" -v t="$total_ns" 'BEGIN{
      printf "load %.2fs  ttft %.2fs  %s tok/s  total %.2fs",
        l/1e9, (l+p)/1e9, (e==0 ? "N/A" : sprintf("%.1f", c*1e9/e)), t/1e9 }')

    printf '\n[%s]  %s\n%s\n' "${labels[$i]}" "$stats" "$text"
  done

  unload "$m"                       # free memory before the next model
done
