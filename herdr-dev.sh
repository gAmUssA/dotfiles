#!/usr/bin/env bash
#
# herdr-dev.sh — spawn a herdr workspace for agent work on a project.
# The herdr counterpart to claude-dev.sh (`cdev`); this one is `hdev`.
#
# Usage:
#   herdr-dev.sh [directory]        # defaults to $PWD
#   herdr-dev.sh ~/projects/api     # workspace label = "api"
#
# Layout (herdr's nouns instead of tmux's — workspace = tmux session,
# tab = tmux window):
#   Tab 1 (claude) — `claude --dangerously-skip-permissions` (yolo) in the
#                    project directory, started as a tracked herdr AGENT so it
#                    shows up in the sidebar with live state
#   Tab 2 (shell)  — plain shell for git / builds / scratch
#   Tab 3 (tests)  — only if a test runner is detected
#
# Behavior:
#   - Reuses an existing workspace with the same label instead of making a
#     duplicate, matching cdev's has-session check.
#   - Starts the herdr server if it isn't running. Unlike tmux, the herdr CLI
#     talks to a server over a socket and every command fails with
#     `server_not_running` when it is down, so this cannot be skipped.
#   - Inside a herdr pane (HERDR_ENV=1) it only focuses the workspace: herdr
#     blocks nested client launches by design.
#
# Difference from cdev worth knowing: cdev pre-types the test command into the
# tests window with `tmux send-keys`. herdr's send-keys targets AGENT panes
# only, so there is no equivalent for a plain shell pane. The command is
# exported as $HDEV_TEST_CMD in that tab instead — run it with `$HDEV_TEST_CMD`.

set -euo pipefail

HERDR_BIN="${HERDR_BIN_PATH:-$HOME/.local/bin/herdr}"
command -v jq >/dev/null 2>&1 || { echo "hdev: jq is required" >&2; exit 1; }
[[ -x "$HERDR_BIN" ]] || { echo "hdev: herdr not found at $HERDR_BIN" >&2; exit 1; }

# Resolve target directory
target="${1:-$PWD}"
if [[ ! -d "$target" ]]; then
  echo "hdev: '$target' is not a directory" >&2
  exit 1
fi
target=$(cd "$target" && pwd)
label=$(basename "$target")

# --- Make sure a server is up ------------------------------------------------
# Every `herdr <noun>` CLI call goes over the socket, so with no server they all
# fail with server_not_running. `herdr` (the client) would start one, but it
# also attaches and takes over the terminal, which we cannot do before the
# workspace is built. So start it headless and wait for the socket.
# NOTE: capture then grep, never `herdr status | grep -q`. `grep -q` exits on
# the first match, herdr takes SIGPIPE, and `set -o pipefail` then reports the
# whole pipeline as failed — so a RUNNING server reads as stopped and this
# function starts a redundant one on every call.
server_running() {
  local out
  out=$("$HERDR_BIN" status server 2>/dev/null) || return 1
  [[ "$out" == *"status: running"* ]]
}

ensure_server() {
  if server_running; then
    return 0
  fi
  echo "hdev: starting herdr server..."
  nohup "$HERDR_BIN" server >/dev/null 2>&1 &
  for _ in $(seq 1 40); do
    server_running && return 0
    sleep 0.25
  done
  echo "hdev: herdr server did not come up" >&2
  exit 1
}
ensure_server

# Attach unless we are already inside a herdr pane (nested launches are blocked).
attach_or_exit() {
  if [[ -n "${HERDR_ENV:-}" ]]; then
    echo "hdev: focused '$label' (already inside herdr)"
    exit 0
  fi
  exec "$HERDR_BIN"
}

# --- Reuse an existing workspace --------------------------------------------
existing=$("$HERDR_BIN" workspace list 2>/dev/null \
  | jq -r --arg l "$label" '.result.workspaces[]? | select(.label == $l) | .workspace_id' \
  | head -1)

if [[ -n "$existing" ]]; then
  "$HERDR_BIN" workspace focus "$existing" >/dev/null 2>&1 || true
  attach_or_exit
fi

# --- Detect a test runner (same set cdev uses) -------------------------------
test_cmd=""
if   [[ -f "$target/package.json"   ]]; then test_cmd="npm test"
elif [[ -f "$target/Cargo.toml"     ]]; then test_cmd="cargo test"
elif [[ -f "$target/go.mod"         ]]; then test_cmd="go test ./..."
elif [[ -f "$target/pytest.ini"     ]] || [[ -f "$target/pyproject.toml" ]]; then test_cmd="pytest"
fi

# --- Build the workspace -----------------------------------------------------
created=$("$HERDR_BIN" workspace create --cwd "$target" --label "$label" --no-focus 2>&1)
ws=$(jq -r '.result.workspace.workspace_id // empty' <<<"$created")
pane=$(jq -r '.result.root_pane.pane_id // empty'   <<<"$created")
tab=$(jq  -r '.result.tab.tab_id // empty'          <<<"$created")
if [[ -z "$ws" || -z "$pane" ]]; then
  echo "hdev: could not create workspace:" >&2
  jq -r '.error.message // .' <<<"$created" >&2
  exit 1
fi

[[ -n "$tab" ]] && "$HERDR_BIN" tab rename "$tab" claude >/dev/null 2>&1 || true

# Start claude as a tracked agent so the sidebar shows its live state. Agent
# names are global, so fall back to the pane id if this label is taken.
if ! "$HERDR_BIN" agent start "$label" --kind claude --pane "$pane" \
      -- --dangerously-skip-permissions >/dev/null 2>&1; then
  "$HERDR_BIN" agent start "$label-$pane" --kind claude --pane "$pane" \
      -- --dangerously-skip-permissions >/dev/null 2>&1 || true
fi

"$HERDR_BIN" tab create --workspace "$ws" --cwd "$target" --label shell --no-focus >/dev/null 2>&1 || true

if [[ -n "$test_cmd" ]]; then
  "$HERDR_BIN" tab create --workspace "$ws" --cwd "$target" --label tests \
    --env "HDEV_TEST_CMD=$test_cmd" --no-focus >/dev/null 2>&1 || true
fi

# Focus the agent tab, then the workspace
[[ -n "$tab" ]] && "$HERDR_BIN" tab focus "$tab" >/dev/null 2>&1 || true
"$HERDR_BIN" workspace focus "$ws" >/dev/null 2>&1 || true

echo "hdev: workspace '$label' ($ws) ready${test_cmd:+ — tests tab has \$HDEV_TEST_CMD=\"$test_cmd\"}"
attach_or_exit
