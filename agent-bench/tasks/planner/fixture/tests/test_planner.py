import unittest

from planner import CycleError, Graph, load, schedule


class GraphTest(unittest.TestCase):
    def test_topo_respects_deps(self):
        g = Graph()
        g.add_task("build", deps=["fetch"])
        g.add_task("fetch")
        g.add_task("test", deps=["build"])
        self.assertEqual(g.topo_order(), ["fetch", "build", "test"])

    def test_topo_priority_breaks_ties(self):
        g = Graph()
        g.add_task("a", priority=0)
        g.add_task("b", priority=5)
        g.add_task("c", priority=5)
        self.assertEqual(g.topo_order(), ["b", "c", "a"])

    def test_cycle_reported_from_smallest_name(self):
        g = Graph()
        g.add_task("a", deps=["d"])      # enters the cycle, is not part of it
        g.add_task("d", deps=["e"])
        g.add_task("e", deps=["c"])
        g.add_task("c", deps=["d"])
        with self.assertRaises(CycleError) as cm:
            g.validate()
        self.assertEqual(cm.exception.cycle, ["c", "d", "e", "c"])

    def test_unknown_dependency(self):
        g = Graph()
        g.add_task("x", deps=["nope"])
        with self.assertRaises(ValueError):
            g.validate()


class ScheduleTest(unittest.TestCase):
    def test_waits_for_dependency_to_end(self):
        g = Graph()
        g.add_task("a", duration=3)
        g.add_task("x", duration=1)        # frees a worker at t=1, while a runs
        g.add_task("b", deps=["a"], duration=2)
        self.assertEqual(
            schedule(g, workers=2), {"a": (0, 3), "x": (0, 1), "b": (3, 5)}
        )

    def test_parallel_by_priority(self):
        g = Graph()
        g.add_task("low", duration=2, priority=0)
        g.add_task("high", duration=2, priority=9)
        g.add_task("mid", duration=2, priority=5)
        self.assertEqual(
            schedule(g, workers=2),
            {"high": (0, 2), "mid": (0, 2), "low": (2, 4)},
        )


class ResourceTest(unittest.TestCase):
    """New feature: resources with a capacity.

    Config:  `resource <name> <capacity>` lines, and `resource=<name>` on a
             task line. A task uses at most one resource.
    Graph:   Graph.add_resource(name, capacity); add_task(..., resource=name).
             validate() raises ValueError for a task naming an unknown resource.
    Schedule: at any moment, at most `capacity` running tasks may use a given
             resource. A ready task whose resource is full is skipped for now
             — it must NOT stop lower-priority ready tasks from starting.
    """

    def test_capacity_limits_parallelism(self):
        g = load("""
            resource db 1
            task m1 duration=2 resource=db
            task m2 duration=2 resource=db
        """)
        self.assertEqual(schedule(g, workers=4), {"m1": (0, 2), "m2": (2, 4)})

    def test_unknown_resource_rejected(self):
        g = load("task x resource=gpu")
        with self.assertRaises(ValueError):
            g.validate()


if __name__ == "__main__":
    unittest.main()
