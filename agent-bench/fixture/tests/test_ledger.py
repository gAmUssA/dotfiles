import unittest

from ledger import Ledger, format_amount, parse_amount


class MoneyTest(unittest.TestCase):
    def test_plain(self):
        self.assertEqual(parse_amount("12"), 1200)
        self.assertEqual(parse_amount("0.07"), 7)

    def test_thousands_and_dollar(self):
        self.assertEqual(parse_amount("$1,234.50"), 123450)

    def test_one_decimal_digit(self):
        self.assertEqual(parse_amount("-3.5"), -350)

    def test_rejects_garbage(self):
        for bad in ["", "abc", "1.234", "$"]:
            with self.assertRaises(ValueError):
                parse_amount(bad)

    def test_format(self):
        self.assertEqual(format_amount(123450), "$1,234.50")
        self.assertEqual(format_amount(-350), "-$3.50")


class LedgerTest(unittest.TestCase):
    def setUp(self):
        self.l = Ledger()
        self.l.add("2026-03-01", "1000", "Salary")
        self.l.add("2026-03-05", "-30.25", "food")
        self.l.add("2026-03-20", "-12", "Food ")
        self.l.add("2026-04-02", "-100", "rent")

    def test_balance(self):
        self.assertEqual(self.l.balance(), 100000 - 3025 - 1200 - 10000)

    def test_by_category_is_net(self):
        self.assertEqual(
            self.l.by_category(),
            {"salary": 100000, "food": -4225, "rent": -10000},
        )

    def test_monthly_totals(self):
        self.assertEqual(
            self.l.monthly_totals(),
            [("2026-03", 100000, 4225), ("2026-04", 0, 10000)],
        )


if __name__ == "__main__":
    unittest.main()
