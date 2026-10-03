"""Load a Graph from a small line-based config format.

    # comments and blank lines are ignored
    task <name> [deps=<a>,<b>] [duration=<int>] [priority=<int>]

Unknown line kinds or keys raise ValueError naming the line number.
"""

from .graph import Graph


def load(text: str) -> Graph:
    g = Graph()
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        kind, name, *pairs = line.split()
        if kind != "task":
            raise ValueError(f"line {lineno}: unknown line kind {kind!r}")
        opts = {}
        for p in pairs:
            key, _, value = p.partition("=")
            if key == "deps":
                opts["deps"] = [d for d in value.split(",") if d]
            elif key in ("duration", "priority"):
                opts[key] = int(value)
            else:
                raise ValueError(f"line {lineno}: unknown key {key!r}")
        g.add_task(name, **opts)
    return g
