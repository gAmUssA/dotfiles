"""Shopping cart and checkout totals."""

from .money import tax


class Cart:
    def __init__(self, catalog, rules=(), tax_rate: str = "0") -> None:
        self.catalog = catalog
        self.rules = list(rules)
        self.tax_rate = tax_rate
        self.lines: dict[str, int] = {}  # sku -> quantity

    def add(self, sku: str, qty: int = 1) -> None:
        self.lines[sku] = self.lines.get(sku, 0) + qty

    def subtotal(self) -> int:
        return sum(self.catalog.get(s).price * q for s, q in self.lines.items())

    def discounts(self) -> int:
        return sum(r.discount(self.lines, self.catalog) for r in self.rules)

    def total(self) -> int:
        """subtotal - discounts, then tax on that DISCOUNTED amount, added on.
        Never negative."""
        sub = self.subtotal()
        disc = self.discounts()
        return max(0, sub - disc + tax(sub, self.tax_rate))
