#!/usr/bin/env bash
# macOS-native plist tooling; all copy/restore operations use temporary files.
set -euo pipefail

main() (
  local repo sandbox bundle helper preferences status digest
  repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
  sandbox=$(mktemp -d "${TMPDIR:-/tmp}/keyboard-layouts-test.XXXXXX")
  sandbox=$(cd -- "$sandbox" && pwd -P)
  trap 'rm -rf -- "$sandbox"' EXIT
  mkdir -p "$sandbox/repo" "$sandbox/installed/Custom.bundle/Contents/Resources"
  cp "$repo/keyboard-layouts.sh" "$sandbox/repo/keyboard-layouts.sh"
  helper="$sandbox/repo/keyboard-layouts.sh"
  bundle="$sandbox/installed/Custom.bundle"
  preferences="$sandbox/input-sources.plist"
  cat >"$bundle/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>example.keyboard.custom</string>
</dict></plist>
EOF
  # Legacy controls must survive byte-for-byte, without XML normalization.
  printf '<?xml version="1.1"?><keyboard id="-1088"><key code="0" output="&#x001B;"/></keyboard>\n' >"$bundle/Contents/Resources/English - Ilya Birman Typography.keylayout"
  printf '<?xml version="1.0"?><keyboard id="-20914"><key code="0" output="ф"/></keyboard>\n' >"$bundle/Contents/Resources/Russian - Ilya Birman Typography.keylayout"
  printf 'Finder state\n' >"$bundle/.DS_Store"
  printf 'resource fork\n' >"$bundle/._metadata"
  cat >"$preferences" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>AppleEnabledInputSources</key><array><dict>
<key>KeyboardLayout ID</key><integer>-1088</integer>
<key>KeyboardLayout Name</key><string>English - Ilya Birman Typography</string>
</dict></array>
<key>AppleSelectedInputSources</key><array><dict>
<key>KeyboardLayout ID</key><integer>-1088</integer>
</dict></array>
<key>AppleCurrentKeyboardLayoutInputSourceID</key><string>example.keyboard.custom.english</string>
<key>AppleInputSourceHistory</key><array><string>volatile history</string></array>
<key>FutureMachineState</key><data>cHJpdmF0ZSBmaXh0dXJl</data>
</dict></plist>
EOF

  expect_status() {
    local expected=$1
    shift
    if "$@" >"$sandbox/stdout" 2>"$sandbox/stderr"; then
      status=0
    else
      status=$?
    fi
    if [[ "$status" -ne "$expected" ]]; then
      cat "$sandbox/stdout" "$sandbox/stderr" >&2
      printf 'FAIL: expected exit %s, got %s\n' "$expected" "$status" >&2
      return 1
    fi
  }

  bash "$helper" backup --source "$bundle" --preferences "$preferences"
  bash "$helper" check --source "$bundle"
  [[ ! -e "$sandbox/repo/keyboard-layouts/Ilya Birman Typography Layout.bundle/.DS_Store" ]]
  [[ ! -e "$sandbox/repo/keyboard-layouts/Ilya Birman Typography Layout.bundle/._metadata" ]]
  cmp "$bundle/Contents/Resources/English - Ilya Birman Typography.keylayout" \
    "$sandbox/repo/keyboard-layouts/Ilya Birman Typography Layout.bundle/Contents/Resources/English - Ilya Birman Typography.keylayout"
  digest=$(shasum -a 256 "$sandbox/repo/prefs/com.apple.HIToolbox.plist")
  bash "$helper" backup --source "$bundle" --preferences "$preferences"
  [[ "$digest" == "$(shasum -a 256 "$sandbox/repo/prefs/com.apple.HIToolbox.plist")" ]]
  printf 'PASS: backup is idempotent, preserves legacy layout bytes and omits Finder files\n'

  plutil -lint "$sandbox/repo/prefs/com.apple.HIToolbox.plist" >/dev/null
  [[ "$(plutil -extract AppleCurrentKeyboardLayoutInputSourceID raw -o - "$sandbox/repo/prefs/com.apple.HIToolbox.plist")" == example.keyboard.custom.english ]]
  [[ "$(cat "$sandbox/repo/prefs/com.apple.HIToolbox.plist")" != *FutureMachineState* ]]
  [[ "$(cat "$sandbox/repo/prefs/com.apple.HIToolbox.plist")" != *AppleInputSourceHistory* ]]
  printf 'PASS: input-source snapshot keeps only portable allowlisted fields\n'

  bash "$helper" restore --destination "$sandbox/restored layouts" --dry-run
  [[ ! -e "$sandbox/restored layouts" ]]
  bash "$helper" restore --destination "$sandbox/restored layouts"
  bash "$helper" check --source "$sandbox/restored layouts/Ilya Birman Typography Layout.bundle"
  mkdir -p "$sandbox/restored layouts/Unrelated.bundle"
  printf 'keep\n' >"$sandbox/restored layouts/Unrelated.bundle/source"
  printf 'local edit\n' >"$sandbox/restored layouts/Ilya Birman Typography Layout.bundle/Contents/local-only"
  expect_status 1 bash "$helper" check --source "$sandbox/restored layouts/Ilya Birman Typography Layout.bundle"
  bash "$helper" restore --destination "$sandbox/restored layouts"
  [[ -f "$sandbox/restored layouts/Unrelated.bundle/source" ]]
  [[ -n "$(find "$sandbox/restored layouts" -path '*/.birman-backup.*/Ilya Birman Typography Layout.bundle/Contents/local-only' -print)" ]]
  bash "$helper" check --source "$sandbox/restored layouts/Ilya Birman Typography Layout.bundle"
  printf 'PASS: preview writes nothing; restore preserves differing copies and unrelated bundles\n'

  ln -s "$bundle/Contents/Info.plist" "$bundle/Contents/linked.plist"
  expect_status 1 bash "$helper" backup --source "$bundle" --preferences "$preferences"
  [[ "$(cat "$sandbox/stderr")" == *'contains symlinks'* ]]
  rm "$bundle/Contents/linked.plist"
  mkdir -p "$sandbox/symlink destination"
  ln -s "$bundle" "$sandbox/symlink destination/Ilya Birman Typography Layout.bundle"
  expect_status 1 bash "$helper" restore --destination "$sandbox/symlink destination"
  [[ -L "$sandbox/symlink destination/Ilya Birman Typography Layout.bundle" ]]
  expect_status 1 bash "$helper" backup --source "$sandbox/missing" --preferences "$preferences"
  expect_status 2 bash "$helper" backup --source
  expect_status 2 bash "$helper" check --preferences "$preferences"
  expect_status 2 bash "$helper" restore --source "$bundle"
  expect_status 2 bash "$helper" backup --dry-run
  printf 'PASS: symlink sources/destinations and invalid action options fail safely\n'

  # Exercise prefs-restore's OS command boundary without importing real prefs.
  mkdir -p "$sandbox/orchestration/prefs" "$sandbox/bin"
  cp "$repo/prefs-restore.sh" "$sandbox/orchestration/prefs-restore.sh"
  cp "$sandbox/repo/prefs/com.apple.HIToolbox.plist" "$sandbox/orchestration/prefs/"
  cat >"$sandbox/orchestration/keyboard-layouts.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${KEYBOARD_TEST_RESTORE_EXIT:-0}" -ne 0 ]]; then
  exit "$KEYBOARD_TEST_RESTORE_EXIT"
