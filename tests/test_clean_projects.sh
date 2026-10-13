#!/usr/bin/env bash
# Exercise the command boundary without touching real projects or caches.
set -euo pipefail

main() (
  local repo sandbox script status
  repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
  script="$repo/clean_projects.sh"
  sandbox=$(mktemp -d "${TMPDIR:-/tmp}/clean-projects-test.XXXXXX")
  sandbox=$(cd -- "$sandbox" && pwd -P)
  trap 'rm -rf -- "$sandbox"' EXIT
  mkdir -p "$sandbox/bin" "$sandbox/empty-bin" "$sandbox/project space" "$sandbox/-project"
  ln -s /bin/cat "$sandbox/empty-bin/cat"
  cat >"$sandbox/bin/kondo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == --help ]]; then
  printf '%s\n' "${KONDO_TEST_HELP:---dry-run}"
  exit 0
fi
printf '%s\0' "$@" > "$KONDO_TEST_ARGS"
if [[ -n "${KONDO_TEST_DIAGNOSTIC:-}" ]]; then
  printf '%s\n' "$KONDO_TEST_DIAGNOSTIC" >&2
fi
exit "${KONDO_TEST_EXIT:-0}"
EOF
  chmod +x "$sandbox/bin/kondo"
  export KONDO_TEST_ARGS="$sandbox/args"
  export PATH="$sandbox/bin:$PATH"

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

  expect_args() {
    printf '%s\0' "$@" >"$sandbox/expected"
    cmp "$sandbox/expected" "$sandbox/args"
  }

  (cd / && bash "$script")
  expect_args --same-filesystem --dry-run -- "$(cd "$HOME/projects" && pwd -P)"
  printf 'PASS: default preview uses ~/projects, independent of working directory\n'

  bash "$script" --older 3M --exclude "$sandbox/-project" "$sandbox/project space"
  expect_args --same-filesystem --older 3M --ignored-dirs "$sandbox/-project" --dry-run -- "$sandbox/project space"
  printf 'PASS: age, exclusion and paths with spaces reach Kondo intact\n'

  (cd "$sandbox" && bash "$script" -- -project)
  expect_args --same-filesystem --dry-run -- "$sandbox/-project"
  printf 'PASS: leading-hyphen directory is treated as a path\n'

  expect_status 2 bash "$script" "$sandbox/project space" "$sandbox/missing"
  [[ "$(cat "$sandbox/stderr")" == *'not a directory'* ]]
  expect_status 2 bash "$script" --exclude "$sandbox/missing" "$sandbox/project space"
  expect_status 2 bash "$script" --older
  expect_status 2 bash "$script" --exclude
  expect_status 2 bash "$script" --older yesterday
  expect_status 2 bash "$script" --all
  printf 'PASS: invalid roots, exclusions, ages and unattended deletion are rejected\n'

  expect_status 2 bash "$script" --apply "$sandbox/project space" </dev/null
  [[ "$(cat "$sandbox/stderr")" == *'requires terminal input'* ]]
  printf 'PASS: cleanup cannot run with redirected input\n'

  export KONDO_TEST_EXIT=37
  expect_status 37 bash "$script" "$sandbox/project space"
  unset KONDO_TEST_EXIT
  export KONDO_TEST_DIAGNOSTIC='error removing directory: permission denied'
  expect_status 1 bash "$script" "$sandbox/project space"
  [[ "$(cat "$sandbox/stderr")" == *'permission denied'* ]]
  unset KONDO_TEST_DIAGNOSTIC
  printf 'PASS: Kondo failures and diagnostics cannot become false success\n'

  export KONDO_TEST_HELP='Kondo without preview support'
  expect_status 1 bash "$script" "$sandbox/project space"
  [[ "$(cat "$sandbox/stderr")" == *'brew upgrade kondo'* ]]
  unset KONDO_TEST_HELP
  expect_status 127 env PATH="$sandbox/empty-bin" /bin/bash "$script" "$sandbox/project space"
  [[ "$(cat "$sandbox/stderr")" == *'brew install kondo'* ]]
  expect_status 0 env PATH="$sandbox/empty-bin" /bin/bash "$script" --help
  printf 'PASS: missing or old Kondo gives an actionable error; help needs no dependency\n'
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
