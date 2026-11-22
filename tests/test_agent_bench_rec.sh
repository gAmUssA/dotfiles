#!/usr/bin/env bash
# agent-bench.sh -p rec preflight, against a stub rec and a loopback
# /v1/models. No model is run: -h nosuch skips every harness, and the stub
# server answers 200 only for the bearer the stub rec printed. Dropping that
# header from the script's curl makes the accept case exit non-zero.
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

main() (
  local repo sandbox server="" key port closed err code rec_ok
  local bench_stamp run_path
  repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
  sandbox=$(mktemp -d "${TMPDIR:-/tmp}/agent-bench-rec-test.XXXXXX")
  trap 'if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi; rm -rf -- "$sandbox"' EXIT

  key=bench-rec-preflight
  rec_ok="#!/bin/sh
if [ \"\${1-}\" = auth ] && [ \"\${2-}\" = token ]; then
  printf '%s\\n' '$key'
fi
exit 0"
  mkdir -p "$sandbox/bin"
  # Keep the real rec, and the other CLIs the report would query, off PATH.
  run_path="$sandbox/bin:$(dirname -- "$(command -v python3)"):/usr/bin:/bin:/usr/sbin:/sbin"

  bench_stamp=$(find "$repo/bench-results" -type f -print0 2>/dev/null | sort -z | xargs -0 shasum 2>/dev/null || true)

  install_rec() {
    printf '%s\n' "$1" >"$sandbox/bin/rec"
    chmod +x "$sandbox/bin/rec"
  }

  # $1 is the base URL. Succeeds iff the preflight passes and the script exits 0.
  run_bench() {
    env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
      -u all_proxy -u ALL_PROXY -u REC_API_KEY -u AGENT_BENCH_APPEND \
      PATH="$run_path" \
      NO_PROXY='*' no_proxy='*' \
      REC_BASE_URL="$1" \
      AGENT_BENCH_OUT="$sandbox/out" \
      AGENT_BENCH_REPORT="$sandbox/report.md" \
      AGENT_BENCH_WARMUP=0 \
      "$repo/agent-bench/agent-bench.sh" -p rec -h nosuch x
  }

  closed=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
  install_rec "$rec_ok"

  # --- REJECT: closed loopback port -----------------------------------------
  if err=$(run_bench "http://127.0.0.1:$closed" 2>&1); then
    fail "accepted a closed port: $err"
  fi
  [[ "$err" == *"rec unreachable"* ]] || fail "closed port message: $err"
  [[ "$err" == *"http://127.0.0.1:$closed"* ]] || fail "closed port message omits REC_BASE_URL: $err"
  printf 'PASS: a closed port is refused, naming the base url\n'

  # --- REJECT: rec auth token failing ---------------------------------------
  install_rec '#!/bin/sh
exit 1'
  if err=$(run_bench "http://127.0.0.1:$closed" 2>&1); then
    fail "accepted a failing rec auth token: $err"
  fi
  [[ "$err" == *"rec auth token failed"* ]] || fail "auth failure message: $err"
  [[ "$err" != *"rec unreachable"* ]] || fail "auth failure fell through to the curl: $err"
  printf 'PASS: a failing rec auth token is refused\n'
  install_rec "$rec_ok"

  # --- ACCEPT: stub /v1/models that requires the bearer ---------------------
  # Bind port 0 inside the server and read the port back once it is listening,
  # so the test does not sleep for the socket to come up.
  cat >"$sandbox/server.py" <<'PY'
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

expected = sys.argv[1]
log_path = sys.argv[2]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        auth = self.headers.get("Authorization", "")
        with open(log_path, "a", encoding="utf-8") as fh:
            fh.write(self.command + " " + path + " " + auth + "\n")
        if path == "/v1/models" and auth == "Bearer " + expected:
            body = b'{"object":"list","data":[]}\n'
            self.send_response(200)
        else:
            body = b"unauthorized\n"
            self.send_response(401)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        return


server = HTTPServer(("127.0.0.1", 0), Handler)
sys.stdout.write(str(server.server_address[1]) + "\n")
sys.stdout.flush()
server.serve_forever()
PY
  mkfifo "$sandbox/ready"
  python3 -u "$sandbox/server.py" "$key" "$sandbox/seen" >"$sandbox/ready" 2>"$sandbox/server.err" &
  server=$!
  IFS= read -r port <"$sandbox/ready" || fail "models server exited before publishing a port: $(cat "$sandbox/server.err")"
  [[ "$port" =~ ^[0-9]+$ ]] || fail "models server published no port: ${port:-}"

  code=$(curl -s -o /dev/null -w '%{http_code}' --noproxy '*' --max-time 5 "http://127.0.0.1:$port/v1/models")
  [[ "$code" == 401 ]] || fail "stub accepted a request with no bearer: $code"
  code=$(curl -s -o /dev/null -w '%{http_code}' --noproxy '*' --max-time 5 \
    -H "Authorization: Bearer $key" "http://127.0.0.1:$port/v1/models")
  [[ "$code" == 200 ]] || fail "stub rejected its own bearer: $code"
  : >"$sandbox/seen"

  if ! err=$(run_bench "http://127.0.0.1:$port" 2>&1); then
    fail "refused a stub that accepts the bearer: $err"
  fi
  [[ -f "$sandbox/seen" ]] || fail "script never requested /v1/models"
  [[ "$(wc -l <"$sandbox/seen" | tr -d ' ')" == 1 ]] || fail "expected one script request: $(cat "$sandbox/seen")"
  [[ "$(cat "$sandbox/seen")" == "GET /v1/models Bearer ${key}" ]] || fail "script dropped the bearer: $(cat "$sandbox/seen")"
  [[ -f "$sandbox/report.md" ]] || fail "script did not write AGENT_BENCH_REPORT"
  [[ ! -e "$repo/bench-out" ]] || fail "preflight wrote $repo/bench-out"
  [[ "$bench_stamp" == "$(find "$repo/bench-results" -type f -print0 2>/dev/null | sort -z | xargs -0 shasum 2>/dev/null || true)" ]] \
    || fail "preflight changed bench-results"
  printf 'PASS: a stub serving /v1/models to the bearer key is accepted\n'
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
