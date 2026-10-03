# Copied in only AFTER the agent finishes. Probes the documented contracts the
# visible tests leave open.
import unittest

from planner import CycleError, Graph, load, schedule


class HiddenGraph(unittest.TestCase):
    def test_priority_only_among_ready(self):
        # high-priority task still waits for its dependency
        g = Graph()
        g.add_task("z", priority=0)
        g.add_task("y", deps=["z"], priority=100)
        g.add_task("a", priority=1)
        self.assertEqual(g.topo_order(), ["a", "z", "y"])

    def test_self_cycle(self):
        g = Graph()
        g.add_task("loop", deps=["loop"])
        with self.assertRaises(CycleError) as cm:
            g.validate()
        self.assertEqual(cm.exception.cycle, ["loop", "loop"])

    def test_cycle_entered_mid_way(self):
        g = Graph()
        g.add_task("a", deps=["x"])
        g.add_task("x", deps=["y"])
        g.add_task("y", deps=["w"])
        g.add_task("w", deps=["x"])
        with self.assertRaises(CycleError) as cm:
            g.validate()
        self.assertEqual(cm.exception.cycle, ["w", "x", "y", "w"])


class HiddenSchedule(unittest.TestCase):
    def test_diamond(self):
        g = Graph()
        g.add_task("root", duration=1)
        g.add_task("l", deps=["root"], duration=3)
        g.add_task("r", deps=["root"], duration=1)
        g.add_task("join", deps=["l", "r"], duration=1)
        self.assertEqual(
            schedule(g, workers=2),
            {"root": (0, 1), "l": (1, 4), "r": (1, 2), "join": (4, 5)},
        )

    def test_blocked_resource_does_not_block_others(self):
        g = load("""
            resource db 1
            task hold duration=5 resource=db priority=9
            task want duration=1 resource=db priority=8
            task free duration=1 priority=1
        """)
        self.assertEqual(
            schedule(g, workers=2),
            {"hold": (0, 5), "free": (0, 1), "want": (5, 6)},
        )

    def test_capacity_two(self):
        g = load("""
            resource gpu 2
            task t1 duration=3 resource=gpu
            task t2 duration=3 resource=gpu
            task t3 duration=3 resource=gpu
        """)
        s = schedule(g, workers=8)
        self.assertEqual(s["t1"], (0, 3))
        self.assertEqual(s["t2"], (0, 3))
        self.assertEqual(s["t3"], (3, 6))

    def test_config_still_rejects_unknown_keys(self):
        with self.assertRaises(ValueError):
            load("task x colour=red")


if __name__ == "__main__":
    unittest.main()
