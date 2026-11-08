#!/usr/bin/env bash
# Run reconcile-check.sh against a throwaway HOME. The expected targets come
# from this checkout's linkall.sh, copied into the sandbox repo. git and herdr
# are stubbed and brew is absent, so the only drift a case can produce is its
# own; every other target is "missing", which is not drift.
#
# Each case runs under /bin/bash (3.2, what `env bash` finds before Homebrew is
# on PATH) and under the bash running this test.
set -euo pipefail

main() (
  local repo sandbox fake_home status shell
  repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
  sandbox=$(mktemp -d "${TMPDIR:-/tmp}/reconcile-check-test.XXXXXX")
  sandbox=$(cd -- "$sandbox" && pwd -P)
  trap 'rm -rf -- "$sandbox"' EXIT

  mkdir -p "$sandbox/bin"
  cat >"$sandbox/bin/git" <<'STUB'
#!/bin/sh
# Clean, in-sync checkout on main.
case "$1" in
  rev-parse) echo main ;;
  rev-list) echo 0 ;;
esac
exit 0
STUB
  cat >"$sandbox/bin/herdr" <<'STUB'
#!/bin/sh
case "$1" in
  --version) echo "herdr 0.0.0-test" ;;
  plugin) echo "gamussa.notify  enabled" ;;
esac
exit 0
STUB
  chmod +x "$sandbox/bin/git" "$sandbox/bin/herdr"

  fresh_home() {
    fake_home="$sandbox/home-$1"
    rm -rf -- "$fake_home"
    mkdir -p "$fake_home/projects/dotfiles/rex" "$fake_home/.config"
    cp "$repo/linkall.sh" "$fake_home/projects/dotfiles/linkall.sh"
  }

  run_check() {
    if HOME="$fake_home" PATH="$sandbox/bin:/usr/bin:/bin" \
      "$shell" "$repo/reconcile-check.sh" >"$sandbox/out" 2>&1; then
      status=0
    else
      status=$?
    fi
  }

  fail() {
    printf 'FAIL (%s): %s\n' "$shell" "$*" >&2
    cat "$sandbox/out" >&2
    exit 1
  }

  has() { grep -qF -- "$1" "$sandbox/out"; }

  cases() {
    # Paths print with a bare ~, never \~.
    fresh_home tilde
    run_check
    [[ "$status" -eq 0 ]] || fail "tilde: expected exit 0, got $status"
    has 'missing       ~/.config/cmux/settings.json' || fail "tilde: cmux target not listed as ~/..."
    if has '\~'; then fail "tilde: a path printed as \\~"; fi

    # Rejected: a real directory at ~/.config/rex — this machine's state today.
    fresh_home realdir
    mkdir -p "$fake_home/.config/rex/themes"
    printf 'rex.bind("cmd+k", "session.switch")\n' >"$fake_home/.config/rex/init.lua"
    run_check
    [[ "$status" -eq 1 ]] || fail "real dir: expected exit 1, got $status"
    has 'REAL DIRECTORY  ~/.config/rex' || fail "real dir: not reported"

    # Rejected: a link to somewhere other than the repo.
    fresh_home wrong
    ln -s "$sandbox/elsewhere" "$fake_home/.config/rex"
    run_check
    [[ "$status" -eq 1 ]] || fail "wrong link: expected exit 1, got $status"
    has 'WRONG TARGET  ~/.config/rex' || fail "wrong link: not reported"

    # Accepted: the link linkall.sh makes.
    fresh_home linked
    ln -s "$fake_home/projects/dotfiles/rex" "$fake_home/.config/rex"
    run_check
    [[ "$status" -eq 0 ]] || fail "linked: expected exit 0, got $status"
    if has 'config/rex'; then fail "linked: ~/.config/rex reported"; fi

    # Accepted: nothing there yet; linkall.sh will create it.
    fresh_home missing
    run_check
    [[ "$status" -eq 0 ]] || fail "missing: expected exit 0, got $status"
    has 'missing       ~/.config/rex' || fail "missing: not listed"
  }

  for shell in /bin/bash "$BASH"; do
    cases
  done
  echo "ok: reconcile-check.sh (/bin/bash and $BASH)"
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
