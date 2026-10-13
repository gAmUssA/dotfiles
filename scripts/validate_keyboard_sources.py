# /// script
# requires-python = ">=3.9"
# dependencies = []
# ///
"""Validate a Birman bundle/preferences pair without rewriting its layout XML."""

import plistlib
import sys
from pathlib import Path
from xml.parsers import expat


class KeyboardHeader(Exception):
    def __init__(self, attributes: dict[str, str]) -> None:
        super().__init__()
        self.attributes = attributes


def layout_identity(path: Path) -> tuple[int, str]:
    parser = expat.ParserCreate()

    def first_element(name: str, attributes: dict[str, str]) -> None:
        if name != "keyboard":
            raise ValueError(f"{path.name}: expected a keyboard root element")
        # Stop at the header: legacy control references in the body are valid
        # for macOS but rejected by this XML parser. Never rewrite the source.
        raise KeyboardHeader(attributes)

    parser.StartElementHandler = first_element
    try:
        with path.open("rb") as source:
            while chunk := source.read(4096):
                parser.Parse(chunk, False)
            parser.Parse(b"", True)
    except KeyboardHeader as header:
        name = header.attributes["name"]
        if not name:
            raise ValueError(f"{path.name}: empty keyboard name")
        return int(header.attributes["id"]), name
    raise ValueError(f"{path.name}: missing keyboard header")


def matches(entry: dict, identity: tuple[int, str]) -> bool:
    layout_id, name = identity
    return (
        entry.get("InputSourceKind") == "Keyboard Layout"
        and type(entry.get("KeyboardLayout ID")) is int
        and entry["KeyboardLayout ID"] == layout_id
        and entry.get("KeyboardLayout Name") == name
    )


def source_entries(preferences: dict, key: str) -> list[dict]:
    entries = preferences[key]
    if not isinstance(entries, list) or not all(isinstance(e, dict) for e in entries):
        raise ValueError(f"{key} must be an array of input-source dictionaries")
    return entries


def validate(bundle: Path, preferences_path: Path) -> None:
    with (bundle / "Contents/Info.plist").open("rb") as source:
        info = plistlib.load(source)
    with preferences_path.open("rb") as source:
        preferences = plistlib.load(source)
    bundle_id = info["CFBundleIdentifier"]
    if not isinstance(bundle_id, str) or not bundle_id:
        raise ValueError("CFBundleIdentifier must be a nonempty string")

    identities: dict[str, tuple[int, str]] = {}
    for language in ("English", "Russian"):
        resource = f"{language} - Ilya Birman Typography"
        identity = layout_identity(bundle / f"Contents/Resources/{resource}.keylayout")
        source_id = info[f"KLInfo_{resource}"]["TISInputSourceID"]
        if not isinstance(source_id, str) or not source_id.startswith(bundle_id + "."):
            raise ValueError(f"{language} TISInputSourceID does not belong to this bundle")
        if source_id in identities or any(
            identity[0] == other[0] or identity[1] == other[1]
            for other in identities.values()
        ):
            raise ValueError("English/Russian layout names and IDs must be distinct")
        identities[source_id] = identity

    enabled = source_entries(preferences, "AppleEnabledInputSources")
    for identity in identities.values():
        candidates = [
            entry for entry in enabled
            if entry.get("KeyboardLayout ID") == identity[0]
            or entry.get("KeyboardLayout Name") == identity[1]
        ]
        if len(candidates) != 1 or not matches(candidates[0], identity):
            raise ValueError(f"enabled input source does not match {identity[1]}")

    current = preferences["AppleCurrentKeyboardLayoutInputSourceID"]
    if not isinstance(current, str) or current not in identities:
        raise ValueError("current input-source ID does not belong to the bundled layouts")
    selected = [
        entry for entry in source_entries(preferences, "AppleSelectedInputSources")
        if entry.get("InputSourceKind") == "Keyboard Layout"
        or "KeyboardLayout ID" in entry or "KeyboardLayout Name" in entry
    ]
    if len(selected) != 1 or not matches(selected[0], identities[current]):
        raise ValueError("selected keyboard does not match the current bundled input source")


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: validate_keyboard_sources.py BUNDLE PREFERENCES", file=sys.stderr)
        return 2
    try:
        validate(Path(sys.argv[1]), Path(sys.argv[2]))
    except (OSError, ValueError, KeyError, TypeError, expat.ExpatError) as error:
        print(f"error: bundle/input-source mismatch: {error}", file=sys.stderr)
        print("Install and enable both edited layouts, select one, then export again.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
