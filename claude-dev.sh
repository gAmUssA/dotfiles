#!/usr/bin/env bash
#
# claude-dev.sh — spawn a tmux session for Claude Code work on a project.
#
# Usage:
#   claude-dev.sh [directory]        # defaults to $PWD
#   claude-dev.sh ~/projects/api     # session name = "api"
#
# Layout:
#   Window 1 (claude) — runs `claude` in the project directory
#   Window 2 (shell)  — plain zsh, for git / builds / scratch commands
#   Window 3 (tests)  — only created if the project has a test runner
#                       (package.json, go.mod, Cargo.toml, pytest.ini, pyproject.toml)
#
# Behavior:
#   - If a session with the project name already exists, switch to it
#     (inside tmux) or attach to it (outside tmux). No duplicate sessions.
#   - Uses the directory basename as the session name, matching the tmux
#     window-label convention (⚡projectname).

set -euo pipefail

# Resolve target directory
target="${1:-$PWD}"
if [[ ! -d "$target" ]]; then
  echo "claude-dev: '$target' is not a directory" >&2
  exit 1
fi
target=$(cd "$target" && pwd)
session=$(basename "$target")

# tmux disallows '.' and ':' in session names; sanitize to '_'
session=${session//[.:]/_}

# If the session already exists, just attach or switch
if tmux has-session -t "$session" 2>/dev/null; then
  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$session"
  else
    tmux attach-session -t "$session"
  fi
  exit 0
fi

# Detect a test runner to decide whether to spawn a 3rd window
test_cmd=""
if [[ -f "$target/package.json" ]]; then
  # prefer npm test; user can change via npm scripts
  test_cmd="npm test"
elif [[ -f "$target/Cargo.toml" ]]; then
  test_cmd="cargo test"
elif [[ -f "$target/go.mod" ]]; then
  test_cmd="go test ./..."
elif [[ -f "$target/pytest.ini" ]] || [[ -f "$target/pyproject.toml" ]]; then
  test_cmd="pytest"
fi

# Create the session detached, with the first window running claude.
# No explicit -n name — automatic-rename-format turns it into the project
# dirname, which matches the other auto-named windows. The robot + status
# icon in the window-status-format already announces "claude is here."
tmux new-session -d -s "$session" -c "$target" "claude"

# Second window: plain shell in the project root
tmux new-window -t "$session:" -n "shell" -c "$target"

# Third window: test runner, if one was detected (not auto-run — land in shell
# at the project root so you can start/restart it intentionally)
if [[ -n "$test_cmd" ]]; then
  tmux new-window -t "$session:" -n "tests" -c "$target"
  tmux send-keys -t "$session:tests" "# ready: $test_cmd" ""
fi

# Focus window 1 (claude) on attach
tmux select-window -t "$session:1"

# Attach or switch
if [[ -n "${TMUX:-}" ]]; then
  tmux switch-client -t "$session"
else
  tmux attach-session -t "$session"
fi
