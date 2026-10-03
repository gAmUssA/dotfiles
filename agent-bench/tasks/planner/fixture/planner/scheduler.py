"""Simulate running a task graph on N parallel workers."""


def schedule(graph, workers: int = 1) -> dict[str, tuple[int, int]]:
    """Return {task: (start, end)} for running `graph` on `workers` workers.

    Time is an integer clock starting at 0; a task occupies one worker for
    `duration` and ends at start + duration. A task may start only once ALL
    of its dependencies have ENDED (end <= now). Whenever workers are free,
    ready tasks are started in priority order (higher `priority` first, then
    name ascending) until workers run out.
    """
    graph.validate()
    result: dict[str, tuple[int, int]] = {}
    running: list[tuple[int, str]] = []  # (end, name)
    now = 0
    while len(result) < len(graph.tasks):
        ready = [
            t for n, t in graph.tasks.items()
            if n not in result
            and all(d in result and result[d][0] <= now for d in t.deps)
        ]
        ready.sort(key=lambda t: (-t.priority, t.name))
        for t in ready:
            if len(running) >= workers:
                break
            result[t.name] = (now, now + t.duration)
            running.append((now + t.duration, t.name))
        running.sort()
        now = running[0][0]
        running = [r for r in running if r[0] > now]
    return result
