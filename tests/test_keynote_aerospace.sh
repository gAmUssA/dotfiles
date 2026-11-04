#!/usr/bin/env bash
set -euo pipefail

main() {
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
  lua tests/test_keynote_aerospace.lua
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
