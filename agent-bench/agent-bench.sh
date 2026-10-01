#!/usr/bin/env bash
# agent-bench.sh — agentic coding bench: does a local model, driven by a real
# coding agent, actually FIX a small repo? Complements ollama-code-bench
# (one-shot codegen, no tools), which cannot tell a good agent driver from a
# good autocompleter.
#
# Tasks live in tasks/<name>/: fixture/ (code + visible tests), hidden/ (tests
# copied in only AFTER the run, so they cannot be special-cased) and
# prompt.txt. Each was validated both ways: it fails as shipped, and a
# reference fix (not committed) passes visible + hidden.
#   ledger  easy:   3 planted bugs + 1 method, one module           (4/8 failing)
#   shop    harder: case-insensitive SKU crash surfacing deep in a
#                   traceback, half-up tax rounding, tax-after-discount
#                   ordering, and a new rule type wired across 3 files (6/8)
#
# Per (harness, task, model) run, graded after the agent stops:
#   visible / hidden  tests passed, always against the PRISTINE tests
#   tampered          the agent edited tests/ (forbidden by the prompt)
#   turns, tool calls, failed calls, malformed calls (arguments the harness
#   rejected — the tool-format weakness that matters for a local model;
#   "failed" also counts e.g. a test run exiting non-zero, which is normal)
#
# Usage: agent-bench/agent-bench.sh [-h pi,opencode] [-t ledger,shop] <model> [...]
#   models are Ollama tags, registered in BOTH pi/models.json and
#   opencode/opencode.json — use the -ctx64k variants (Ollama's default context
#   truncates agent prompts).
# Writes bench-results/agent-<chip>-<ram>gb.md; raw events in bench-out/agent/.
#
# Gotchas, both found the hard way:
# - Work dirs are in $TMPDIR, outside this repo: OpenCode loads AGENTS.md from
#   parent dirs, and this repo's AGENTS.md would leak into the task.
# - stdin is </dev/null: `pi -p` otherwise waits on stdin forever.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$HERE")"
OUT="$REPO/bench-out/agent"
TIMEOUT="${AGENT_BENCH_TIMEOUT:-1200}"   # seconds per run
harnesses="pi"; tasks="ledger,shop"

while getopts "h:t:" opt; do
    case $opt in h) harnesses=$OPTARG ;; t) tasks=$OPTARG ;; *) exit 1 ;; esac
done
shift $((OPTIND - 1))
[[ $# -gt 0 ]] || { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
curl -sf --max-time 5 http://localhost:11434/api/version >/dev/null \
    || { echo "ollama daemon unreachable — open Ollama.app"; exit 1; }

OC_NO_MCP=$(python3 -c 'import json,os
p=os.path.expanduser("~/.config/opencode/opencode.json")
try: names=json.load(open(p)).get("mcp",{})
except Exception: names={}
print(json.dumps({"mcp":{n:{"enabled":False} for n in names}}))')

mkdir -p "$OUT"
results="$OUT/results.tsv"
# AGENT_BENCH_APPEND=1 keeps earlier rows: lets a long matrix run in batches
# (a single run of 12 can outlive a background-job time limit).
[[ "${AGENT_BENCH_APPEND:-}" == 1 ]] || : > "$results"

# "passed total" for test modules matching a glob, run in dir $1
grade() {
    (cd "$1" && python3 - "$2" <<'PY'
import sys, unittest, io
suite = unittest.defaultTestLoader.discover("tests", pattern=sys.argv[1], top_level_dir=".")
r = unittest.TextTestRunner(stream=io.StringIO(), verbosity=0).run(suite)
print(r.testsRun - len(r.failures) - len(r.errors), r.testsRun)
PY
    ) 2>/dev/null || echo "0 ?"
}

# "turns tools failed malformed" from a harness's JSON event stream
count_events() {
    python3 - "$1" "$2" <<'PY'
import json, re, sys
harness, path = sys.argv[1], sys.argv[2]
turns = tools = failed = malformed = 0
bad_args = re.compile(r"validation failed|invalid (input|arguments)|arguments provided to the tool are invalid|expected .{0,40} received", re.I)
for line in open(path, errors="replace"):
    try: e = json.loads(line)
    except ValueError: continue
    t = e.get("type")
    if harness == "pi":
        turns += t == "turn_start"
        tools += t == "tool_execution_start"
        if t == "tool_execution_end" and e.get("isError"):
            failed += 1
            malformed += bool(bad_args.search(json.dumps(e.get("result"))))
    else:  # opencode
        turns += t == "step_start"
        if t == "tool_use":
            tools += 1
            st = e.get("part", {}).get("state", {})
            if st.get("status") == "error":
                failed += 1
                malformed += bool(bad_args.search(json.dumps(st.get("error", ""))))
print(turns, tools, failed, malformed)
PY
}

run_agent() {  # harness model workdir prompt -> JSON events on stdout
    local h=$1 m=$2 w=$3 p=$4
    case $h in
        pi) (cd "$w" && timeout "$TIMEOUT" pi -p --mode json --no-session \
                --no-extensions --no-skills --no-context-files --offline \
                --provider ollama --model "$m" "$p" </dev/null) ;;
        # --pure drops plugins but not MCP servers from the global config;
        # disable those too, so OpenCode gets no tools pi does not have.
        opencode) (cd "$w" && OPENCODE_CONFIG_CONTENT="$OC_NO_MCP" timeout "$TIMEOUT" opencode run --pure --auto \
                --format json -m "ollama/$m" "$p" </dev/null) ;;
        *) echo "unknown harness $h" >&2; return 2 ;;
    esac
}

