#!/usr/bin/env bash
# Kondo owns project detection and deletion; this wrapper defaults to preview.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: clean_projects.sh [OPTIONS] [DIRECTORY ...]

Preview project dependencies and build artifacts with Kondo (0.9 or newer).
Without DIRECTORY, scan ~/projects regardless of the current directory.

Options:
  --dry-run         Preview only (the default).
  --apply           Ask Kondo which projects to clean; requires terminal input.
  --older AGE       Consider projects unchanged for AGE, e.g. 30d or 3M.
  --exclude DIR     Skip projects under DIR; repeat for additional exclusions.
  --help, -h        Show this help.
  --                Treat remaining arguments as directory names.

Relative directories and exclusions are resolved from the current directory.
Exclusions apply to projects, not individual artifacts within a project.
Shared caches such as ~/.gradle, ~/.npm and ~/.cache/uv are outside this helper.
EOF
}

resolve_directory() {
  if [[ ! -d "$1" ]]; then
    printf 'error: not a directory: %s; supply an existing project directory\n' "$1" >&2
    return 2
  fi
  (cd -- "$1" && pwd -P)
}

run_kondo() (
  # Kondo 0.9 can print deletion errors but return success. Preserve those
  # diagnostics and make their presence fail this wrapper's command.
  local diagnostics status=0
  diagnostics=$(mktemp "${TMPDIR:-/tmp}/clean-projects.XXXXXX")
  trap 'rm -f -- "$diagnostics"' EXIT

  if kondo "$@" 2>"$diagnostics"; then
    status=0
  else
    status=$?
  fi
  if [[ -s "$diagnostics" ]]; then
    cat "$diagnostics" >&2
    if [[ "$status" -eq 0 ]]; then
      printf 'error: Kondo reported diagnostics; review them before retrying\n' >&2
      status=1
    fi
  fi
  return "$status"
)

main() {
  local apply=0 older='' directory kondo_help
  local -a directories=() exclusions=() kondo_args=(--same-filesystem)

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help | -h)
        usage
        return 0
        ;;
      --dry-run) apply=0 ;;
      --apply) apply=1 ;;
      --older | --exclude)
        if [[ "$#" -lt 2 || -z "$2" || "$2" == --* ]]; then
          printf 'error: %s requires a value; see --help\n' "$1" >&2
          return 2
        fi
        if [[ "$1" == --older ]]; then
          older=$2
          if [[ ! "$older" =~ ^[0-9]+[mhdwMy]$ ]]; then
            printf 'error: invalid age %s; use a duration such as 30d or 3M\n' "$older" >&2
            return 2
          fi
        else
          exclusions+=("$2")
        fi
        shift
        ;;
      --)
        shift
        directories+=("$@")
        break
        ;;
      -*)
        printf 'error: unknown option %s; see --help\n' "$1" >&2
        return 2
        ;;
      *) directories+=("$1") ;;
    esac
    shift
  done

  if [[ "${#directories[@]}" -eq 0 ]]; then
    directories=("$HOME/projects")
  fi
  # Validate every root before starting Kondo, which otherwise silently skips
  # invalid paths. Absolute paths also keep leading hyphens out of its options.
  local -a roots=()
  for directory in "${directories[@]}"; do
    roots+=("$(resolve_directory "$directory")")
  done
  if [[ -n "$older" ]]; then
    kondo_args+=(--older "$older")
  fi
  # Bash 3.2 (macOS /bin/bash) treats empty arrays as unset under set -u.
  if [[ "${#exclusions[@]}" -gt 0 ]]; then
    for directory in "${exclusions[@]}"; do
      kondo_args+=(--ignored-dirs "$(resolve_directory "$directory")")
    done
  fi
  if [[ "$apply" -eq 1 ]]; then
    if [[ ! -t 0 ]]; then
      printf 'error: --apply requires terminal input; run interactively or use --dry-run\n' >&2
      return 2
    fi
  else
    kondo_args+=(--dry-run)
  fi

  if ! command -v kondo >/dev/null 2>&1; then
    printf 'error: Kondo is missing; install it with: brew install kondo\n' >&2
    return 127
  fi
  kondo_help=$(kondo --help)
  if [[ "$kondo_help" != *--dry-run* ]]; then
    printf 'error: Kondo 0.9 or newer is required; run: brew upgrade kondo\n' >&2
    return 1
  fi
  run_kondo "${kondo_args[@]}" -- "${roots[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
