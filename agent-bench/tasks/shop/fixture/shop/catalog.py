"""Product catalog loaded from CSV text."""

import csv
import io
from dataclasses import dataclass

from .money import to_cents


@dataclass(frozen=True)
class Item:
    sku: str
    name: str
    price: int  # cents
    category: str


class Catalog:
    """SKUs are case-insensitive everywhere: "ab-1", "AB-1" and " Ab-1 " are
    the same product. Categories are compared lower-case."""

    def __init__(self, csv_text: str) -> None:
        self._items: dict[str, Item] = {}
        for row in csv.DictReader(io.StringIO(csv_text.strip())):
            item = Item(
                sku=row["sku"].strip(),
                name=row["name"].strip(),
                price=to_cents(row["price"]),
                category=row["category"].strip().lower(),
            )
            self._items[item.sku] = item

    def get(self, sku: str) -> Item:
        return self._items[sku]
