#!/usr/bin/env bash
# githooks/pre-commit secret scan, against staged files in a throwaway repo.
# OP_KEYCHAIN_SERVICE points at a service that does not exist, so the
# live-value check finds nothing and only the patterns are exercised.
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

main() (
  local repo sandbox
  repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
  sandbox=$(mktemp -d "${TMPDIR:-/tmp}/pre-commit-test.XXXXXX")
  trap 'rm -rf -- "$sandbox"' EXIT
  git -C "$sandbox" init -q

  # Stage one file with $1 as content; succeed iff the hook accepts it.
  scan() {
    printf '%s\n' "$1" >"$sandbox/config.json"
    git -C "$sandbox" add config.json
    (cd "$sandbox" && OP_KEYCHAIN_SERVICE=pre-commit-test-none python3 "$repo/githooks/pre-commit") 2>/dev/null
  }

  # A literal key is refused. Assembled at runtime so this file itself
  # does not trip the hook it tests.
  local literal
  literal=$(printf 'sk-proj-%s' 4f9a8b7c6d5e4f3a2b1c)
  if scan "{\"apiKey\": \"$literal\"}"; then fail "literal apiKey accepted"; fi
  printf 'PASS: a literal apiKey is refused\n'

  # References to a value elsewhere pass: shell, 1Password, OpenCode.
  local ref
  # shellcheck disable=SC2016 # the literal ${VAR} is the reference under test
  for ref in '${REC_API_KEY}' 'op://Private/rec/credential' '{env:REC_API_KEY}' '{file:~/.secrets/rec}'; do
    scan "{\"apiKey\": \"$ref\"}" || fail "reference refused: $ref"
  done
  # shellcheck disable=SC2016 # literal text
  printf 'PASS: ${VAR}, op://, {env:VAR} and {file:path} references are accepted\n'
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
