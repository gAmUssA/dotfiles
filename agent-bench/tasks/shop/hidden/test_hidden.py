# Copied in only AFTER the agent finishes. Checks documented contracts that the
# visible tests do not pin down.
import unittest

from shop import Cart, Catalog, parse_rule
from shop.money import tax

CSV = """
sku,name,price,category
TEA-1,Green tea,4.50,Grocery
BK-7,Python book,40,Books
MUG-2,Mug,12.5,Home
PEN-3,Pen,1.99,Office
"""


class HiddenMoney(unittest.TestCase):
    def test_more_half_up(self):
        self.assertEqual(tax(100, "0.5"), 1)      # 0.5 -> 1
        self.assertEqual(tax(1050, "5"), 53)      # 52.5 -> 53 (round() gives 52)
        self.assertEqual(tax(333, "10"), 33)      # 33.3 -> 33


class HiddenCart(unittest.TestCase):
    def setUp(self):
        self.cat = Catalog(CSV)

    def test_rules_with_lowercase_skus(self):
        cart = Cart(self.cat, [parse_rule("bxgy:tea-1:1:1")])
        cart.add("TEA-1", 2)
        self.assertEqual(cart.total(), 450)

    def test_bundle_three_items_and_case(self):
        cart = Cart(self.cat, [parse_rule("bundle:bk-7+MUG-2+pen-3=50")])
        cart.add("BK-7")
        cart.add("mug-2")
        cart.add("PEN-3", 2)
        # one set: 5000; extra pen 199
        self.assertEqual(cart.total(), 5000 + 199)

    def test_bundle_never_raises_price(self):
        cart = Cart(self.cat, [parse_rule("bundle:TEA-1+PEN-3=100")])
        cart.add("TEA-1")
        cart.add("PEN-3")
        self.assertEqual(cart.total(), 450 + 199)

    def test_bundle_absent_items(self):
        cart = Cart(self.cat, [parse_rule("bundle:BK-7+MUG-2=45")])
        cart.add("TEA-1")
        self.assertEqual(cart.total(), 450)

    def test_unknown_rule_still_rejected(self):
        with self.assertRaises(ValueError):
            parse_rule("coupon:X:1")


if __name__ == "__main__":
    unittest.main()
