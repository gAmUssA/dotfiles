# Splash agent-bench repro

A coding-agent benchmark of [Splash](https://github.com/incoai/splash) serving
Qwen3.8-27B, run through two real agent harnesses, with oMLX serving the same
model as the baseline. Everything needed to rerun it is in this repository.

## What it measures

Three small Python repos in [`../../tasks/`](../../tasks), each with planted
bugs and a missing feature. The agent gets the repo and `prompt.txt`, then
works alone. After it stops, the pristine visible tests and a set of
**hidden** tests (copied in only after the run) are graded.

| Task | Shape |
|---|---|
| ledger | 3 planted bugs and 1 missing method, one module |
| shop | a case-insensitive SKU crash deep in a traceback, half-up tax rounding, tax-after-discount ordering, and a new rule type across 3 files |
| planner | priority tie-break, cycle reporting, dependency-end scheduling, and capacity-limited resources across 3 modules |

Each task runs under [pi](https://pi.dev/) (no extensions, skills or context
files, `--offline`) and under OpenCode (`run --standalone`, MCP servers off).
Per run, the report records the tests passed, wall time, turns, tool calls,
failed calls (including a test run exiting non-zero, which is normal) and
malformed calls (arguments the harness rejected).

## Results

Mac Studio, M5 Max (40-core GPU), 64 GB, macOS 27.0.1 · Splash 1.6.0 ·
oMLX HEAD-68c8c09 · rec 0.1.0 · pi 1.4.0 · OpenCode 2.0.25 · Python 3.15 ·
2026-11-08. Wall time per run; every run passed all visible tests.

| Run | oMLX · Qwen3.8-27B oQ4e MTP | **Splash · Qwen3.8-27B 4bit** (run 1 / run 2) | rec · Flint 40B-A2.5B int4 |
|---|---|---|---|
| pi ledger | 26s | **19s / 19s** | 19s |
| pi shop | 62s | **40s / 39s** | 80s |
| pi planner | 136s | **61s / 55s** | 68s |
| OpenCode ledger | 97s | 65s / 61s | 23s |
| OpenCode shop | 195s | 117s / 148s | 72s, 5/6 hidden, 5 malformed calls |
| OpenCode planner | 245s | 205s / 173s | 70s |
| **pi total** | 224s | **120s / 113s** | 167s |
| **OpenCode total** | 537s | 387s / 382s | 165s |

Hidden tests: all passed on oMLX and Splash; Flint missed one on OpenCode
shop. Failed tool calls per run were 0–2 everywhere except Flint's OpenCode
shop. Run 2 of Splash is this kit (`run.sh`), against the same server.

On the same 27B model and harnesses, Splash finished the agent loops
**1.2–2.5× faster per run than oMLX** (1.9–2.0× in total under pi, 1.4× under
OpenCode), with the same scores. That is well under the 2× decode speed-up
the launch post reports, as agent wall time is also turns, tool execution
and prefill. Flint is a different, sparser model (2.5B active), included as
the local baseline these numbers are compared against; its OpenCode runs
are fastest overall, but it is the only one that lost a hidden test.

Conditions and limits:

- One run per row, except Splash (two). Splash's two runs differed by up to 26% (OpenCode shop).
- Only one engine ran the bench at a time. Splash was stopped during the
  oMLX and Flint runs. rec stayed resident (Flint loaded) throughout, and
  oMLX kept its model loaded while Splash ran.
- Each engine got one untimed warm-up request first. Without it, oMLX and
  rec pay 30–60s of loading in their first timed run (pi ledger); Splash
  loads at start-up and did not.
- Splash and oMLX ran at their defaults. rec served a 262144-token context.
  `/v1/models` on Splash reports reasoning effort `xhigh` as its default, and
  neither harness overrides it.
- Full table for every model tried on this machine:
  [`bench-results/agent-m5-max-64gb.md`](../../../bench-results/agent-m5-max-64gb.md).

## Reproduce

### Prerequisites

- Apple silicon M3 or newer, macOS 26.4+, 36 GB+ (Splash's own floor).
- `brew install incoai/tap/splash`
- [pi](https://pi.dev/) and [OpenCode](https://opencode.ai/) on PATH, plus
  `python3`, `curl` and `jq`.

### Run

```bash
git clone https://github.com/gAmUssA/dotfiles && cd dotfiles

# terminal 1 — the first start downloads ~20 GB (model + DFlash2 draft)
splash serve --model mlx-community/Qwen3.8-27B-4bit --port 8100

# terminal 2, after "Ready"
agent-bench/repro/splash/run.sh --check   # prerequisites only
agent-bench/repro/splash/run.sh           # ~10 min, 6 runs
```

`run.sh` gives each harness a provider pointing at the server, in a temporary
pi agent dir (`PI_CODING_AGENT_DIR`) and OpenCode config (`OPENCODE_CONFIG`).
Your own pi and OpenCode providers are not used, and nothing outside the
checkout changes. Results land in `bench-out/repro-splash/report.md`, with
each run's raw JSON event stream in `bench-out/repro-splash/<run>/events.jsonl`
and the agent's final tree in `<run>/work/`.

`SPLASH_PORT` and `SPLASH_MODEL` override the port (8100 here, as oMLX
held 8000) and the model.

The provider both harnesses got, as pi sees it — the same entry
[`pi/models.json`](../../../pi/models.json) tracks:

```json
"splash": {
  "baseUrl": "http://127.0.0.1:8100/v1",
  "api": "openai-completions",
  "apiKey": "local",
  "models": [{
    "id": "mlx-community/Qwen3.8-27B-4bit",
    "reasoning": true,
    "thinkingLevelMap": {"off": "none"},
    "input": ["text", "image"],
    "contextWindow": 262144,
    "maxTokens": 32768,
    "compat": {"supportsMidConvoSystemMessages": true}
  }]
}
```

It mirrors what `splash pi` writes. The kit does not use `splash pi` itself:
that command edits `~/.pi/agent/models.json` in place.

## Observations for the Splash team

1. **The launch post's model no longer loads.** `splash serve --model
   incoai/Qwen3.8-27B-Splash` (from the announcement) fails on 1.6.0 with
   *"is a Splash package, which Splash no longer loads; serve the MLX model of
   its family instead"*. The message is clear, but the post is what new users
   copy.
2. **`splash pi` writes through a symlinked `~/.pi/agent/models.json`.**
   The code says this is deliberate, for dotfile managers. But a dotfiles repo
   is exactly where an unasked-for edit lands in a tracked, often public file.
   A `--print` mode that emits the provider JSON (or writing only when the
   file is not a link) would let those users paste it themselves.
3. **Port 8000 collides with oMLX**, which already listened there on this machine
   (`cannot bind 127.0.0.1:8000: Address already in use`). `--port` solves
   it; mentioning it in the quick start would save a round trip.
4. **Start-up:** the first start took ~4 minutes on top of the download,
   including a 34s Neural Engine calibration; later starts take ~45s.
5. **No problems seen:** no malformed tool calls in 12 Splash runs, a clean
   shutdown on SIGTERM, and identical scores across the two runs.