fi
printf 'installed\n' > "$KEYBOARD_TEST_MARKER"
EOF
  cat >"$sandbox/bin/defaults" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == domains ]]; then
  printf '\n'
  exit 0
fi
if [[ "$1" != import || ! -f "$KEYBOARD_TEST_MARKER" ]]; then
  printf 'error: input-source import ran before bundle installation\n' >&2
  exit 73
fi
printf 'imported\n' > "$KEYBOARD_TEST_IMPORT"
exit "${KEYBOARD_TEST_IMPORT_EXIT:-0}"
EOF
  chmod +x "$sandbox/orchestration/keyboard-layouts.sh" "$sandbox/bin/defaults"
  export KEYBOARD_TEST_MARKER="$sandbox/restore-marker"
  export KEYBOARD_TEST_IMPORT="$sandbox/import-marker"
  export PATH="$sandbox/bin:$PATH"
  expect_status 0 bash "$sandbox/orchestration/prefs-restore.sh"
  [[ -f "$KEYBOARD_TEST_IMPORT" ]]
  rm "$KEYBOARD_TEST_MARKER" "$KEYBOARD_TEST_IMPORT"
  export KEYBOARD_TEST_RESTORE_EXIT=31
  expect_status 1 bash "$sandbox/orchestration/prefs-restore.sh"
  [[ ! -e "$KEYBOARD_TEST_IMPORT" ]]
  unset KEYBOARD_TEST_RESTORE_EXIT
  export KEYBOARD_TEST_IMPORT_EXIT=49
  expect_status 1 bash "$sandbox/orchestration/prefs-restore.sh"
  printf 'PASS: preferences import follows bundle installation and reports either failure\n'

  cp "$repo/prefs-backup.sh" "$sandbox/orchestration/prefs-backup.sh"
  # defaults reports no app domains; these process stubs also prevent copying
  # any real PopClip files or consulting a real Git checkout during the test.
  printf '#!/bin/sh\nexit 0\n' >"$sandbox/bin/rsync"
  printf '#!/bin/sh\nexit 0\n' >"$sandbox/bin/git"
  chmod +x "$sandbox/bin/rsync" "$sandbox/bin/git"
  rm "$KEYBOARD_TEST_MARKER"
  expect_status 0 bash "$sandbox/orchestration/prefs-backup.sh"
  [[ -f "$KEYBOARD_TEST_MARKER" ]]
  export KEYBOARD_TEST_RESTORE_EXIT=31
  expect_status 1 bash "$sandbox/orchestration/prefs-backup.sh"
  [[ "$(cat "$sandbox/stderr")" == *'Birman backup'* ]]
  printf 'PASS: preference backup includes the keyboard snapshot and reports failures\n'
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
