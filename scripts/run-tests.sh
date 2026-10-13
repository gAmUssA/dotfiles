#!/usr/bin/env bash
set -euo pipefail

main() {
  local repo harness
  repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
  for harness in "$repo"/tests/test_*.sh; do
    bash "$harness"
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
