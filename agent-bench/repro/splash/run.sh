#!/usr/bin/env bash
# Reproduce the Splash rows of bench-results/agent-m5-max-64gb.md on a clean
# machine: three coding tasks, each driven by pi and by OpenCode against a
# local `splash serve`. See README.md beside this script.
#
#   agent-bench/repro/splash/run.sh            # run the bench (~10 min)
#   agent-bench/repro/splash/run.sh --check    # prerequisites only
#
# Needs: splash serving $SPLASH_MODEL on 127.0.0.1:$SPLASH_PORT, plus pi,
# opencode, python3, curl and jq on PATH. Nothing outside this checkout is
# written except a temporary pi agent dir and OpenCode config, both removed
# on exit; your own pi and OpenCode settings are not read for the provider.
# Results: $REPRO_OUT/report.md (default bench-out/repro-splash/).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
PORT="${SPLASH_PORT:-8100}"
MODEL="${SPLASH_MODEL:-mlx-community/Qwen3.8-27B-4bit}"
OUT_DIR="${REPRO_OUT:-$REPO/bench-out/repro-splash}"

cleanup() {
    [[ -n "${tmp:-}" ]] && rm -rf "$tmp"
    return 0
}

check() {
    local tool missing=() models
    for tool in splash pi opencode python3 curl jq; do
        command -v "$tool" >/dev/null || missing+=("$tool")
    done
    if ((${#missing[@]})); then
        echo "missing on PATH: ${missing[*]} — see README.md, Prerequisites" >&2
        return 1
    fi
    models=$(curl -sf --max-time 5 "http://127.0.0.1:$PORT/v1/models") || {
        echo "no Splash server on 127.0.0.1:$PORT — start one in another terminal:" >&2
        echo "  splash serve --model $MODEL --port $PORT" >&2
        return 1
    }
    jq -e --arg m "$MODEL" 'any(.data[]?; .id == $m)' <<<"$models" >/dev/null || {
        echo "Splash on :$PORT serves $(jq -r '[.data[]?.id] | join(", ")' <<<"$models"), not $MODEL —" >&2
        echo "  restart it with: splash serve --model $MODEL --port $PORT" >&2
        return 1
    }
}

# The provider both harnesses get: the same entry pi/models.json and
# opencode/opencode.json track, at this run's port and model.
write_configs() {  # dir
    mkdir -p "$1/pi"
    jq -n --arg url "http://127.0.0.1:$PORT/v1" --arg m "$MODEL" '{providers: {splash: {
        baseUrl: $url, api: "openai-completions", apiKey: "local",
        models: [{id: $m, reasoning: true, thinkingLevelMap: {off: "none"},
                  input: ["text", "image"], contextWindow: 262144, maxTokens: 32768,
                  compat: {supportsMidConvoSystemMessages: true}}]}}}' >"$1/pi/models.json"
    jq -n --arg url "http://127.0.0.1:$PORT/v1" --arg m "$MODEL" '{
        "$schema": "https://opencode.ai/config.json",
        provider: {splash: {npm: "@ai-sdk/openai-compatible", name: "Splash",
            options: {baseURL: $url, apiKey: "local"},
            models: {($m): {limit: {context: 262144, output: 32768}}}}}}' >"$1/opencode.json"
}

main() {
    check || exit 1
    [[ "${1:-}" == --check ]] && { echo "ready: Splash serves $MODEL on :$PORT"; exit 0; }
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/splash-repro.XXXXXX")
    trap cleanup EXIT
    write_configs "$tmp"
    mkdir -p "$OUT_DIR"
    PI_CODING_AGENT_DIR="$tmp/pi" OPENCODE_CONFIG="$tmp/opencode.json" \
        SPLASH_PORT="$PORT" AGENT_BENCH_OUT="$OUT_DIR" AGENT_BENCH_REPORT="$OUT_DIR/report.md" \
        "$REPO/agent-bench/agent-bench.sh" -h pi,opencode -p splash "$MODEL"
    echo "report: $OUT_DIR/report.md   raw events: $OUT_DIR/*/events.jsonl"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
