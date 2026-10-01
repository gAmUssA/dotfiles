import unittest

from shop import Cart, Catalog, parse_rule
from shop.money import tax

CSV = """
sku,name,price,category
TEA-1,Green tea,4.50,Grocery
BK-7,Python book,40,Books
MUG-2,Mug,12.5,Home
"""


class MoneyTest(unittest.TestCase):
    def test_tax_half_up(self):
        self.assertEqual(tax(1000, "8.875"), 89)
        self.assertEqual(tax(200, "6.25"), 13)
        self.assertEqual(tax(0, "8"), 0)


class CatalogTest(unittest.TestCase):
    def test_lookup_case_insensitive(self):
        c = Catalog(CSV)
        self.assertEqual(c.get("tea-1").price, 450)
        self.assertEqual(c.get(" Mug-2 ").name, "Mug")


class CartTest(unittest.TestCase):
    def setUp(self):
        self.cat = Catalog(CSV)

    def test_plain_total_with_tax(self):
        cart = Cart(self.cat, tax_rate="10")
        cart.add("BK-7")
        cart.add("MUG-2", 2)
        self.assertEqual(cart.total(), 6500 + 650)

    def test_mixed_case_sku_in_cart(self):
        cart = Cart(self.cat)
        cart.add("tea-1", 3)
        self.assertEqual(cart.total(), 1350)

    def test_tax_after_discount(self):
        cart = Cart(self.cat, [parse_rule("percent:books:10")], tax_rate="10")
        cart.add("BK-7")
        # 4000 - 400 = 3600, + 360 tax
        self.assertEqual(cart.total(), 3960)

    def test_bxgy(self):
        cart = Cart(self.cat, [parse_rule("bxgy:TEA-1:2:1")])
        cart.add("TEA-1", 6)
        self.assertEqual(cart.total(), 6 * 450 - 2 * 450)


class BundleTest(unittest.TestCase):
    """New rule type: "bundle:<sku>+<sku>[+...]=<price>". Each complete set of
    the listed SKUs (one of each) costs <price> instead of their summed prices;
    the discount is the difference, applied once per complete set. A set never
    costs MORE than its parts (discount is never negative)."""

    def setUp(self):
        self.cat = Catalog(CSV)

    def test_parse(self):
        rule = parse_rule("bundle:BK-7+MUG-2=45.00")
        cart = Cart(self.cat, [rule])
        cart.add("BK-7")
        cart.add("MUG-2")
        self.assertEqual(cart.total(), 4500)

    def test_only_complete_sets(self):
        cart = Cart(self.cat, [parse_rule("bundle:BK-7+MUG-2=45")])
        cart.add("BK-7", 2)
        cart.add("MUG-2", 3)
        # 2 complete sets at 45.00, plus 1 extra mug at 12.50
        self.assertEqual(cart.total(), 2 * 4500 + 1250)


if __name__ == "__main__":
    unittest.main()
