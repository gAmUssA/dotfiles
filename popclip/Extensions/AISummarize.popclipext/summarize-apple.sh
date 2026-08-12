#!/bin/bash
#
# PopClip action: summarize the selection on-device, then present the result.
#
set -euo pipefail

EXT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "${EXT_DIR}/lib.sh"

# Kept as separate assignments: a failing command substitution nested in an
# argument would not trip `set -e`, and the engine would run with no binary.
engine="$(build_cached "${EXT_DIR}/apple-intelligence.swift")"
summary="$(run_engine "$engine")"
deliver "Apple Intelligence" "$summary"
