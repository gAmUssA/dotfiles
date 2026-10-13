#!/usr/bin/env bash
# Snapshot the installed, customized Birman bundle, not a stock download.
set -euo pipefail

keyboard_layouts_usage() {
  cat <<'EOF'
Usage: keyboard-layouts.sh backup|check|restore [OPTIONS]

  backup    Copy the installed EN/RU bundle and portable input-source preferences
            into dotfiles. Review the Git diff before committing.
  check     Compare the installed bundle with the snapshot, without changing it.
  restore   Install the snapshot; preserve a differing installation in a backup.

Options:
  --source BUNDLE       Installed/edited bundle to back up or compare.
  --preferences PLIST   Read input-source preferences from a file (backup only).
  --destination DIR     Restore into this Keyboard Layouts directory.
  --system              Restore into /Library/Keyboard Layouts.
  --dry-run             Preview a restore without writing anything.
  --help, -h            Show this help.

Restore updates the existing user/system installation when there is one;
otherwise it uses ~/Library/Keyboard Layouts. It never creates a second copy
at the other standard location or changes the active input source itself.
System-wide changes may require running restore --system with sudo yourself.
After restoring, log out and back in before selecting the layouts.
EOF
}

keyboard_layouts_installed() {
  local name=$1 user_bundle system_bundle
  user_bundle="$HOME/Library/Keyboard Layouts/$name"
  system_bundle="/Library/Keyboard Layouts/$name"
  if [[ -e "$user_bundle" && -e "$system_bundle" ]]; then
    printf 'error: Birman is installed in both user and system folders; reconcile the copies first\n' >&2
    return 2
  elif [[ -e "$user_bundle" ]]; then
    printf '%s\n' "$user_bundle"
  elif [[ -e "$system_bundle" ]]; then
    printf '%s\n' "$system_bundle"
  else
    return 1
  fi
}

keyboard_layouts_validate() {
  local bundle=$1 layout links
  if [[ ! -d "$bundle" || -L "$bundle" ]]; then
    printf 'error: expected a real keyboard bundle directory at %s\n' "$bundle" >&2
    return 1
  fi
  links=$(find "$bundle" -type l -print)
  if [[ -n "$links" ]]; then
    printf 'error: keyboard bundle contains symlinks; replace them with actual resources before copying\n' >&2
    return 1
  fi
  plutil -lint "$bundle/Contents/Info.plist" >/dev/null
  for layout in English Russian; do
    if [[ ! -s "$bundle/Contents/Resources/$layout - Ilya Birman Typography.keylayout" ]]; then
      printf 'error: missing %s Birman layout in %s\n' "$layout" "$bundle" >&2
      return 1
    fi
  done
  # Do not normalize the layout XML: macOS accepts legacy control-character
  # references and XML 1.1 that ordinary XML validators reject.
}

keyboard_layouts_same() {
  local status
  if diff -qr -x .DS_Store -x '._*' "$1" "$2" >/dev/null; then
    return 0
  else
    status=$?
    if [[ "$status" -ne 1 ]]; then
      printf 'error: keyboard bundle comparison failed\n' >&2
    fi
    return "$status"
  fi
}

keyboard_layouts_copy() {
  # No -a/-X/-E: copy data and timestamps, not Finder metadata, ACLs or xattrs.
  rsync -rt --delete --exclude .DS_Store --exclude '._*' "$1/" "$2/"
}

keyboard_layouts_destination() {
  local destination=$1 parent
  if [[ -d "$destination" ]]; then
    (cd -- "$destination" && pwd -P)
  else
    parent=$(dirname -- "$destination")
    if [[ ! -d "$parent" ]]; then
      printf 'error: create the parent directory %s before restoring\n' "$parent" >&2
      return 1
    fi
    printf '%s/%s\n' "$(cd -- "$parent" && pwd -P)" "$(basename -- "$destination")"
  fi
}

keyboard_layouts_replace() {
  local staged=$1 target=$2 parent backup
  parent=$(dirname -- "$target")
  if [[ -L "$target" || ( -e "$target" && ! -d "$target" ) ]]; then
    printf 'error: refusing to replace a symlink or file at %s; reconcile it first\n' "$target" >&2
    return 1
  fi
  if [[ -d "$target" ]]; then
    if keyboard_layouts_same "$staged" "$target"; then
      printf 'Already current: %s\n' "$target"
      return 0
    else
      local status=$?
      [[ "$status" -eq 1 ]] || return "$status"
    fi
    backup=$(mktemp -d "$parent/.birman-backup.XXXXXX")
    mv -- "$target" "$backup/"
    printf 'Previous bundle preserved in: %s\n' "$backup"
  fi
  mv -- "$staged" "$target"
  printf 'Copied: %s\n' "$target"
}

