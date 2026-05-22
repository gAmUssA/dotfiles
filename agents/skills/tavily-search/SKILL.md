---
name: tavily-search
description: Web search and content extraction via the Tavily API. Use whenever you need current/up-to-date information the model can't be sure of — latest release versions, documentation, news, facts, library APIs, or any web content. Requires the TAVILY_API_KEY environment variable.
---

# Tavily Search

Search the web for current information. This skill is Pi's equivalent of an
MCP search server — a plain CLI tool you invoke with the `bash` tool.

The `TAVILY_API_KEY` environment variable must be set (it already is in this
shell). Do not print or echo the key.

## Search

```
./search.sh "your query"          # top 5 results
./search.sh "your query" 10       # up to N results
```

The script prints a synthesized `ANSWER:` line followed by `RESULTS:` (each
with title, URL, and a content snippet). Prefer the authoritative source
(official docs, GitHub releases, vendor sites) over blogs/forums when results
disagree, and always cite the URL you used.
