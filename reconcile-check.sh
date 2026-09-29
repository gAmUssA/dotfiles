#!/usr/bin/env bash
# Read-only audit of an ALREADY configured machine against this repo.
#
# Run this before `linkall.sh` on a machine that has been in use. linkall.sh
# `rm -f`s every target before relinking, so a config that has drifted from a
# symlink into a regular file — which tmux-assistant-resurrect and Paseo have
# both done to claude/settings.json — is destroyed silently, with no backup and
# no diff. This finds those first.
#
# Writes nothing. Exits 1 if anything needs a human decision.
#
# Usage: ./reconcile-check.sh

set -uo pipefail

REPO="$HOME/projects/dotfiles"
drift=0

note()  { printf '  %s\n' "$*"; }
head2() { printf '\n== %s\n' "$*"; }

cd "$REPO" || { echo "No repo at $REPO"; exit 1; }

# ---------------------------------------------------------------- repo state
head2 "Repository"
git fetch --quiet origin 2>/dev/null || note "fetch failed (offline?) — comparisons may be stale"
branch=$(git rev-parse --abbrev-ref HEAD)
behind=$(git rev-list --count "HEAD..origin/$branch" 2>/dev/null || echo '?')
ahead=$(git rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo '?')
dirty=$(git status --porcelain | wc -l | tr -d ' ')
note "branch $branch — $behind behind, $ahead ahead, $dirty uncommitted"
[ "$dirty" != "0" ] && { note "UNCOMMITTED changes here; they are this machine's, not the repo's:"; git status --short | sed 's/^/    /'; drift=1; }
[ "$ahead" != "0" ] && [ "$ahead" != "?" ] && { note "UNPUSHED commits — push before reconciling elsewhere"; drift=1; }

# ------------------------------------------------------------- symlink drift
# Expected targets come from linkall.sh itself, so the two cannot diverge.
head2 "Config links (expected vs actual)"
ghostty_dir="$HOME/Library/Application Support/com.mitchellh.ghostty"

while IFS= read -r line; do
  target=${line#ln -s *dotfiles/}       # strip through the source path
  target=${target#* }                    # leave only the destination
  target=${target//\"/}
  target=${target/\$GHOSTTY_MACOS_DIR/$ghostty_dir}
  target=${target/#\~/$HOME}
  [ -z "$target" ] && continue

  if [ -L "$target" ]; then
    dest=$(readlink "$target")
    case "$dest" in
      "$REPO"/*|"$HOME/projects/dotfiles/"*) : ;;
      *) note "WRONG TARGET  ${target/#$HOME/\~}  ->  $dest"; drift=1 ;;
    esac
  elif [ -e "$target" ]; then
    note "REGULAR FILE  ${target/#$HOME/\~}  <- linkall.sh would DELETE this"
    drift=1
  else
    note "missing       ${target/#$HOME/\~}  (linkall.sh will create it)"
  fi
done < <(grep -E '^ln -s' linkall.sh)

# ------------------------------------------------------------------ Homebrew
head2 "Homebrew"
if command -v brew >/dev/null; then
  # Capture first, then match. `... | grep -q` under pipefail reports failure
  # even on a match, because grep exits at the first hit and the producer takes
  # SIGPIPE. That gotcha is in AGENTS.md and it bit this script once already.
  check_out=$(brew bundle check --file="$REPO/Brewfile" --verbose 2>/dev/null)
  if printf '%s' "$check_out" | grep -qi 'not installed'; then
    note "Brewfile has unsatisfied entries:"
    printf '%s\n' "$check_out" | grep -i 'not installed' | head -10 | sed 's/^/    /'
    note "run: brew bundle --file=Brewfile"
  else
    note "Brewfile satisfied"
  fi
  note "entries installed here but NOT in the Brewfile (brew bundle cleanup would remove):"
  cleanup=$(brew bundle cleanup --file="$REPO/Brewfile" 2>/dev/null | head -20)
  if [ -n "$cleanup" ]; then printf '%s\n' "$cleanup" | sed 's/^/    /'; drift=1; else note "  none"; fi
  note "NOTE: brew bundle ADDS but never REMOVES. Entries deleted from the"
  note "      Brewfile stay installed until you cleanup deliberately."
else
  note "brew not on PATH"
fi

# --------------------------------------------------------------------- herdr
head2 "herdr"
if command -v herdr >/dev/null; then
  note "$(herdr --version)"
  plugins=$(herdr plugin list 2>/dev/null)
  if printf '%s' "$plugins" | grep -q 'gamussa.notify'; then
    note "gamussa.notify present"
  else
    note "gamussa.notify MISSING — linkall.sh installs it; needs the server running"
    drift=1
  fi
else
  note "herdr not on PATH — install before linkall.sh (it installs the plugin)"
  drift=1
fi

# ------------------------------------------------------------------- verdict
head2 "Verdict"
if [ "$drift" -eq 0 ]; then
  note "No drift. linkall.sh is safe to re-run."
  exit 0
fi
note "Drift found. Do NOT run linkall.sh until each item above is resolved."
note "Never resolve drift by picking a side — diff both, union the changes,"
note "then relink. See AGENTS.md."
exit 1
