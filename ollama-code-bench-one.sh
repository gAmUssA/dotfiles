#!/usr/bin/env bash
# ollama-code-bench-one.sh — run the code benchmark for ONE model, without
# wiping the shared bench-out/ history. Reuses the grading logic and the
# coroutines jar from ollama-code-bench.sh. Usage:
#   ./ollama-code-bench-one.sh <ollama-model-tag>

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/bench-out"
LIB="$OUT/lib"
COROUTINES_VER="1.11.0"
COROUTINES_JAR="$LIB/kotlinx-coroutines-core-jvm-$COROUTINES_VER.jar"

[[ $# -eq 1 ]] || { echo "usage: $0 <model-tag>"; exit 1; }
m="$1"

mkdir -p "$LIB"
if [[ ! -f "$COROUTINES_JAR" ]]; then
  curl -s -o "$COROUTINES_JAR" \
    "https://repo1.maven.org/maven2/org/jetbrains/kotlinx/kotlinx-coroutines-core-jvm/$COROUTINES_VER/kotlinx-coroutines-core-jvm-$COROUTINES_VER.jar"
fi

task_ids=( "java" "kotlin" "swift" )
task_files=( "Shapes.java" "Main.kt" "main.swift" )
task_prompts=(
'Write a complete, runnable single-file Java program (Java 21). Define a sealed interface Shape permitting two records, Circle(double radius) and Rectangle(double width, double height). Add a static method area(Shape) returning the area via a pattern-matching switch expression. In main, build a List<Shape> with new Circle(2.0) and new Rectangle(3.0, 4.0), sum the areas, and print the total with printf("%.2f%n", total). Name the public class Shapes. Output ONLY the Java code — no markdown fences, no commentary.'
'Write a complete, runnable single-file Kotlin program using kotlinx.coroutines. Define a sealed class FetchResult with data class Success(val id: Int, val data: String) and data class Failure(val id: Int, val error: String). Write suspend fun fetchItem(id: Int): FetchResult that calls delay(100) then returns Success(id, "item-$id"). In fun main, use runBlocking and async to fetch ids 1, 2, 3 concurrently, awaitAll, and print each as "id=<id> data=<data>". Idiomatic Kotlin. Output ONLY the Kotlin code — no fences, no commentary.'
'Write a complete, runnable single-file Swift program for Swift 6. Define an actor Cache storing [String: Int] with async func set(_ key: String, _ value: Int) and async func get(_ key: String) -> Int?. Define a Codable struct Entry { let key: String; let value: Int }. Use @main with an async main that creates a Cache, sets "answer" to 42, reads it back, builds an Entry, encodes it to JSON via JSONEncoder, and prints "value=\(entry.value)". Must compile clean under Swift 6 concurrency. Output ONLY the Swift code — no fences, no commentary.'
)

extract_code() {
  if grep -q '```' "$1"; then
    awk 'BEGIN{inb=0}
         /^[[:space:]]*```/{ if(inb){exit} else {inb=1; next} }
         inb{print}' "$1"
  else
    cat "$1"
  fi
}

grade_java() {
  local src="$1" work="$2" out="$work/out"; mkdir -p "$out"
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

printf '\n########## %s ##########\n' "$m"
mdir="$OUT/$(echo "$m" | tr ':/.' '___')"; rm -rf "$mdir"; mkdir -p "$mdir"

for i in "${!task_ids[@]}"; do
  tid="${task_ids[$i]}"; tfile="${task_files[$i]}"; prompt="${task_prompts[$i]}"
  resp=$(timeout 600 curl -s --max-time 590 http://localhost:11434/api/generate -d "$(jq -n \
    --arg model "$m" --arg prompt "$prompt" \
    '{model:$model, prompt:$prompt, stream:false, think:false,
      options:{num_predict:2048, temperature:0.1}}')")

  if [[ -z "$resp" ]] || ! echo "$resp" | jq -e '.eval_count' >/dev/null 2>&1; then
    printf '[%-6s] (gen timeout or error)\n' "$tid"
    echo "$resp" | head -c 300 > "$mdir/$tid.err" 2>/dev/null
    continue
  fi

  echo "$resp" | jq -r '.response' > "$mdir/$tid.raw"
  extract_code "$mdir/$tid.raw" > "$mdir/$tfile"
  gen_s=$(echo "$resp" | jq -r '(.total_duration//0)/1e9 | .*10|round/10')
  toks=$(echo "$resp" | jq -r '.eval_count // 0')
  tps=$(echo "$resp" | jq -r 'if (.eval_duration//0)>0 then (.eval_count/( .eval_duration/1e9))*10|round/10 else 0 end')

  work="$mdir/work_$tid"; mkdir -p "$work"
  case "$tid" in
    java)   verdict="$(grade_java   "$mdir/$tfile" "$work")" ;;
    kotlin) verdict="$(grade_kotlin "$mdir/$tfile" "$work")" ;;
    swift)  verdict="$(grade_swift  "$mdir/$tfile" "$work")" ;;
  esac
  printf '[%-6s] gen %5ss | %4s tok @ %s tok/s | %s\n' "$tid" "$gen_s" "$toks" "$tps" "$verdict"
done
unload "$m"

printf '\nSources + raw responses under: %s\n' "$mdir"
