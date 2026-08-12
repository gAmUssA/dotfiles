#!/bin/bash
#
# PopClip action: summarize the selection with Claude, then present the result.
#
set -euo pipefail

EXT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "${EXT_DIR}/lib.sh"

model="${POPCLIP_OPTION_CUSTOMMODEL:-}"
[[ -n "$model" ]] || model="${POPCLIP_OPTION_MODEL:-claude-haiku-4-5}"

# Kept as separate assignments: a failing command substitution nested in an
# argument would not trip `set -e`, and the engine would run with no binary.
engine="$(build_cached "${EXT_DIR}/claude-summarize.swift")"
summary="$(run_engine "$engine")"
deliver "Claude · ${model}" "$summary"
