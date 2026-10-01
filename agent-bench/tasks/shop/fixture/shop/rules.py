"""Discount rules. Each rule returns the discount it grants, in cents (>= 0)."""

from dataclasses import dataclass

from .money import to_cents


@dataclass(frozen=True)
class PercentOff:
    category: str
    percent: int

    def discount(self, lines, catalog) -> int:
        total = 0
        for sku, qty in lines.items():
            item = catalog.get(sku)
            if item.category == self.category:
                total += item.price * qty * self.percent // 100
        return total


@dataclass(frozen=True)
class BuyXGetY:
    """Buy `x` of a SKU, get `y` more of it free (repeats)."""
    sku: str
    x: int
    y: int

    def discount(self, lines, catalog) -> int:
        qty = lines.get(self.sku, 0)
        free = (qty // (self.x + self.y)) * self.y
        return free * catalog.get(self.sku).price


def parse_rule(spec: str):
    """Build a rule from its config string.

      "percent:<category>:<pct>"     PercentOff, e.g. "percent:books:10"
      "bxgy:<sku>:<x>:<y>"           BuyXGetY,   e.g. "bxgy:TEA-1:2:1"

    Raises ValueError for an unknown kind.
    """
    kind, *args = spec.strip().split(":")
    if kind == "percent":
        return PercentOff(args[0].lower(), int(args[1]))
    if kind == "bxgy":
        return BuyXGetY(args[0], int(args[1]), int(args[2]))
    raise ValueError(f"unknown rule: {spec!r}")
