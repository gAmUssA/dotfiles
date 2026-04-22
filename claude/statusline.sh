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
