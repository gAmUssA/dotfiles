#!/usr/bin/env bash
#
# Updates iTerm2 profiles that reference old Nerd Fonts "Complete" builds
# (which strip ligatures) to v3+ Nerd Font PostScript names that keep them.
#
# Requires iTerm2 to be fully quit — otherwise iTerm2's in-memory prefs get
# flushed to disk on quit and overwrite these edits.

set -euo pipefail

PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
PB=/usr/libexec/PlistBuddy

if pgrep -x iTerm2 >/dev/null; then
  echo "iTerm2 is running. Cmd+Q it fully, then re-run this script." >&2
  exit 1
fi

if [[ ! -f "$PLIST" ]]; then
  echo "iTerm2 plist not found at $PLIST" >&2
  exit 1
fi

# cfprefsd caches the plist in memory. Kill it so our edits are the source of truth.
killall cfprefsd 2>/dev/null || true

BACKUP="$PLIST.bak.$(date +%Y%m%d-%H%M%S)"
cp "$PLIST" "$BACKUP"
echo "Backup: $BACKUP"

# All profiles → IosevkaTerm NF (v3+ PostScript: IosevkaTermNF-<Style>).
# Sizes are preserved from each profile's current setting.
declare -a REPLACEMENTS=(
  "M+1CodeNFM-Reg|IosevkaTermNF"
  "Menlo-Regular|IosevkaTermNF"
  "Iosevka-Term-Light|IosevkaTermNF-Light"
  "IosevkaNerdFontCompleteM-Light|IosevkaTermNF-Light"
  "IosevkaNerdFontCompleteM-|IosevkaTermNF"
  "IosevkaTermNF-Regular|IosevkaTermNF"
  "JetBrainsMonoNF-Regular|IosevkaTermNF"
  "JetBrainsMonoNF-ExtraLight|IosevkaTermNF-ExtraLight"
  "JetBrainsMonoNerdFontCompleteM-ExtraLight|IosevkaTermNF-ExtraLight"
  "JetBrainsMonoNerdFontCompleteM-|IosevkaTermNF"
)

count=$($PB -c "Print :'New Bookmarks'" "$PLIST" | grep -c "^    Dict {" || true)
echo "Scanning $count profiles…"

for ((i=0; i<count; i++)); do
  name=$($PB -c "Print :'New Bookmarks':$i:Name" "$PLIST" 2>/dev/null || echo "?")
  font=$($PB -c "Print :'New Bookmarks':$i:'Normal Font'" "$PLIST" 2>/dev/null || echo "")
  [[ -z "$font" ]] && continue

  # Split "FontName SIZE" — size is the last whitespace-separated token.
  size="${font##* }"
  ps="${font% *}"

  new_ps=""
  for rule in "${REPLACEMENTS[@]}"; do
    from="${rule%%|*}"
    to="${rule##*|}"
    if [[ "$ps" == "$from" ]]; then
      new_ps="$to"
      break
    fi
  done

  if [[ -n "$new_ps" ]]; then
    $PB -c "Set :'New Bookmarks':$i:'Normal Font' '$new_ps $size'" "$PLIST"
    $PB -c "Set :'New Bookmarks':$i:'ASCII Ligatures' true" "$PLIST" 2>/dev/null \
      || $PB -c "Add :'New Bookmarks':$i:'ASCII Ligatures' bool true" "$PLIST"
    $PB -c "Set :'New Bookmarks':$i:'Non-ASCII Ligatures' true" "$PLIST" 2>/dev/null \
      || $PB -c "Add :'New Bookmarks':$i:'Non-ASCII Ligatures' bool true" "$PLIST"
    echo "  [$i] $name: $ps -> $new_ps"
  else
    echo "  [$i] $name: $ps (skipped)"
  fi
done

# Bump cfprefsd again so the next iTerm2 launch reads the fresh plist.
killall cfprefsd 2>/dev/null || true

echo "Done. Launch iTerm2 and open a new window to see the change."
echo "If a font doesn't appear, run: brew bundle --file=$HOME/projects/dotfiles/Brewfile"
