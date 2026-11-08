#!/usr/bin/env bash
# agent-bench/repro/splash/run.sh --check, against a stub /v1/models served by
# python's http.server on a free port. splash, pi and opencode are stubs on
# PATH: only their presence is checked, and no model is ever run.
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

main() (
  local repo sandbox port server=""
  repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
  sandbox=$(mktemp -d "${TMPDIR:-/tmp}/splash-repro-test.XXXXXX")
  trap '[[ -n "$server" ]] && kill "$server" 2>/dev/null; rm -rf -- "$sandbox"; return 0' EXIT

  mkdir -p "$sandbox/bin" "$sandbox/www/v1"
  local tool
  for tool in splash pi opencode; do
    printf '#!/bin/sh\nexit 0\n' >"$sandbox/bin/$tool"
    chmod +x "$sandbox/bin/$tool"
  done
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')

  # Run the check; print its stderr, succeed iff it accepts.
  check() {
    # shellcheck disable=SC2069 # keep stderr (the message under test), drop stdout
    PATH="$sandbox/bin:$PATH" SPLASH_PORT=$port SPLASH_MODEL=mlx-community/Qwen3.8-27B-4bit \
      "$repo/agent-bench/repro/splash/run.sh" --check 2>&1 >/dev/null
  }

  local err
  if err=$(check); then fail "accepted with no server on :$port"; fi
  [[ "$err" == *"splash serve --model mlx-community/Qwen3.8-27B-4bit --port $port"* ]] \
    || fail "no-server message names no start command: $err"
  printf 'PASS: no server is refused, with the command that starts one\n'

  printf '{"data":[{"id":"unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M"}]}' >"$sandbox/www/v1/models"
  python3 -m http.server "$port" --bind 127.0.0.1 --directory "$sandbox/www" >/dev/null 2>&1 &
  server=$!
  local _
  for _ in $(seq 50); do curl -sf "http://127.0.0.1:$port/v1/models" >/dev/null && break; sleep 0.1; done
  if err=$(check); then fail "accepted a server serving another model"; fi
  [[ "$err" == *"unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M"* ]] || fail "wrong-model message names no served model: $err"
  printf 'PASS: a server serving another model is refused, naming what it serves\n'

  printf '{"data":[{"id":"mlx-community/Qwen3.8-27B-4bit"}]}' >"$sandbox/www/v1/models"
  check || fail "refused a server serving the model"
  printf 'PASS: a server serving the model is accepted\n'
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
