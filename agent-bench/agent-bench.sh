#!/usr/bin/env bash
# agent-bench.sh — agentic coding bench: does a local model, driven by pi,
# actually FIX a small repo? Complements ollama-code-bench (one-shot codegen,
# no tools), which cannot tell a good agent driver from a good autocompleter.
#
# Per model: copy fixture/ (a tiny Python package with 3 planted bugs and one
# unimplemented method; 4 of its 8 visible tests fail), give pi one task, let it
# use its tools until it stops, then grade:
#   visible   tests/test_ledger.py — what the agent could see and run
#   hidden    hidden/test_hidden.py — copied in AFTER the run, so it cannot be
#             special-cased; checks the documented contract, not the examples
#   tampered  any change to tests/ by the agent (forbidden by the prompt)
# plus wall time, turns, tool calls and tool errors from pi's JSON event stream.
#
# Usage: agent-bench/agent-bench.sh <ollama-model> [...]
#   e.g. agent-bench/agent-bench.sh qwen3-coder:30b-ctx64k qwen3.6:35b-mlx-ctx64k
# Models must be listed under the ollama provider in pi/models.json. Use the
# -ctx64k variants: Ollama's default context truncates agent prompts.
# Writes bench-results/agent-<chip>-<ram>gb.md; raw runs go to bench-out/agent/.
#
# pi gets stdin </dev/null: in -p mode it otherwise waits on stdin forever.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$HERE")"
OUT="$REPO/bench-out/agent"
TIMEOUT="${AGENT_BENCH_TIMEOUT:-900}"   # seconds per model

PROMPT='This is a small Python package. Run its tests with `python3 -m unittest -v`.
Fix the failing tests by changing code under ledger/ only, and implement
Ledger.monthly_totals() exactly as its docstring describes. Do NOT modify
anything under tests/. Re-run the tests until they all pass, then stop and
summarize what you changed in two sentences.'