for h in ${harnesses//,/ }; do
  command -v "$h" >/dev/null || { echo "skip harness $h: not installed"; continue; }
  for t in ${tasks//,/ }; do
    tdir="$HERE/tasks/$t"; [[ -d $tdir ]] || { echo "no task $t"; continue; }
    prompt=$(cat "$tdir/prompt.txt")
    for m in "$@"; do
        slug="$h-$t-$(echo "$m" | tr ':/.' '___')"
        dir="$OUT/$slug"; rm -rf "$dir"; mkdir -p "$dir"
        work=$(mktemp -d "${TMPDIR:-/tmp}/agent-bench.XXXXXX")
        cp -R "$tdir/fixture/." "$work/"
        before=$(cd "$work" && find tests -name '*.py' -exec shasum {} + | sort | shasum)

        echo "########## $h / $t / $m ##########"
        start=$(date +%s)
        run_agent "$h" "$m" "$work" "$prompt" > "$dir/events.jsonl" 2> "$dir/agent.err"
        rc=$?
        secs=$(( $(date +%s) - start ))

        after=$(cd "$work" && find tests -name '*.py' -exec shasum {} + | sort | shasum)
        tampered=no; [[ "$before" == "$after" ]] || tampered=YES
        rm -rf "$work/tests"; cp -R "$tdir/fixture/tests" "$work/tests"
        read -r vis_ok vis_n <<<"$(grade "$work" 'test_*.py')"
        cp "$tdir/hidden/"*.py "$work/tests/"
        read -r hid_ok hid_n <<<"$(grade "$work" 'test_hidden*.py')"
        read -r turns tools failed malformed <<<"$(count_events "$h" "$dir/events.jsonl")"
        cp -R "$work" "$dir/work"; rm -rf "$work"

        status=done; [[ $rc -eq 124 ]] && status=TIMEOUT; [[ $rc -ne 0 && $rc -ne 124 ]] && status="exit $rc"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$h" "$t" "$m" \
            "$vis_ok" "$vis_n" "$hid_ok" "$hid_n" "$tampered" "$secs" "$turns" "$tools" \
            "$failed" "$malformed" "$status" >> "$results"
        echo "visible $vis_ok/$vis_n | hidden $hid_ok/$hid_n | tampered $tampered | ${secs}s | turns $turns | tools $tools ($failed failed, $malformed malformed) | $status"
    done
  done
done

# --- record --------------------------------------------------------------------
chip=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)
ram=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
slugchip=$(echo "$chip" | sed 's/Apple //' | tr 'A-Z ' 'a-z-')
dest="$REPO/bench-results/agent-${slugchip}-${ram}gb.md"
{
    echo "# Agent bench — $chip, $ram GB"
    echo
    echo "Generated by \`agent-bench/agent-bench.sh\`; tasks and grading are described"
    echo "in its header. Each row is ONE run — sampling makes single runs noisy."
    echo
    echo "*failed* = tool results flagged as errors, incl. test runs that exit"
    echo "non-zero (normal). *malformed* = calls the harness rejected for bad"
    echo "arguments — the number that says whether a model drives tools reliably."
    echo
    echo "| field | value |"
    echo "|---|---|"
    echo "| pi | $(pi --version 2>/dev/null) |"
    echo "| opencode | $(opencode --version 2>/dev/null) |"
    echo "| ollama | $(ollama --version 2>/dev/null | awk '{print $NF}') |"
    echo "| python | $(python3 --version 2>&1 | awk '{print $2}') |"
    echo "| timeout | ${TIMEOUT}s per run |"
    echo "| recorded | $(date +%Y-%m-%d) |"
    echo
    echo "| harness | task | model | digest | visible | hidden | tests untouched | time | turns | tool calls | failed | malformed | end |"
    echo "|---|---|---|---|---|---|---|---|---|---|---|---|---|"
    while IFS=$'\t' read -r h t m vok vn hok hn tam secs turns tools failed bad st; do
        digest=$(ollama list | awk -v m="$m" '$1==m{print $2}')
        full=$([[ "$vok" == "$vn" && "$hok" == "$hn" && "$tam" == no ]] && echo "**$vok/$vn**" || echo "$vok/$vn")
        echo "| $h | $t | \`$m\` | \`$digest\` | $full | $hok/$hn | $([[ $tam == no ]] && echo ✅ || echo "❌ edited") | ${secs}s | $turns | $tools | $failed | $bad | $st |"
    done < "$results"
} > "$dest"
echo "wrote $dest"
