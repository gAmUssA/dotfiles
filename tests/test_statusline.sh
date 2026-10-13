#!/usr/bin/env bash
# Shared agent status line (claude/statusline.sh) and its per-CLI installer
# (agents/statusline-install.sh), against a throwaway HOME and stub CLIs.
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
plain() { sed $'s/\x1b\\[[0-9;]*m//g'; }

main() (
  local repo sandbox out status
  repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
  sandbox=$(mktemp -d "${TMPDIR:-/tmp}/statusline-test.XXXXXX")
  trap 'rm -rf -- "$sandbox"' EXIT
  local script="$repo/claude/statusline.sh"

  # --- rendering --------------------------------------------------------------
  # A full Claude payload: every segment, plus the prompt-cache line.
  out=$(printf '%s' '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/tmp/demo"},
    "cost":{"total_duration_ms":125000,"total_lines_added":10,"total_lines_removed":2},
    "context_window":{"used_percentage":42.7,"context_window_size":1000000},
    "prompt_cache":{"warm":false,"recache_tokens_if_cold":82000}}' | "$script" | plain)
  [[ "$(sed -n 1p <<<"$out")" == "Opus │ demo │ 42%/1M │ +10/-2 │ 2m5s" ]] || fail "full payload line 1: $out"
  [[ "$(sed -n 2p <<<"$out")" == "cache ○ cold · next message re-caches 82k tokens" ]] || fail "cache line: $out"
  printf 'PASS: a full Claude payload renders every segment and the cache line\n'

  # grok/agy shape: no line counts and no prompt cache, so neither appears.
  out=$(printf '%s' '{"model":{"id":"grok-4.7","display_name":"Grok 4.7"},"workspace":{"current_dir":"/tmp/demo"},
    "context_window":{"used_percentage":11,"context_window_size":256000},"cost":{"total_duration_ms":36000}}' | "$script" | plain)
  [[ "$out" == "Grok 4.7 │ demo │ 11%/256k │ 36s" ]] || fail "sparse payload: $out"
  # A bare-string model and a cwd-only payload; nothing at all degrades to "?".
  out=$(printf '%s' '{"model":"gpt-6.1","cwd":"/tmp/demo"}' | "$script" | plain)
  [[ "$out" == "gpt-6.1 │ demo" ]] || fail "string model: $out"
  out=$(printf '{}' | "$script" | plain)
  [[ "$out" == "? │ ?" ]] || fail "empty payload: $out"
  printf 'PASS: absent fields drop their segment instead of rendering zeros\n'

  # --- installer --------------------------------------------------------------
  local home="$sandbox/home" bin="$sandbox/bin" fake="$sandbox/dotfiles"
  mkdir -p "$home/.grok" "$home/.copilot" "$bin" "$fake/pi/extensions" "$fake/opencode/statusline"
  : >"$fake/pi/extensions/statusline.ts"
  : >"$fake/opencode/statusline/tui.tsx"
  for cli in grok agy copilot pi opencode; do printf '#!/bin/sh\n' >"$bin/$cli"; chmod +x "$bin/$cli"; done
  printf '[ui]\nyolo = false\n' >"$home/.grok/config.toml"
  printf '{"hooks":{"SessionStart":[]}}\n' >"$home/.copilot/settings.json"
  install() { HOME="$home" DOTFILES="$fake" PATH="$bin:/usr/bin:/bin:/opt/homebrew/bin" bash "$repo/agents/statusline-install.sh"; }

  install >/dev/null
  [[ $(grep -c '^\[ui\.status_line\]' "$home/.grok/config.toml") == 1 ]] || fail "grok block missing"
  grep -q '^yolo = false$' "$home/.grok/config.toml" || fail "grok lost existing keys"
  # shellcheck disable=SC2088 # the literal ~ is what copilot is meant to expand
  [[ $(jq -r '.statusLine.command' "$home/.copilot/settings.json") == "~/.claude/statusline.sh" ]] || fail "copilot statusLine"
  jq -e '.hooks.SessionStart' "$home/.copilot/settings.json" >/dev/null || fail "copilot lost its hooks"
  [[ $(jq -r '.statusLine.type' "$home/.gemini/antigravity-cli/settings.json") == command ]] || fail "agy statusLine"
  [[ $(readlink "$home/.pi/agent/extensions/statusline.ts") == "$fake/pi/extensions/statusline.ts" ]] || fail "pi link"
  [[ $(readlink "$home/.config/opencode/plugins/dotfiles-statusline") == "$fake/opencode/statusline" ]] || fail "opencode link"
  printf 'PASS: installer configures all five CLIs and keeps their other settings\n'

  local before after
  before=$(cd "$home" && find . -type f -exec shasum {} + | sort)
  out=$(install)
  after=$(cd "$home" && find . -type f -exec shasum {} + | sort)
  [[ "$before" == "$after" ]] || fail "second run changed files"
  grep -q '^linked\|^set ' <<<"$out" && fail "second run reported changes: $out"
  printf 'PASS: a second run changes nothing\n'

  # A regular file where a link belongs is someone's local edit: refuse it.
  rm "$home/.pi/agent/extensions/statusline.ts"
  printf 'local edit\n' >"$home/.pi/agent/extensions/statusline.ts"
  status=0; install >/dev/null 2>"$sandbox/err" || status=$?
  [[ $status -ne 0 ]] || fail "regular file at link target was accepted"
  grep -q 'is a regular file' "$sandbox/err" || fail "no actionable message: $(cat "$sandbox/err")"
  [[ $(cat "$home/.pi/agent/extensions/statusline.ts") == "local edit" ]] || fail "local edit was overwritten"
  rm "$home/.pi/agent/extensions/statusline.ts"
  # JSONC that jq cannot parse is left untouched, with a hand-edit hint.
  printf '// comment\n{}\n' >"$home/.copilot/settings.json"
  status=0; install >/dev/null 2>"$sandbox/err" || status=$?
  [[ $status -ne 0 ]] || fail "unparseable settings were accepted"
  grep -q 'add statusLine by hand' "$sandbox/err" || fail "no hand-edit hint: $(cat "$sandbox/err")"
  [[ $(head -1 "$home/.copilot/settings.json") == "// comment" ]] || fail "unparseable settings were rewritten"
  printf 'PASS: installer refuses to overwrite a regular file or unparseable settings\n'
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