[[ $# -gt 0 ]] || { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
command -v pi >/dev/null || { echo "pi not found (npm i -g @earendil-works/pi-coding-agent)"; exit 1; }
curl -sf --max-time 5 http://localhost:11434/api/version >/dev/null \
    || { echo "ollama daemon unreachable — open Ollama.app"; exit 1; }

mkdir -p "$OUT"
results="$OUT/results.tsv"
: > "$results"

# unittest counts for one test module: prints "passed total"
grade() {
    (cd "$1" && python3 - "$2" <<'PY'
import sys, unittest, io
suite = unittest.defaultTestLoader.loadTestsFromName(sys.argv[1])
r = unittest.TextTestRunner(stream=io.StringIO(), verbosity=0).run(suite)
bad = len(r.failures) + len(r.errors)
print(r.testsRun - bad, r.testsRun)
PY
    ) 2>/dev/null || echo "0 ?"
}

for m in "$@"; do
    slug=$(echo "$m" | tr ':/.' '___')
    dir="$OUT/$slug"; work="$dir/work"
    rm -rf "$dir"; mkdir -p "$dir"
    cp -R "$HERE/fixture" "$work"
    before=$(cd "$work" && find tests -type f -name '*.py' -exec shasum {} + | sort | shasum)

    echo "########## $m ##########"
    start=$(date +%s)
    (cd "$work" && timeout "$TIMEOUT" pi -p --mode json --no-session \
        --no-extensions --no-skills --no-context-files --offline \
        --provider ollama --model "$m" "$PROMPT" </dev/null) \
        > "$dir/events.jsonl" 2> "$dir/pi.err"
    rc=$?
    secs=$(( $(date +%s) - start ))

    after=$(cd "$work" && find tests -type f -name '*.py' -exec shasum {} + | sort | shasum)
    tampered=no; [[ "$before" == "$after" ]] || tampered=YES
    # Grade against PRISTINE tests even if the agent edited them.
    rm -rf "$work/tests"; cp -R "$HERE/fixture/tests" "$work/tests"
    cp "$HERE/hidden/test_hidden.py" "$work/tests/"
    read -r vis_ok vis_n <<<"$(grade "$work" tests.test_ledger)"
    read -r hid_ok hid_n <<<"$(grade "$work" tests.test_hidden)"

    read -r turns tools tool_errs malformed <<<"$(python3 - "$dir/events.jsonl" <<'PY'
import json, sys
# errs: any tool result flagged isError — includes a bash test run that exits
# non-zero, which is normal agent behaviour. malformed: pi rejected the call's
# arguments ("Validation failed for tool ...") — the tool-format weakness that
# actually matters for a local model driving an agent.
turns = tools = errs = malformed = 0
for line in open(sys.argv[1], errors="replace"):
    try: e = json.loads(line)
    except ValueError: continue
    t = e.get("type")
    turns += t == "turn_start"
    tools += t == "tool_execution_start"
    if t == "tool_execution_end" and e.get("isError"):
        errs += 1
        malformed += "Validation failed for tool" in json.dumps(e.get("result"))
print(turns, tools, errs, malformed)
PY
)"
    status=done; [[ $rc -eq 124 ]] && status=TIMEOUT; [[ $rc -ne 0 && $rc -ne 124 ]] && status="exit $rc"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$m" "$vis_ok" "$vis_n" "$hid_ok" "$hid_n" \
        "$tampered" "$secs" "$turns" "$tools" "$tool_errs" "$malformed" "$status" >> "$results"
    echo "visible $vis_ok/$vis_n | hidden $hid_ok/$hid_n | tests tampered: $tampered | ${secs}s | turns $turns | tools $tools ($tool_errs failed, $malformed malformed) | $status"
done

# --- record --------------------------------------------------------------------
chip=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)
ram=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
slugchip=$(echo "$chip" | sed 's/Apple //' | tr 'A-Z ' 'a-z-')
dest="$REPO/bench-results/agent-${slugchip}-${ram}gb.md"
{
    echo "# Agent bench — $chip, $ram GB"
    echo
    echo "Generated by \`agent-bench/agent-bench.sh\`. One task, driven end-to-end by"
    echo "pi with tools: fix 3 planted bugs + implement one method in a small Python"
    echo "package (4/8 visible tests failing at start). Graded by running the tests"
    echo "after the agent stops, including 5 hidden tests it never saw."
    echo
    echo "*failed* = tool results flagged as errors, incl. test runs that exit non-zero"
    echo "(normal). *malformed* = calls pi rejected for bad arguments — the number that"
    echo "says whether a model can drive tools reliably."
    echo
    echo "| field | value |"
    echo "|---|---|"
    echo "| pi | $(pi --version 2>/dev/null) |"
    echo "| ollama | $(ollama --version 2>/dev/null | awk '{print $NF}') |"
    echo "| python | $(python3 --version 2>&1 | awk '{print $2}') |"
    echo "| timeout | ${TIMEOUT}s per model |"
    echo "| recorded | $(date +%Y-%m-%d) |"
    echo
    echo "| model | digest | visible | hidden | tests untouched | time | turns | tool calls | failed | malformed | end |"
    echo "|---|---|---|---|---|---|---|---|---|---|---|"
    while IFS=$'\t' read -r m vok vn hok hn tam secs turns tools errs bad st; do
        digest=$(ollama list | awk -v m="$m" '$1==m{print $2}')
        ok=$([[ "$vok" == "$vn" && "$hok" == "$hn" && "$tam" == no ]] && echo "**$vok/$vn**" || echo "$vok/$vn")
        echo "| \`$m\` | \`$digest\` | $ok | $hok/$hn | $([[ $tam == no ]] && echo ✅ || echo "❌ edited") | ${secs}s | $turns | $tools | $errs | $bad | $st |"
    done < "$results"
} > "$dest"
echo "wrote $dest"
