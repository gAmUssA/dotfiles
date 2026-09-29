#!/usr/bin/env python3
"""Reconnect a saved Herdr profile without stopping its remote session.

Usage: ./herdr-reconnect.py [machine] [session] [--dry-run]
Defaults to ds9 / default. Requires Python 3 and herdr on PATH.
"""

import argparse
import json
import shlex
import subprocess
import sys


def profile_id(machine: str, session: str) -> str:
    result = subprocess.run(
        ["herdr", "machine", "list", "--json"],
        check=True,
        capture_output=True,
        text=True,
    )
    profiles = json.loads(result.stdout)
    if not isinstance(profiles, list) or not all(
        isinstance(profile, dict) for profile in profiles
    ):
        raise ValueError("Unexpected profile data; inspect `herdr machine list --json`.")
    matches = [
        profile
        for profile in profiles
        if machine in (profile.get("id"), profile.get("label"), profile.get("target"))
        and profile.get("session") == session
    ]
    if not matches:
        raise ValueError(
            f"No saved profile for {machine!r} / {session!r}; run `herdr machine list`."
        )
    if len(matches) != 1:
        raise ValueError("Multiple matching profiles; use a profile ID as the machine.")
    identifier = matches[0].get("id")
    if not isinstance(identifier, str) or not identifier:
        raise ValueError("Profile has no ID; inspect `herdr machine list --json`.")
    return identifier


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("machine", nargs="?", default="ds9", help="label, SSH target or profile ID")
    parser.add_argument("session", nargs="?", default="default", help="remote session name")
    parser.add_argument("--dry-run", action="store_true", help="show commands without reconnecting")
    args = parser.parse_args()

    try:
        identifier = profile_id(args.machine, args.session)
        disable = ["herdr", "machine", "disable", identifier]
        enable = ["herdr", "machine", "enable", identifier]
        if args.dry_run:
            print(shlex.join(disable))
            print(shlex.join(enable))
            return 0

        # Re-enable even if disable errors or the user interrupts that command.
        try:
            subprocess.run(disable, check=True)
        finally:
            try:
                subprocess.run(enable, check=True)
            except (OSError, subprocess.CalledProcessError, KeyboardInterrupt):
                print(f"Re-enable was not confirmed. Run: {shlex.join(enable)}", file=sys.stderr)
                raise
    except subprocess.CalledProcessError as error:
        if error.stderr:
            print(error.stderr.rstrip(), file=sys.stderr)
        print(
            f"Failed (exit {error.returncode}): {shlex.join(error.cmd)}",
            file=sys.stderr,
        )
        return 1
    except (OSError, ValueError) as error:
        print(f"Reconnect failed: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Interrupted; check the saved profile with `herdr machine list`.", file=sys.stderr)
        return 130

    print(f"Re-enabled {args.machine} / {args.session}; remote session left running.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
