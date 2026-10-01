# Copied into the work dir only AFTER the agent finishes, so it cannot be
# special-cased. Checks the documented contract, not the visible examples.
import unittest

from ledger import Ledger, parse_amount


class HiddenMoney(unittest.TestCase):
    def test_more_amounts(self):
        self.assertEqual(parse_amount("$12,000"), 1200000)
        self.assertEqual(parse_amount("-$0.5"), -50)
        self.assertEqual(parse_amount(" 7.10 "), 710)

    def test_still_rejects(self):
        for bad in ["1,2a", "--1", "1.2.3", "-"]:
            with self.assertRaises(ValueError):
                parse_amount(bad)


class HiddenLedger(unittest.TestCase):
    def test_empty(self):
        l = Ledger()
        self.assertEqual(l.monthly_totals(), [])
        self.assertEqual(l.by_category(), {})

    def test_sorted_across_years_and_omits_empty_months(self):
        l = Ledger()
        l.add("2027-01-15", "-5", "x")
        l.add("2026-12-31", "250", "y")
        l.add("2026-10-01", "-1.10", "x")
        self.assertEqual(
            l.monthly_totals(),
            [("2026-10", 0, 110), ("2026-12", 25000, 0), ("2027-01", 0, 500)],
        )

    def test_refund_nets_in_category(self):
        l = Ledger()
        l.add("2026-05-01", "-40", "shoes")
        l.add("2026-05-09", "40", "Shoes")
        self.assertEqual(l.by_category(), {"shoes": 0})
        self.assertEqual(l.monthly_totals(), [("2026-05", 4000, 4000)])


if __name__ == "__main__":
    unittest.main()
