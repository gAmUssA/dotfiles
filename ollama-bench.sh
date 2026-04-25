#!/usr/bin/env bash
# Ollama benchmark — single concrete prompt, per-model timings.
# Each model is run cold (worst case = first popup invocation after restart).
#
# Output columns: LOAD, TTFT, TOK/S, TOTAL (seconds), and the actual response
# so you can judge both speed AND answer quality.
#
# Edit the `models` array below to add/remove models. Skipped categories:
# embedding (mxbai-embed-large), vision (llava), code-completion fine-tunes
# (maryasov/*) — none of those are chat-suitable.
#
# Usage: ./ollama-bench.sh
# Requires: ollama daemon running (curl http://localhost:11434/api/version)

PROMPT='One-line bash command to find the 5 largest files recursively in the current directory and print their sizes. Output ONLY the command — no explanation, no markdown fences, no preamble.'

# Chat-capable models. Skipping: mxbai-embed (embedding), llava (vision),
# maryasov/* (fine-tune variant), custom-gpt-oss (modelfile dup).
models=(
  "gemma3:4b"
  "llama3.2:latest"
  "qwen2.5:7b"
  "mistral:7b"
  "starcoder2:15b"
  "gpt-oss:20b"
  "qwen3.5:27b"
  "qwen3-coder:30b"
  "codellama:34b"
)

# Unload everything first so each model is a true cold start
for m in "${models[@]}"; do
  curl -s http://localhost:11434/api/generate \
    -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done

printf '%-22s %8s %8s %8s %8s   %s\n' "MODEL" "LOAD" "TTFT" "TOK/S" "TOTAL" "RESPONSE"
printf '%-22s %8s %8s %8s %8s   %s\n' "----" "----" "----" "----" "----" "--------"

for m in "${models[@]}"; do
  resp=$(timeout 180 curl -s --max-time 170 http://localhost:11434/api/generate -d "$(jq -n \
    --arg model "$m" --arg prompt "$PROMPT" \
    '{model: $model, prompt: $prompt, stream: false, options: {num_predict: 80, temperature: 0.2}}')")

  if [[ -z "$resp" ]] || ! echo "$resp" | jq -e '.eval_count' >/dev/null 2>&1; then
    printf '%-22s %s\n' "$m" "(timeout or error)"
    continue
  fi

  load_ns=$(echo "$resp" | jq -r '.load_duration // 0')
  prompt_ns=$(echo "$resp" | jq -r '.prompt_eval_duration // 0')
  eval_ns=$(echo "$resp" | jq -r '.eval_duration // 0')
  eval_count=$(echo "$resp" | jq -r '.eval_count // 0')
  total_ns=$(echo "$resp" | jq -r '.total_duration // 0')
  text=$(echo "$resp" | jq -r '.response' | tr '\n' ' ' | sed 's/  */ /g' | head -c 110)

  load_s=$(awk -v n="$load_ns" 'BEGIN{printf "%.2fs", n/1e9}')
  ttft_s=$(awk -v l="$load_ns" -v p="$prompt_ns" 'BEGIN{printf "%.2fs", (l+p)/1e9}')
  total_s=$(awk -v n="$total_ns" 'BEGIN{printf "%.2fs", n/1e9}')
  toks=$(awk -v c="$eval_count" -v e="$eval_ns" 'BEGIN{ if (e==0) print "N/A"; else printf "%.1f", c*1e9/e }')

  printf '%-22s %8s %8s %8s %8s   %s\n' "$m" "$load_s" "$ttft_s" "$toks" "$total_s" "$text"
done

# Free memory after benchmark
for m in "${models[@]}"; do
  curl -s http://localhost:11434/api/generate \
    -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done
