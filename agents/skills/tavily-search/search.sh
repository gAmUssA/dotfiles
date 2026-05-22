#!/usr/bin/env bash
# Tavily web search — prints a synthesized answer plus the top results
# (title, url, content snippet) as readable text for the agent to reason over.
#
# Usage: ./search.sh "your query" [max_results]
# Requires: TAVILY_API_KEY in the environment, jq, curl.
set -euo pipefail

query="${1:-}"
max="${2:-5}"

if [[ -z "$query" ]]; then
  echo "error: no query given. usage: ./search.sh \"query\" [max_results]" >&2
  exit 2
fi
if [[ -z "${TAVILY_API_KEY:-}" ]]; then
  echo "error: TAVILY_API_KEY is not set in the environment." >&2
  exit 3
fi

resp=$(curl -s -X POST https://api.tavily.com/search \
  -H "Authorization: Bearer ${TAVILY_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg q "$query" --argjson n "$max" \
        '{query:$q, max_results:$n, include_answer:true, search_depth:"basic"}')")

if [[ -z "$resp" ]] || ! echo "$resp" | jq -e . >/dev/null 2>&1; then
  echo "error: empty or non-JSON response from Tavily." >&2
  echo "$resp" >&2
  exit 4
fi

echo "$resp" | jq -r '
  "ANSWER: \(.answer // "(none)")\n\nRESULTS:",
  (.results[]? | "- \(.title)\n  \(.url)\n  \(.content)\n")'
