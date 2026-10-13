#!/usr/bin/env bash
# Point every agent CLI's status line at the shared claude/statusline.sh.
#
# The configs edited here are per-machine files the repo does not track (they
# also hold trusted folders, tessl hooks with absolute paths, login state), so
# instead of linking them this sets one key in each and leaves the rest alone.
# Idempotent; a CLI that is not installed is skipped. Run by linkall.sh.
#
#   grok      ~/.grok/config.toml                     [ui.status_line] (added only if absent)
#   agy       ~/.gemini/antigravity-cli/settings.json .statusLine
#   copilot   ~/.copilot/settings.json                .statusLine
#   pi        ~/.pi/agent/extensions/statusline.ts -> pi/extensions/statusline.ts
#   opencode  ~/.config/opencode/plugins/dotfiles-statusline -> opencode/statusline/
#             (v2 auto-loads a plugin directory's tui entry; v1 is not supported)
#
# Claude Code's own statusLine is in the tracked claude/settings.json.
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/projects/dotfiles}"
# shellcheck disable=SC2088 # literal ~ on purpose: each CLI expands it, keeping its config portable
SCRIPT_TILDE="~/.claude/statusline.sh"

# Set .statusLine in a JSON settings file, creating the file if needed.
set_json_statusline() {
  local file=$1 value=$2 tmp
  mkdir -p "$(dirname "$file")"
  [[ -s "$file" ]] || echo '{}' > "$file"
  tmp=$(mktemp "${file}.XXXXXX")
  if ! jq --argjson v "$value" '.statusLine = $v' "$file" > "$tmp"; then
    rm -f "$tmp"
    echo "error: $file is not plain JSON — add statusLine by hand: $value" >&2
    return 1
  fi
  if cmp -s "$tmp" "$file"; then rm -f "$tmp"; echo "same    $file"; else mv "$tmp" "$file"; echo "set     $file"; fi
}

link() {
  local src=$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then echo "same    $dst"; return; fi
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    echo "error: $dst is a regular file — diff it against $src, then remove it and rerun" >&2
    return 1
  fi
  ln -sfn "$src" "$dst"
  echo "linked  $dst"
}

install_grok() {
  local cfg="$HOME/.grok/config.toml"
  touch "$cfg"
  if grep -q '^\[ui\.status_line\]' "$cfg"; then
    echo "same    $cfg (has [ui.status_line]; edit by hand to change it)"
    return
  fi
  printf '\n[ui.status_line]\ntype = "command"\ncommand = "%s"\nrefresh_interval = 30\n' "$SCRIPT_TILDE" >> "$cfg"
  echo "set     $cfg"
}

install_opencode() {
  link "$DOTFILES/opencode/statusline" "$HOME/.config/opencode/plugins/dotfiles-statusline"
}

main() {
  local failed=0
  if command -v grok >/dev/null 2>&1; then install_grok || failed=1; else echo "skip    grok (not installed)"; fi
  if command -v agy >/dev/null 2>&1; then
    set_json_statusline "$HOME/.gemini/antigravity-cli/settings.json" \
      "{\"type\":\"command\",\"command\":\"$SCRIPT_TILDE\"}" || failed=1
  else echo "skip    agy (not installed)"; fi
  if command -v copilot >/dev/null 2>&1; then
    set_json_statusline "$HOME/.copilot/settings.json" \
      "{\"type\":\"command\",\"command\":\"$SCRIPT_TILDE\",\"refreshInterval\":30}" || failed=1
  else echo "skip    copilot (not installed)"; fi
  if command -v pi >/dev/null 2>&1; then
    link "$DOTFILES/pi/extensions/statusline.ts" "$HOME/.pi/agent/extensions/statusline.ts" || failed=1
  else echo "skip    pi (not installed)"; fi
  if command -v opencode >/dev/null 2>&1; then install_opencode || failed=1; else echo "skip    opencode (not installed)"; fi
  echo "Restart running agents to pick up their status line."
  return "$failed"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