keyboard_layouts_main() (
  local action=${1:-} source='' preferences='' destination='' dry_run=0
  local here name snapshot installed status stage='' key fragment
  here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
  name='Ilya Birman Typography Layout.bundle'
  snapshot="$here/keyboard-layouts/$name"
  case "$action" in
    --help | -h) keyboard_layouts_usage; return 0 ;;
    backup | check | restore) shift ;;
    *) keyboard_layouts_usage >&2; return 2 ;;
  esac
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help | -h) keyboard_layouts_usage; return 0 ;;
      --source | --preferences | --destination)
        if [[ "$#" -lt 2 || -z "$2" || "$2" == --* ]]; then
          printf 'error: %s requires a path; see --help\n' "$1" >&2
          return 2
        fi
        case "$1" in
          --source) source=$2 ;;
          --preferences) preferences=$2 ;;
          --destination) destination=$2 ;;
        esac
        shift
        ;;
      --system) destination='/Library/Keyboard Layouts' ;;
      --dry-run) dry_run=1 ;;
      *) printf 'error: unknown option %s; see --help\n' "$1" >&2; return 2 ;;
    esac
    shift
  done
  if [[ "$action" != restore && ( -n "$destination" || "$dry_run" -eq 1 ) ]] ||
     [[ "$action" != backup && -n "$preferences" ]] ||
     [[ "$action" == restore && -n "$source" ]]; then
    printf 'error: options do not match the selected action; see --help\n' >&2
    return 2
  fi
  trap 'if [[ -n "$stage" ]]; then rm -rf -- "$stage"; fi' EXIT

  if [[ "$action" != restore ]]; then
    if [[ -z "$source" ]]; then
      if source=$(keyboard_layouts_installed "$name"); then
        :
      else
        status=$?
        printf 'error: select the installed bundle with --source BUNDLE\n' >&2
        return "$status"
      fi
    fi
    keyboard_layouts_validate "$source"
    if [[ "$action" == check ]]; then
      keyboard_layouts_validate "$snapshot"
      if keyboard_layouts_same "$source" "$snapshot"; then
        printf 'PASS: installed Birman bundle matches dotfiles byte-for-byte\n'
        return 0
      else
        status=$?
        printf 'Bundle differs; review both copies before backing up or restoring\n' >&2
        return "$status"
      fi
    fi

    mkdir -p "$here/keyboard-layouts" "$here/prefs"
    stage=$(mktemp -d "$here/keyboard-layouts/.snapshot.XXXXXX")
    keyboard_layouts_copy "$source" "$stage/$name"
    if [[ -z "$preferences" ]]; then
      preferences="$stage/raw-input-sources.plist"
      defaults export com.apple.HIToolbox "$preferences"
    fi
    plutil -lint "$preferences" >/dev/null
    plutil -create xml1 "$stage/input-sources.plist"
    # Keep only portable selection state; omit histories, timestamps and any
    # future top-level machine state introduced by macOS.
    for key in AppleEnabledInputSources AppleSelectedInputSources AppleCurrentKeyboardLayoutInputSourceID; do
      fragment=$(plutil -extract "$key" xml1 -o - "$preferences")
      plutil -insert "$key" -xml "$fragment" "$stage/input-sources.plist"
    done
    keyboard_layouts_replace "$stage/$name" "$snapshot"
    mv -- "$stage/input-sources.plist" "$here/prefs/com.apple.HIToolbox.plist"
    printf 'Copied portable input sources: prefs/com.apple.HIToolbox.plist\n'
    printf 'Review: git diff -- keyboard-layouts prefs/com.apple.HIToolbox.plist\n'
    return 0
  fi

  keyboard_layouts_validate "$snapshot"
  if [[ -z "$destination" ]]; then
    if installed=$(keyboard_layouts_installed "$name"); then
      destination=$(dirname -- "$installed")
    else
      status=$?
      [[ "$status" -eq 1 ]] || return "$status"
      destination="$HOME/Library/Keyboard Layouts"
    fi
  fi
  destination=$(keyboard_layouts_destination "$destination")
  # Prevent two standard installations with the same bundle/layout IDs.
  if [[ "$destination" == "$HOME/Library/Keyboard Layouts" && -e "/Library/Keyboard Layouts/$name" ]] ||
     [[ "$destination" == '/Library/Keyboard Layouts' && -e "$HOME/Library/Keyboard Layouts/$name" ]]; then
    printf 'error: another standard Birman installation exists; reconcile the copies before restoring\n' >&2
    return 1
  fi
  if [[ -d "$destination/$name" && ! -L "$destination/$name" ]]; then
    if keyboard_layouts_same "$snapshot" "$destination/$name"; then
      printf 'Already current: %s/%s\n' "$destination" "$name"
      return 0
    else
      status=$?
      [[ "$status" -eq 1 ]] || return "$status"
    fi
  fi
  if [[ "$dry_run" -eq 1 ]]; then
    printf 'Would copy %s to %s/%s; preserve any existing bundle first\n' "$snapshot" "$destination" "$name"
    return 0
  fi
  if [[ "$destination" == '/Library/Keyboard Layouts' && ! -w "$destination" ]]; then
    printf 'error: system layout folder needs administrator access; run sudo ./keyboard-layouts.sh restore --system yourself\n' >&2
    return 1
  fi
  mkdir -p "$destination"
  stage=$(mktemp -d "$destination/.birman-restore.XXXXXX")
  keyboard_layouts_copy "$snapshot" "$stage/$name"
  keyboard_layouts_replace "$stage/$name" "$destination/$name"
  printf 'Log out and back in, then select English/Russian - Ilya Birman Typography.\n'
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  keyboard_layouts_main "$@"
fi
