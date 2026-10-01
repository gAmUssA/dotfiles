"""A tiny in-memory ledger."""

from dataclasses import dataclass
from datetime import date

from .money import parse_amount


@dataclass(frozen=True)
class Txn:
    day: date
    amount: int  # cents; negative = expense, positive = income
    category: str


class Ledger:
    def __init__(self) -> None:
        self._txns: list[Txn] = []

    def add(self, day: str, amount: str, category: str) -> Txn:
        """Add a transaction. `day` is ISO "YYYY-MM-DD", `amount` as parse_amount."""
        txn = Txn(date.fromisoformat(day), parse_amount(amount), category.strip().lower())
        self._txns.append(txn)
        return txn

    def balance(self) -> int:
        """Net of all transactions, in cents."""
        return sum(t.amount for t in self._txns)

    def by_category(self) -> dict[str, int]:
        """Net amount per category, in cents."""
        totals: dict[str, int] = {}
        for t in self._txns:
            totals[t.category] = totals.get(t.category, 0) + abs(t.amount)
        return totals

    def monthly_totals(self) -> list[tuple[str, int, int]]:
        """Per-month summary, sorted by month ascending.

        Returns a list of (month, income, expenses) tuples where month is
        "YYYY-MM", income is the sum of positive amounts and expenses is the
        sum of negative amounts as a POSITIVE number, both in cents. Months
        with no transactions are omitted.

        Example: a $100 paycheck and a $30.25 expense in March 2026 give
        [("2026-03", 10000, 3025)].
        """
        raise NotImplementedError
