# Flint (Recursive's 40B-A2.5B MoE) in your own pi, served by rec.
# rec beat Ollama ~1.5x on the agent bench with identical scores, and pi
# beat OpenCode (no malformed edit calls) — see bench-results/.
# The context must match pi/models.json (provider "rec", 65536).
FLINT_CONTEXT=65536

# Start rec in the background unless it is already serving; wait until ready.
flint-serve() {
  command -v rec >/dev/null || {
    echo "rec is not installed: curl -fsSL https://raw.githubusercontent.com/recursive-oss/rec/main/install.sh | SHELL=/bin/sh bash" >&2
    return 1
  }
  rec status 2>/dev/null | jq -e .ready >/dev/null 2>&1 && return 0
  local log="${XDG_STATE_HOME:-$HOME/.local/state}/rec-serve.log"
  mkdir -p "${log:h}"
  rec serve --context "$FLINT_CONTEXT" >"$log" 2>&1 &!
  local i
  for i in {1..120}; do
    rec status 2>/dev/null | jq -e .ready >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "rec did not become ready in 120s; see $log" >&2
  return 1
}

# pi on Flint. Extra arguments go to pi (e.g. `flint -p "fix the test"`).
flint() {
  flint-serve || return
  pi --provider rec --model flint "$@"
}
