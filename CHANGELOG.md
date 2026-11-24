# Changelog

## 2026-11-24

- The benchmark moved to [gAmUssA/agent-bench](https://github.com/gAmUssA/agent-bench), results at
  [gamov.io/agent-bench](https://gamov.io/agent-bench): `agent-bench/`, `bench-results/`,
  `bench-record.sh`, `ollama-*bench*.sh`, the gemma4 sweep scripts and their tests are gone from
  here, and dotfiles keeps only the provider setup. `pi/models.json` gains the `unsloth` 256k
  alias and the `mtplx` provider, and an Inkling model on `omlx`.

## 2026-11-21

- `agent-bench`'s `rec` provider preflight honours `REC_BASE_URL` (default
  `http://127.0.0.1:11500`), and `tests/test_agent_bench_rec.sh` smoke-tests it
  against a loopback stub: closed port and failing `rec auth token` are
  rejected, a stub that requires the bearer key is accepted.

- `agent-bench` gains a `claude` harness (`-h claude -p anthropic opus`) that
  runs `claude -p` on the CLI login and never on an API key, and its report
  keeps earlier rows instead of rebuilding from the last invocation alone.
  Inkling 2 mini, 256k-context variants and an Opus run are recorded in
  `bench-results/agent-m5-max-64gb.md`; `qwen3-coder` is dropped from the pi
  and OpenCode configs.

## 2026-11-06

- The README, `AGENTS.md`, and Claude's auto-mode notes now match the
  machine: `~/.claude/settings.local.json` is not a global settings file,
  Mackup stays retired, and the Stop hook does not ring the tmux bell
  (tmux-agentbar does). `linkall.sh` no longer deletes `~/.mackup.cfg`.

## 2026-11-04

- Pause AeroSpace automatically while Keynote or Keynote Creator Studio is
  running, preventing fullscreen slideshows from disappearing. Restore an
  automation-owned pause when Keynote quits; preserve existing manual pauses.
