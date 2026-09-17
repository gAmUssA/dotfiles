#!/usr/bin/env python3
"""Route a banner to its Herdr terminal and the iTerm session hosting it.

Uses the public pane.focus socket API: in Herdr 0.9.0 agent.focus does not
project explicit navigation to attached clients (headless/client_views.rs).
Only Python's standard library and macOS's ps/osascript are required.
"""

import argparse
import ctypes
import json
import os
from pathlib import Path
import shlex
import socket
import struct
import subprocess
import sys
import time


class RoutingError(Exception):
    pass


def request(socket_path, method, params):
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(5)
        connection.connect(socket_path)
        connection.sendall(json.dumps({
            "id": "notify", "method": method, "params": params,
        }).encode() + b"\n")
        with connection.makefile("rb") as stream:
            response = json.loads(stream.readline())
    if "error" in response:
        raise RoutingError(f"{method}: {response['error']}")
    return response["result"]


def focus_terminal(socket_path, terminal_id):
    # A pane can move to another workspace while its banner is visible. Its
    # public pane ID changes; its terminal ID does not. Never follow a reused
    # pane ID after a close or server restart.
    snapshot = request(socket_path, "session.snapshot", {})["snapshot"]
    matches = [p for p in snapshot["panes"] if p["terminal_id"] == terminal_id]
    if len(matches) != 1:
        raise RoutingError("notification terminal is no longer present")
    pane = request(socket_path, "pane.focus", {"pane_id": matches[0]["pane_id"]})["pane"]
    if pane["terminal_id"] != terminal_id or not pane["focused"]:
        raise RoutingError("server did not focus the notification terminal")
    return pane


def decode_procargs(data):
    """Decode macOS KERN_PROCARGS2 without logging the process environment."""
    argc = struct.unpack_from("i", data)[0]
    end = data.index(b"\0", 4)
    executable = os.fsdecode(data[4:end])
    values = data[end:].lstrip(b"\0").split(b"\0")
    args = [os.fsdecode(value) for value in values[:argc]]
    # Discard everything except routing inputs; shells can carry credentials.
    keys = {"HOME", "XDG_CONFIG_HOME", "HERDR_SESSION", "HERDR_SOCKET_PATH",
            "HERDR_CLIENT_SOCKET_PATH"}
    env = {}
    for value in values[argc:]:
        key, separator, value = value.partition(b"=")
        key = os.fsdecode(key)
        if separator and key in keys:
            env[key] = os.fsdecode(value)
    return executable, args, env


def process_context(pid):
    libc = ctypes.CDLL(None, use_errno=True)
    mib = (ctypes.c_int * 3)(1, 49, pid)  # CTL_KERN, KERN_PROCARGS2, pid
    size = ctypes.c_size_t(os.sysconf("SC_ARG_MAX"))
    buffer = ctypes.create_string_buffer(size.value)
    if libc.sysctl(mib, 3, buffer, ctypes.byref(size), None, 0):
        raise OSError(ctypes.get_errno(), "cannot read process routing context")
    return decode_procargs(buffer.raw[:size.value])


def client_socket(args, env):
    """Resolve only local TUI invocations, following Herdr's session precedence."""
    remaining = []
    session = None
    iterator = iter(args[1:])
    for arg in iterator:
        if arg == "--session":
            session = next(iterator, None)
            if session is None:
                return None
        elif arg.startswith("--session="):
            session = arg.partition("=")[2]
        elif arg != "--handoff":
            remaining.append(arg)
    if len(remaining) == 3 and remaining[:2] == ["session", "attach"]:
        session = remaining[2]
    elif remaining:
        # Excludes server, CLI queries, --remote, help, and unknown options.
        return None
    config = Path(env.get("XDG_CONFIG_HOME", str(Path(env.get("HOME", "~")) / ".config"))) / "herdr"
    if session is None:
        if env.get("HERDR_SOCKET_PATH"):
            return env["HERDR_SOCKET_PATH"]
        if env.get("HERDR_CLIENT_SOCKET_PATH"):
            # A legacy client-only override cannot safely identify its API.
            return None
        session = env.get("HERDR_SESSION", "default")
    if session != "default":
        config = config / "sessions" / session
    return str(config / "herdr.sock")


