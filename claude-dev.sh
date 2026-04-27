#!/usr/bin/env bash
#
# claude-dev.sh — spawn a tmux session for Claude Code work on a project.
#
# Usage:
#   claude-dev.sh [directory]        # defaults to $PWD
#   claude-dev.sh ~/projects/api     # session name = "api"
#
# Layout:
#   Window 1 (claude) — runs `claude --dangerously-skip-permissions` (yolo)
#                       in the project directory
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

# Create the session detached, with the first window running claude in
# yolo mode (--dangerously-skip-permissions). The literal flag is used
# rather than the `yolo` zsh alias because tmux execs the command directly
# without going through an interactive shell — interactive aliases don't
# resolve in that context.
#
# No explicit -n name — automatic-rename-format turns it into the project
# dirname, which matches the other auto-named windows. The robot + status
# icon in the window-status-format already announces "claude is here."
tmux new-session -d -s "$session" -c "$target" "claude --dangerously-skip-permissions"

# Second window: plain shell in the project root
tmux new-window -t "$session:" -n "shell" -c "$target"

# Third window: test runner, if one was detected (not auto-run — pre-type the
# command into the prompt so you hit Enter to start it intentionally).
# Previous version sent "# ready: $test_cmd" + an empty arg, which (a) didn't
# press Enter so the line stayed parked in the buffer, and (b) wouldn't have
# parsed anyway because interactive_comments isn't active in this zsh setup.
if [[ -n "$test_cmd" ]]; then
  tmux new-window -t "$session:" -n "tests" -c "$target"
  tmux send-keys -t "$session:tests" "$test_cmd"
fi

# Focus window 1 (claude) on attach
tmux select-window -t "$session:1"

# Attach or switch
if [[ -n "${TMUX:-}" ]]; then
  tmux switch-client -t "$session"
else
  tmux attach-session -t "$session"
fi
