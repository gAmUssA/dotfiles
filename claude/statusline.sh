#!/bin/bash
# Claude Code custom status line.
# Activated via ~/.claude/settings.json → statusLine.
# Receives session JSON on stdin; prints a single-line status string.

input=$(cat)
eval "$(echo "$input" | jq -r '
  @sh "MODEL=\(.model.display_name // "?")",
  @sh "DIR=\(.workspace.current_dir // "?")",
  @sh "DURATION_MS=\(.cost.total_duration_ms // 0)",
  @sh "ADDED=\(.cost.total_lines_added // 0)",
  @sh "REMOVED=\(.cost.total_lines_removed // 0)",
  @sh "PCT=\(.context_window.used_percentage // 0 | floor)",
  @sh "CTX_SIZE=\(.context_window.context_window_size // 0)",
  @sh "AGENT=\(.agent.name // "")",
  @sh "WORKTREE=\(.worktree.name // "")"
')"

DIR_SHORT="${DIR##*/}"
DURATION_S=$((DURATION_MS / 1000))
MINUTES=$((DURATION_S / 60))
SEC=$((DURATION_S % 60))

if [ "$CTX_SIZE" -ge 1000000 ]; then
  CTX_LABEL="$((CTX_SIZE / 1000000))M"
else
  CTX_LABEL="$((CTX_SIZE / 1000))k"
fi

if [ "$MINUTES" -gt 0 ]; then
  TIME="${MINUTES}m${SEC}s"
else
  TIME="${SEC}s"
fi

R='\033[0m'; D='\033[2m'; B='\033[1m'
GRN='\033[32m'; YEL='\033[33m'; RED='\033[31m'
MAG='\033[35m'; CYN='\033[36m'; BLU='\033[34m'

if [ "$PCT" -lt 50 ]; then PC="$GRN"
elif [ "$PCT" -lt 75 ]; then PC="$YEL"
else PC="$RED"
fi

BRANCH=$(git -C "$DIR" symbolic-ref --short HEAD 2>/dev/null)
GIT=""
if [ -n "$BRANCH" ]; then
  DIRTY=""
  git -C "$DIR" diff --quiet HEAD 2>/dev/null || DIRTY="${YEL}*${R}"
  GIT=" ${MAG}${BRANCH}${DIRTY}"
fi

BADGES=""
[ -n "$AGENT" ] && BADGES="${BADGES} ${CYN}[${AGENT}]${R}"
[ -n "$WORKTREE" ] && BADGES="${BADGES} ${BLU}[wt:${WORKTREE}]${R}"

echo -e "${B}${MODEL}${R} ${D}│${R} ${DIR_SHORT}${GIT}${BADGES} ${D}│${R} ${PC}${PCT}%${R}${D}/${R}${CTX_LABEL} ${D}│${R} ${GRN}+${ADDED}${R}${D}/${R}${RED}-${REMOVED}${R} ${D}│${R} ${D}${TIME}${R}"

# Prompt-cache line: how long until the main conversation's cache expires,
# and once cold, how many tokens the next message re-processes. Every message
# re-sends the whole conversation; a warm cache skips re-reading it (faster,
# cheaper against usage limits). Subscription main thread: 1h TTL; API key or
# usage credits: 5m. Fields need Claude Code >= 2.1.251 (miss causes 2.1.260);
# absent fields are skipped, and nothing prints until prompt_cache appears.
# settings.json sets statusLine.refreshInterval (seconds) so the countdown
# moves while idle; Claude Code also re-runs this at expires_at by itself.
echo "$input" | jq -r --argjson now "$(date +%s)" '
  .prompt_cache // empty
  | . as $c
  | ($c.ttl // "") as $ttl
  | (if $ttl == "1h" then 3600 elif $ttl == "5m" then 300 else null end) as $span
  | def k(n): if n == null then null elif n >= 1000 then "\((n / 1000) | round)k" else "\(n)" end;
    if $c.warm == true and $c.expires_at != null then
      (($c.expires_at - $now) | if . < 0 then 0 else . end) as $left
      | (if $span then ($left / $span) else 1 end) as $frac
      | ([((($frac * 6) | ceil)), 6] | min) as $full
      | (if $frac < 0.2 then "\u001b[33m" else "\u001b[32m" end) as $col
      | "\($col)cache ● \($ttl) "
        + ("█" * $full) + ("░" * (6 - $full))
        + " " + (if $left >= 60 then "\(($left / 60) | floor)m" else "\($left)s" end) + " left"
        + (if $c.hit_ratio != null then " · hit \(($c.hit_ratio * 100) | round)%" else "" end)
        + (if $c.misses != null then " · misses \($c.misses)" else "" end)
        + "\u001b[0m"
    elif $c.warm == false then
      "\u001b[31mcache ○ cold"
        + (if $c.recache_tokens_if_cold != null
           then " · next message re-caches \(k($c.recache_tokens_if_cold)) tokens" else "" end)
        + (if ($c.last_miss_cause.causes // []) | length > 0
           then " · last miss: \($c.last_miss_cause.causes | join(", "))" else "" end)
        + "\u001b[0m"
    else empty end
' 2>/dev/null
