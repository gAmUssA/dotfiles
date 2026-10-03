"""Task dependency graph."""

from dataclasses import dataclass, field


class CycleError(Exception):
    """Raised when the graph has a dependency cycle.

    `cycle` is the list of task names forming ONE cycle, in dependency order
    (each task depends on the next one), starting AND ending with the
    lexicographically smallest task in that cycle.
    E.g. a->b->c->a (a depends on b, b on c, c on a): ["a", "b", "c", "a"].
    """

    def __init__(self, cycle):
        super().__init__(" -> ".join(cycle))
        self.cycle = cycle


@dataclass
class Task:
    name: str
    deps: list = field(default_factory=list)
    duration: int = 1
    priority: int = 0


class Graph:
    def __init__(self) -> None:
        self.tasks: dict[str, Task] = {}

    def add_task(self, name, deps=(), duration=1, priority=0) -> Task:
        task = Task(name, list(deps), duration, priority)
        self.tasks[name] = task
        return task

    def validate(self) -> None:
        """Raise ValueError naming the task and the missing dependency if any
        task depends on a name that was never added. Raise CycleError (see its
        docstring) if there is a dependency cycle."""
        for t in self.tasks.values():
            for d in t.deps:
                if d not in self.tasks:
                    raise ValueError(f"{t.name}: unknown dependency {d}")
        visiting, done = set(), set()

        def visit(n, path):
            if n in done:
                return
            if n in visiting:
                raise CycleError(path + [n])
            visiting.add(n)
            for d in self.tasks[n].deps:
                visit(d, path + [n])
            visiting.discard(n)
            done.add(n)

        for n in sorted(self.tasks):
            visit(n, [])

    def topo_order(self) -> list[str]:
        """All task names, every task after all of its dependencies.

        Among tasks that are ready at the same moment, higher `priority`
        comes first; equal priorities go by name, ascending.
        """
        self.validate()
        remaining = {n: set(t.deps) for n, t in self.tasks.items()}
        order = []
        while remaining:
            ready = sorted(n for n, deps in remaining.items() if not deps)
            n = ready[0]
            order.append(n)
            del remaining[n]
            for deps in remaining.values():
                deps.discard(n)
        return order