def client_ttys(socket_path, herdr_bin):
    output = subprocess.run(
        ["/bin/ps", "-axo", "pid=,tty=,comm="], check=True,
        capture_output=True, text=True, timeout=5,
    ).stdout
    ttys = []
    for line in output.splitlines():
        fields = line.split(None, 2)
        if len(fields) != 3:
            continue
        pid, tty, executable = fields
        if tty == "??" or Path(executable).name not in {"herdr", Path(herdr_bin).name}:
            continue
        try:
            _, args, env = process_context(int(pid))
            target = client_socket(args, env)
            if target and os.path.realpath(target) == os.path.realpath(socket_path):
                ttys.append("/dev/" + tty)
        except (OSError, ValueError):
            # The process may have exited since ps. Never guess its session.
            continue
    return list(dict.fromkeys(ttys))


FOCUS_ITERM = '''on run targetTTYs
  if application "iTerm" is not running then return "nomatch"
  tell application "iTerm"
    repeat with w in windows
      repeat with t in tabs of w
        repeat with s in sessions of t
          if targetTTYs contains (tty of s) then
            select w
            select t
            select s
            set miniaturized of w to false
            set index of w to 1
            activate
            return "matched|" & (tty of s)
          end if
        end repeat
      end repeat
    end repeat
  end tell
  return "nomatch"
end run
'''

OPEN_ITERM = '''on run argv
  tell application "iTerm"
    set w to (create window with default profile)
    tell current session of w to write text (item 1 of argv)
    activate
    return "opened"
  end tell
end run
'''


def applescript(source, args):
    result = subprocess.run(
        ["/usr/bin/osascript", "-", *args], input=source, text=True,
        capture_output=True, timeout=15,
    )
    if result.returncode:
        raise RoutingError(f"iTerm Automation failed: {result.stderr.strip()}")
    return result.stdout.strip()


def attach_command(socket_path, herdr_bin):
    # Explicit --session overrides HERDR_SOCKET_PATH, so pass only the socket.
    # Clear inherited pane context if iTerm's default profile sets it.
    return shlex.join([
        "/usr/bin/env", "-u", "HERDR_ENV", "-u", "HERDR_SESSION",
        "-u", "HERDR_CLIENT_SOCKET_PATH", "-u", "HERDR_PANE_ID",
        "-u", "HERDR_TAB_ID", "-u", "HERDR_WORKSPACE_ID",
        "HERDR_SOCKET_PATH=" + socket_path, herdr_bin,
    ])


def route(socket_path, terminal_id, herdr_bin):
    focus_terminal(socket_path, terminal_id)
    ttys = client_ttys(socket_path, herdr_bin)
    result = applescript(FOCUS_ITERM, ttys) if ttys else "nomatch"
    if result == "nomatch":
        # Detached session, stale tty, or a different terminal app: open an
        # explicit attachment, never merely activate an unrelated iTerm tab.
        result = applescript(OPEN_ITERM, [attach_command(socket_path, herdr_bin)])
        if result != "opened":
            raise RoutingError("iTerm did not open a client")
        # Attaching initializes a per-client view. Reapply pane.focus once the
        # client exists, including its workspace/tab projection.
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            ttys = client_ttys(socket_path, herdr_bin)
            if ttys:
                result = applescript(FOCUS_ITERM, ttys)
                if result.startswith("matched|"):
                    break
            time.sleep(0.2)
        else:
            raise RoutingError("timed out waiting for the iTerm Herdr client")
    if not result.startswith("matched|"):
        raise RoutingError(f"iTerm did not select a client: {result}")
    pane = focus_terminal(socket_path, terminal_id)
    return f"focused {pane['workspace_id']}/{pane['tab_id']}/{pane['pane_id']} {result}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--socket", required=True)
    parser.add_argument("--terminal", required=True)
    parser.add_argument("--herdr-bin", required=True)
    args = parser.parse_args()
    try:
        print(route(args.socket, args.terminal, args.herdr_bin))
    except (OSError, ValueError, KeyError, RoutingError, subprocess.SubprocessError) as error:
        print(f"notification routing failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
