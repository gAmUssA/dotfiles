#!/usr/bin/env bash
# regrade-gemma4.sh — re-grade gemma-4 quant outputs after stripping the leaked
# harmony channel tokens (<|channel>thought / <channel|>) ollama fails to filter.
set -o pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/bench-out"
COROUTINES_JAR="$OUT/lib/kotlinx-coroutines-core-jvm-1.11.0.jar"

# drop everything up to & including the last <channel|>, then strip md fences.
sanitize() {
  perl -0777 -pe 's/.*<channel\|>//s; s/<\|channel>thought//g' "$1" \
  | awk 'BEGIN{seen=0;inb=0}
         /^[[:space:]]*```/{ if(!seen){seen=1;inb=1;next} else {exit} }
         { if(seen){ if(inb)print } else print }'
}

grade_java() {
  local src="$1" w="$2" cls="$w/cls"; mkdir -p "$cls"
  sed -E '/^public .*(class|interface|enum|record)/s/^public //' "$src" > "$w/Prog.java"
  javac -d "$cls" "$w/Prog.java" 2>"$w/c.err" || { echo "COMPILE fail | $(head -1 "$w/c.err")"; return; }
  local mc=""; for f in "$cls"/*.class; do local c; c="$(basename "$f" .class)"; javap -p -cp "$cls" "$c" 2>/dev/null | grep -q 'public static void main' && { mc="$c"; break; }; done
  [[ -z "$mc" ]] && { echo "COMPILE ok | no main"; return; }
  local r; r="$(cd "$cls" && timeout 20 java "$mc" 2>"$w/r.err")"
  [[ $? -ne 0 ]] && { echo "COMPILE ok | RUN fail | $(head -1 "$w/r.err")"; return; }
  echo "COMPILE ok | RUN ok | out: $(echo "$r" | tr '\n' ' ')"
}
grade_kotlin() {
  local src="$1" w="$2" jar="$w/p.jar"
  kotlinc "$src" -cp "$COROUTINES_JAR" -include-runtime -d "$jar" 2>"$w/c.err" || { echo "COMPILE fail | $(grep -m1 error "$w/c.err" | head -c 120)"; return; }
  local r; r="$(timeout 30 java -cp "$jar:$COROUTINES_JAR" MainKt 2>"$w/r.err")"
  [[ $? -ne 0 ]] && { echo "COMPILE ok | RUN fail | $(head -1 "$w/r.err")"; return; }
  echo "COMPILE ok | RUN ok | out: $(echo "$r" | tr '\n' ' ' | head -c 120)"
}
grade_swift() {
  local src="$1" w="$2" bin="$w/p"
  if ! swiftc -swift-version 6 -parse-as-library "$src" -o "$bin" 2>"$w/c.err"; then
    cp "$src" "$w/main.swift"
    swiftc -swift-version 6 "$w/main.swift" -o "$bin" 2>"$w/c.err" || { echo "COMPILE fail | $(grep -m1 error: "$w/c.err" | head -c 120)"; return; }
  fi
  local r; r="$(timeout 20 "$bin" 2>"$w/r.err")"
  [[ $? -ne 0 ]] && { echo "COMPILE ok | RUN fail | $(head -1 "$w/r.err")"; return; }
  echo "COMPILE ok | RUN ok | out: $(echo "$r" | tr '\n' ' ')"
}

for q in Q4_K_M Q6_K Q8_0; do
  d="$OUT/hf_co_yuxinlu1_gemma-4-12B-coder-fable5-composer2_5-v1-GGUF_$q"
  [[ -d "$d" ]] || { echo "## $q — missing"; continue; }
  echo "########## $q (sanitized) ##########"
  for pair in "java:Shapes.java:grade_java" "kotlin:Main.kt:grade_kotlin" "swift:main.swift:grade_swift"; do
    IFS=: read tid file fn <<<"$pair"
    [[ -f "$d/$tid.raw" ]] || { printf '[%-6s] no raw\n' "$tid"; continue; }
    w="$d/rg_$tid"; rm -rf "$w"; mkdir -p "$w"
    sanitize "$d/$tid.raw" > "$w/$file"
    printf '[%-6s] %s\n' "$tid" "$($fn "$w/$file" "$w")"
  done
done
