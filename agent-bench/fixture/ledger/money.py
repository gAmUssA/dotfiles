"""Money helpers. Amounts are always integer cents internally."""


def parse_amount(text: str) -> int:
    """Parse a human amount into integer cents.

    Accepts an optional leading "-" or "$", thousands separators and up to two
    decimals:  "12" -> 1200, "$1,234.50" -> 123450, "-3.5" -> -350, "0.07" -> 7.
    Raises ValueError on anything else (empty string, letters, three decimals).
    """
    s = text.strip()
    negative = s.startswith("-")
    if negative:
        s = s[1:]
    if s.startswith("$"):
        s = s[1:]
    if not s:
        raise ValueError(f"not an amount: {text!r}")
    whole, _, frac = s.partition(".")
    if len(frac) > 2:
        raise ValueError(f"too many decimals: {text!r}")
    if not whole.isdigit() or (frac and not frac.isdigit()):
        raise ValueError(f"not an amount: {text!r}")
    cents = int(whole) * 100 + int(frac or 0)
    return -cents if negative else cents


def format_amount(cents: int) -> str:
    """Format integer cents as "$1,234.50" / "-$3.50"."""
    sign = "-" if cents < 0 else ""
    cents = abs(cents)
    return f"{sign}${cents // 100:,}.{cents % 100:02d}"
