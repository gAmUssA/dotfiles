#!/usr/bin/env bash
# Real Kondo integration; all deletion is confined to disposable fixtures.
set -euo pipefail

main() (
  local repo sandbox script preview
  if ! command -v kondo >/dev/null 2>&1; then
    printf 'error: integration tests need Kondo >= 0.9; run: brew install kondo\n' >&2
    return 127
  fi
  repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
  script="$repo/clean_projects.sh"
  sandbox=$(mktemp -d "${TMPDIR:-/tmp}/clean-projects-kondo.XXXXXX")
  sandbox=$(cd -- "$sandbox" && pwd -P)
  trap 'rm -rf -- "$sandbox"' EXIT

  mkdir -p "$sandbox/node project/node_modules" "$sandbox/maven/target" \
    "$sandbox/gradle/build" "$sandbox/gradle/.gradle" "$sandbox/gradle/app/build" \
    "$sandbox/cad/out"
  printf '{}\n' >"$sandbox/node project/package.json"
  printf 'dependency\n' >"$sandbox/node project/node_modules/package.js"
  printf 'source\n' >"$sandbox/node project/index.js"
  printf '<project/>\n' >"$sandbox/maven/pom.xml"
  printf 'compiled\n' >"$sandbox/maven/target/example.jar"
  printf '// build\n' >"$sandbox/gradle/build.gradle.kts"
  printf '// build\n' >"$sandbox/gradle/app/build.gradle.kts"
  printf 'compiled\n' >"$sandbox/gradle/build/example.jar"
  printf 'cache\n' >"$sandbox/gradle/.gradle/cache.bin"
  printf 'compiled\n' >"$sandbox/gradle/app/build/example.jar"
  printf 'export\n' >"$sandbox/cad/out/model.step"

  preview=$(bash "$script" "$sandbox")
  [[ "$preview" == *'node_modules'* && "$preview" == *'target'* && "$preview" == *'.gradle'* ]]
  [[ -f "$sandbox/node project/node_modules/package.js" ]]
  [[ -f "$sandbox/maven/target/example.jar" ]]
  [[ -f "$sandbox/gradle/.gradle/cache.bin" ]]
  [[ -f "$sandbox/cad/out/model.step" ]]
  printf 'PASS: real Kondo previews Node, Maven and Gradle artifacts without deleting files\n'

  preview=$(bash "$script" --exclude "$sandbox/node project" "$sandbox")
  [[ "$preview" != *'node project'* && "$preview" == *'Maven'* ]]
  printf 'PASS: excluded project is absent from real Kondo results\n'

  preview=$(bash "$script" "$sandbox/gradle/app")
  [[ "$preview" == *'gradle/app'* && "$preview" == *'build'* ]]
  printf 'PASS: an explicit Gradle module path includes its build artifacts\n'

  # script(1) supplies a terminal, allowing the same interactive path as a human.
  printf 'n\n' | script -q /dev/null /bin/bash "$script" --apply "$sandbox/maven" >"$sandbox/decline.log" 2>&1
  [[ -f "$sandbox/maven/target/example.jar" ]]
  printf 'y\n' | script -q /dev/null /bin/bash "$script" --apply "$sandbox/node project" >"$sandbox/apply.log" 2>&1
  [[ ! -e "$sandbox/node project/node_modules" ]]
  [[ -f "$sandbox/node project/index.js" ]]
  [[ -f "$sandbox/node project/package.json" ]]
  [[ -f "$sandbox/cad/out/model.step" ]]
  printf 'PASS: interactive decline preserves artifacts; acceptance removes only fixture dependencies\n'
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
