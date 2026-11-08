#!/usr/bin/env bash
# Run linkall.sh against a throwaway HOME and check how it links ~/.config/rex.
#
# The real repo is never a link source here: the sandbox HOME gets its own
# projects/dotfiles holding a copy of linkall.sh and an empty rex/, so nothing
# linkall.sh does can write through a link into this checkout. Commands with
# effects outside HOME (git config, launchctl) are stubbed, and PATH holds only
# the stubs and the system directories, so agent CLIs, herdr, brew and pipx are
# absent and their blocks skip.
set -euo pipefail

main() (
  local repo sandbox fake_home dotfiles
  repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
  sandbox=$(mktemp -d "${TMPDIR:-/tmp}/linkall-rex-test.XXXXXX")
  sandbox=$(cd -- "$sandbox" && pwd -P)
  trap 'rm -rf -- "$sandbox"' EXIT

  mkdir -p "$sandbox/bin"
  for stub in git launchctl; do
    printf '#!/bin/sh\nexit 0\n' >"$sandbox/bin/$stub"
    chmod +x "$sandbox/bin/$stub"
  done

  fresh_home() {
    fake_home="$sandbox/home-$1"
    dotfiles="$fake_home/projects/dotfiles"
    mkdir -p "$dotfiles/rex" "$fake_home/.ssh"
    cp "$repo/linkall.sh" "$dotfiles/linkall.sh"
  }

  run_linkall() {
    HOME="$fake_home" PATH="$sandbox/bin:/usr/bin:/bin" \
      sh "$dotfiles/linkall.sh" >"$sandbox/stdout" 2>"$sandbox/stderr" || true
  }

  fail() {
    printf 'FAIL: %s\n' "$*" >&2
    cat "$sandbox/stderr" >&2
    exit 1
  }

  expect_linked() {
    [[ -L "$fake_home/.config/rex" ]] || fail "$1: ~/.config/rex is not a symlink"
    [[ "$(readlink "$fake_home/.config/rex")" == "$fake_home/projects/dotfiles/rex" ]] \
      || fail "$1: ~/.config/rex points at $(readlink "$fake_home/.config/rex")"
    [[ ! -e "$dotfiles/rex/rex" && ! -L "$dotfiles/rex/rex" ]] \
      || fail "$1: a link was nested inside the repo's rex/"
  }

  # A fresh machine gets the directory link.
  fresh_home fresh
  run_linkall
  expect_linked "fresh HOME"

  # Re-running replaces the link rather than nesting a second one inside it.
  run_linkall
  expect_linked "second run"

  # A link to somewhere else is replaced.
  fresh_home stale
  mkdir -p "$fake_home/.config" "$sandbox/elsewhere"
  ln -s "$sandbox/elsewhere" "$fake_home/.config/rex"
  run_linkall
  expect_linked "stale link"
  [[ ! -e "$sandbox/elsewhere/rex" && ! -L "$sandbox/elsewhere/rex" ]] \
    || fail "stale link: a link was nested inside the old target"

  # A real directory is the live config: left exactly as it was, nothing nested
  # into it, and the skip is reported.
  fresh_home realdir
  mkdir -p "$fake_home/.config/rex/themes"
  printf 'rex.bind("cmd+k", "session.switch")\n' >"$fake_home/.config/rex/init.lua"
  printf 'theme\n' >"$fake_home/.config/rex/themes/Live.itermcolors"
  run_linkall
  [[ -d "$fake_home/.config/rex" && ! -L "$fake_home/.config/rex" ]] \
    || fail "real dir: ~/.config/rex was replaced"
  [[ "$(cat "$fake_home/.config/rex/init.lua")" == 'rex.bind("cmd+k", "session.switch")' ]] \
    || fail "real dir: init.lua changed"
  [[ -f "$fake_home/.config/rex/themes/Live.itermcolors" ]] || fail "real dir: theme removed"
  [[ ! -e "$fake_home/.config/rex/rex" && ! -L "$fake_home/.config/rex/rex" ]] \
    || fail "real dir: a link was nested inside it"
  grep -q 'skip: ~/.config/rex is a real directory' "$sandbox/stderr" \
    || fail "real dir: no skip message on stderr"

  echo "ok: linkall.sh links ~/.config/rex (4 cases)"
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
