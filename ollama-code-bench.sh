#!/usr/bin/env bash
# ollama-code-bench.sh — high-level coding benchmark for local models.
#
# Unlike ollama-bench.sh (shell one-liner latency for the tmux pop-up), this
# benchmark asks each model to write a real, idiomatic program in Java, Kotlin,
# and Swift, then OBJECTIVELY grades it by compiling and running the output:
#
#   Java   — sealed interface + records + pattern-matching switch (Java 21).
#            Graded with `javac` + run (single-file source mode runs the wrong
#            class when the model puts the interface first, so we compile + find
#            the main class instead).
#   Kotlin — sealed class + coroutines (runBlocking/async/awaitAll).
#            Graded with `kotlinc` against kotlinx-coroutines-core-jvm.
#   Swift  — actor cache + Codable + @main, compiled under -swift-version 6
#            so actor/Sendable mistakes show up as real errors.
#
# Each (model, task) gets: GEN time, COMPILE ok/fail (+ first error), RUN output.
# The compile/run signal is objective; final quality ranking (idioms, modern
# API use, correctness of logic) is judged on top of it by reading bench-out/.
#
# Usage: ./ollama-code-bench.sh
# Requires: ollama daemon, jq, java 21+, kotlinc, swiftc. Network once for the
# coroutines jar.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/bench-out"
LIB="$OUT/lib"
COROUTINES_VER="1.11.0"
COROUTINES_JAR="$LIB/kotlinx-coroutines-core-jvm-$COROUTINES_VER.jar"

rm -rf "$OUT"; mkdir -p "$LIB"

# --- one-time: coroutines jar for the Kotlin compile -----------------------
if [[ ! -f "$COROUTINES_JAR" ]]; then
  curl -s -o "$COROUTINES_JAR" \
    "https://repo1.maven.org/maven2/org/jetbrains/kotlinx/kotlinx-coroutines-core-jvm/$COROUTINES_VER/kotlinx-coroutines-core-jvm-$COROUTINES_VER.jar"
fi

# --- models (coding-capable; small chat models excluded) -------------------
models=(
  "qwen2.5-coder:7b"
  "qwen3-coder:30b"
  "qwen3.6:27b"
  "devstral:24b"
)

# --- task suite (parallel arrays; macOS bash 3.2, no assoc arrays) ---------
task_ids=( "java" "kotlin" "swift" )
task_files=( "Shapes.java" "Main.kt" "main.swift" )
task_prompts=(
'Write a complete, runnable single-file Java program (Java 21). Define a sealed interface Shape permitting two records, Circle(double radius) and Rectangle(double width, double height). Add a static method area(Shape) returning the area via a pattern-matching switch expression. In main, build a List<Shape> with new Circle(2.0) and new Rectangle(3.0, 4.0), sum the areas, and print the total with printf("%.2f%n", total). Name the public class Shapes. Output ONLY the Java code — no markdown fences, no commentary.'
'Write a complete, runnable single-file Kotlin program using kotlinx.coroutines. Define a sealed class FetchResult with data class Success(val id: Int, val data: String) and data class Failure(val id: Int, val error: String). Write suspend fun fetchItem(id: Int): FetchResult that calls delay(100) then returns Success(id, "item-$id"). In fun main, use runBlocking and async to fetch ids 1, 2, 3 concurrently, awaitAll, and print each as "id=<id> data=<data>". Idiomatic Kotlin. Output ONLY the Kotlin code — no fences, no commentary.'
'Write a complete, runnable single-file Swift program for Swift 6. Define an actor Cache storing [String: Int] with async func set(_ key: String, _ value: Int) and async func get(_ key: String) -> Int?. Define a Codable struct Entry { let key: String; let value: Int }. Use @main with an async main that creates a Cache, sets "answer" to 42, reads it back, builds an Entry, encodes it to JSON via JSONEncoder, and prints "value=\(entry.value)". Must compile clean under Swift 6 concurrency. Output ONLY the Swift code — no fences, no commentary.'
)

