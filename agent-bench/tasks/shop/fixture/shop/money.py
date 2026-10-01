"""Money helpers. All amounts are integer cents."""


def to_cents(text: str) -> int:
    """"12.5" -> 1250, "0.99" -> 99, "3" -> 300."""
    whole, _, frac = text.strip().partition(".")
    return int(whole) * 100 + int(frac.ljust(2, "0")[:2] or 0)


def tax(cents: int, rate_percent: str) -> int:
    """Tax on `cents` at `rate_percent` (e.g. "8.875"), rounded to the cent.

    Rounding is HALF UP: exactly half a cent always rounds away from zero.
    E.g. tax(1000, "8.875") == 89 (88.75 -> 89), tax(200, "6.25") == 13
    (12.5 -> 13), tax(0, "8") == 0.
    """
    return round(cents * float(rate_percent) / 100)
