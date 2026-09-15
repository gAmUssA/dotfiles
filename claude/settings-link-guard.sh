#!/usr/bin/env bash
#
# Warn when ~/.claude/settings.json stops being a symlink into this repo.
#
# WHY: several tools write Claude's settings by replacing the file (tmp file +
# mv) rather than editing through the link. That silently converts the symlink
# into a regular file, after which the live config and the tracked copy drift
# apart with nothing to announce it. Seen twice already:
#   2026-09-08  tmux-assistant-resurrect  (added its session hooks)
#   2026-09-11  paseo                     (added 5 $PASEO_TERMINAL_ID hooks)
# Each time the repo kept serving a stale config to other machines while this
# one quietly diverged. githooks/pre-commit does not catch it — that guards
# secrets, not link integrity.
#
# Behavior, deliberately conservative:
#   symlink                      -> silent, exit 0
#   regular file, same as repo   -> relink silently (nothing to lose)
#   regular file, DIVERGED       -> warn, list what differs, change NOTHING
#
# It never auto-merges. The repo file is public and tracked; deciding which
# stray hooks belong in it is a judgement call, not something a startup hook
# should make. See the "keep machine-specific hooks out of the public repo"
# commit for the rule: absolute machine paths -> settings.local.json,
# $HOME-relative or PATH-resolved -> tracked.
#
# Runs as a SessionStart hook. Exits 0 always: a broken guard must never block
# a session from starting.

set -u

LIVE="$HOME/.claude/settings.json"
REPO="$HOME/projects/dotfiles/claude/settings.json"

[[ -L "$LIVE" ]] && exit 0          # healthy
[[ -e "$LIVE" ]] || exit 0          # nothing there; linkall.sh will create it
[[ -f "$REPO" ]] || exit 0          # repo missing; not our problem to guess

if command -v python3 >/dev/null 2>&1; then
  drift=$(python3 - "$LIVE" "$REPO" <<'PY' 2>/dev/null
import json, sys
def hooks(p):
    try: d = json.load(open(p))
    except Exception: return None
    return {(e, c.get("command", ""))
            for e, groups in d.get("hooks", {}).items()
            for g in groups for c in g.get("hooks", [])}
live, repo = hooks(sys.argv[1]), hooks(sys.argv[2])
if live is None or repo is None:
    print("UNREADABLE"); raise SystemExit
only_live = live - repo
for e, c in sorted(only_live):
    print(f"  live-only  {e}: {c[:88]}")
PY
)
else
  drift="  (python3 unavailable — cannot compare)"
fi

if [[ -z "$drift" ]]; then
  # Identical content: relinking loses nothing.
  ln -sfn "$REPO" "$LIVE" 2>/dev/null \
    && printf '\033[33m[settings-guard]\033[0m ~/.claude/settings.json was a plain file; relinked to the repo (content was identical).\n' >&2
  exit 0
fi

{
  printf '\033[33m[settings-guard] ~/.claude/settings.json is NO LONGER a symlink and has DIVERGED from the repo.\033[0m\n'
  printf 'Something rewrote it (Paseo and tmux-assistant-resurrect have both done this).\n'
  printf 'Hooks live here but missing from the tracked copy:\n%s\n' "$drift"
  printf 'Nothing was changed. To repair, merge what you want to keep into\n'
  printf '  %s\n' "$REPO"
  printf 'putting absolute machine paths in ~/.claude/settings.local.json instead, then:\n'
  printf '  ln -sfn "%s" "%s"\n' "$REPO" "$LIVE"
} >&2

exit 0