# --- extract the first fenced code block, or pass through if no fences -----
extract_code() {
  if grep -q '```' "$1"; then
    awk 'BEGIN{inb=0}
         /^[[:space:]]*```/{ if(inb){exit} else {inb=1; next} }
         inb{print}' "$1"
  else
    cat "$1"
  fi
}

# --- per-language compile + run; echoes a verdict, returns 0 if RUN ok -----
grade_java() {
  local src="$1" work="$2" out="$work/out"; mkdir -p "$out"
  # Drop leading `public` on any top-level type decl so javac doesn't demand a
  # filename match. Matches the whole line (handles `public sealed interface`,
  # `public final class`, `public record`, etc.), not a fixed modifier order.
  sed -E '/^public .*(class|interface|enum|record)/s/^public //' "$src" > "$work/Prog.java"
  if ! javac -d "$out" "$work/Prog.java" 2>"$work/compile.err"; then
    echo "COMPILE fail | $(head -1 "$work/compile.err")"; return 2
  fi
  local main_cls=""
  for f in "$out"/*.class; do
    local c; c="$(basename "$f" .class)"
    if javap -p -cp "$out" "$c" 2>/dev/null | grep -q 'public static void main'; then main_cls="$c"; break; fi
  done
  [[ -z "$main_cls" ]] && { echo "COMPILE ok | RUN fail: no main"; return 2; }
  local run; run="$(cd "$out" && timeout 20 java "$main_cls" 2>"$work/run.err")"
  if [[ $? -ne 0 ]]; then echo "COMPILE ok | RUN fail | $(head -1 "$work/run.err")"; return 2; fi
  echo "COMPILE ok | RUN ok | out: $(echo "$run" | tr '\n' ' ')"; return 0
}

grade_kotlin() {
  local src="$1" work="$2" jar="$work/prog.jar"
  cp "$src" "$work/Main.kt"
  if ! kotlinc "$work/Main.kt" -cp "$COROUTINES_JAR" -include-runtime -d "$jar" 2>"$work/compile.err"; then
    echo "COMPILE fail | $(grep -m1 error "$work/compile.err" || head -1 "$work/compile.err")"; return 2
  fi
  local run; run="$(timeout 30 java -cp "$jar:$COROUTINES_JAR" MainKt 2>"$work/run.err")"
  if [[ $? -ne 0 ]]; then echo "COMPILE ok | RUN fail | $(head -1 "$work/run.err")"; return 2; fi
  echo "COMPILE ok | RUN ok | out: $(echo "$run" | tr '\n' ' ' | head -c 160)"; return 0
}

grade_swift() {
  local src="$1" work="$2" bin="$work/prog"
  # Try library mode first (correct for the requested @main); if that fails,
  # retry as a script (main.swift, top-level code). Grade "does it work",
  # not "did it match one compile flag".
  cp "$src" "$work/Prog.swift"
  if ! swiftc -swift-version 6 -parse-as-library "$work/Prog.swift" -o "$bin" 2>"$work/compile.err"; then
    cp "$src" "$work/main.swift"
    if ! swiftc -swift-version 6 "$work/main.swift" -o "$bin" 2>"$work/compile.err"; then
      echo "COMPILE fail (swift6) | $(grep -m1 error: "$work/compile.err" | head -c 160 || head -1 "$work/compile.err")"; return 2
    fi
  fi
  local run; run="$(timeout 20 "$bin" 2>"$work/run.err")"
  if [[ $? -ne 0 ]]; then echo "COMPILE ok | RUN fail | $(head -1 "$work/run.err")"; return 2; fi
  echo "COMPILE ok | RUN ok | out: $(echo "$run" | tr '\n' ' ')"; return 0
}

unload() { curl -s http://localhost:11434/api/generate -d "{\"model\":\"$1\",\"keep_alive\":0}" >/dev/null 2>&1; }

printf '\n=== ollama-code-bench: %s models x %s tasks ===\n' "${#models[@]}" "${#task_ids[@]}"

# installed model tags, queried once via the API (fail-open: if the query
# returns nothing we assume present and let generation surface a real error,
# so a busy daemon during a concurrent pull can't cause false skips)
installed="$(curl -s http://localhost:11434/api/tags | jq -r '.models[]?.name' 2>/dev/null)"

for m in "${models[@]}"; do
  if [[ -n "$installed" ]] && ! grep -qx "$m" <<<"$installed"; then
    printf '\n### %s — NOT INSTALLED, skipping\n' "$m"; continue
  fi
  printf '\n########## %s ##########\n' "$m"
  mdir="$OUT/$(echo "$m" | tr ':/.' '___')"; mkdir -p "$mdir"

  for i in "${!task_ids[@]}"; do
    tid="${task_ids[$i]}"; tfile="${task_files[$i]}"; prompt="${task_prompts[$i]}"
    resp=$(timeout 300 curl -s --max-time 290 http://localhost:11434/api/generate -d "$(jq -n \
      --arg model "$m" --arg prompt "$prompt" \
      '{model:$model, prompt:$prompt, stream:false, think:false,
        options:{num_predict:2048, temperature:0.1}}')")

    if [[ -z "$resp" ]] || ! echo "$resp" | jq -e '.eval_count' >/dev/null 2>&1; then
      printf '[%-6s] (gen timeout or error)\n' "$tid"; continue
    fi

    echo "$resp" | jq -r '.response' > "$mdir/$tid.raw"
    extract_code "$mdir/$tid.raw" > "$mdir/$tfile"
    gen_s=$(echo "$resp" | jq -r '(.total_duration//0)/1e9 | .*10|round/10')

    work="$mdir/work_$tid"; mkdir -p "$work"
    case "$tid" in
      java)   verdict="$(grade_java   "$mdir/$tfile" "$work")" ;;
      kotlin) verdict="$(grade_kotlin "$mdir/$tfile" "$work")" ;;
      swift)  verdict="$(grade_swift  "$mdir/$tfile" "$work")" ;;
    esac
    printf '[%-6s] gen %5ss | %s\n' "$tid" "$gen_s" "$verdict"
  done
  unload "$m"
done

printf '\nGenerated sources + raw responses under: %s\n' "$OUT"
