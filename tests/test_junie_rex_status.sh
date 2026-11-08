#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
script="$repo/junie/rex-status.sh"
hooks="$repo/junie/rex-hooks.json"

jq -e '.hooks.SessionStart and .hooks.UserPromptSubmit and .hooks.PreToolUse and
  .hooks.PermissionRequest and .hooks.Stop and .hooks.StopFailure and .hooks.SessionEnd' \
  "$hooks" >/dev/null || fail 'hook configuration is incomplete or invalid JSON'
printf 'PASS: hook configuration covers the planned lifecycle events\n'

python3 - "$script" <<'PY'
import errno
import json
import os
import pty
import select
import signal
import subprocess
import sys
import time
import tty

script = sys.argv[1]
ESC = b"\x1b"


def fail(message):
    raise SystemExit(f"FAIL: {message}")


def run_pty(event, payload=None, rex=True, tmux=False):
    pid, master = pty.fork()
    if pid == 0:
        if rex:
            os.environ["REX_BLOCK"] = "test-block"
        else:
            os.environ.pop("REX_BLOCK", None)
        if tmux:
            os.environ["TMUX"] = "/tmp/tmux-test"
        else:
            os.environ.pop("TMUX", None)
        os.execv("/bin/sh", ["sh", script, event])

    tty.setraw(master)
    if payload is not None:
        os.write(master, json.dumps(payload).encode() + b"\n")

    output = bytearray()
    deadline = time.monotonic() + 5
    status = None
    while time.monotonic() < deadline:
        ready, _, _ = select.select([master], [], [], 0.05)
        if ready:
            try:
                chunk = os.read(master, 4096)
                if chunk:
                    output.extend(chunk)
            except OSError as exc:
                if exc.errno != errno.EIO:
                    raise
        waited, status = os.waitpid(pid, os.WNOHANG)
        if waited == pid:
            break
    else:
        os.kill(pid, signal.SIGKILL)
        os.waitpid(pid, 0)
        fail(f"{event} hook did not exit")

    while True:
        try:
            chunk = os.read(master, 4096)
            if not chunk:
                break
            output.extend(chunk)
        except OSError as exc:
            if exc.errno == errno.EIO:
                break
            raise
    os.close(master)
    if not os.waitstatus_to_exitcode(status) == 0:
        fail(f"{event} hook exited unsuccessfully")
    return bytes(output)


def osc(body):
    return ESC + b"]7501;" + body.encode() + ESC + b"\\"


cases = [
    ("SessionStart", {"source": "startup"}, "state=idle:id=junie:app=junie"),
    ("SessionStart", {"source": "resume"}, "state=idle:id=junie:app=junie"),
    ("SessionStart", {"source": "clear"}, "state=idle:id=junie:app=junie"),
    ("UserPromptSubmit", {}, "state=working:id=junie:app=junie"),
    ("PreToolUse", {}, "state=working:id=junie:app=junie"),
    ("PermissionRequest", {}, "state=blocked:kind=permission:id=junie:app=junie"),
    ("Stop", {}, "state=done:id=junie:app=junie"),
    ("StopFailure", {}, "state=error:id=junie:app=junie"),
    ("SessionEnd", {}, "state=clear:id=junie"),
]
for event, payload, report in cases:
    actual = run_pty(event, payload)
    if actual != osc(report):
        fail(f"{event} emitted unexpected bytes: {actual!r}")

if run_pty("SessionStart", {"source": "compact"}) != b"":
    fail("compaction must not overwrite the current turn status")
if run_pty("UserPromptSubmit", {}, rex=False) != b"":
    fail("non-Rex terminal must not receive a status report")
if run_pty("UserPromptSubmit", {}, tmux=True) != (
    ESC + b"Ptmux;" + ESC + ESC + b"]7501;state=working:id=junie:app=junie"
    + ESC + ESC + b"\\" + ESC + b"\\"
):
    fail("tmux status report is not wrapped for passthrough")

env = dict(os.environ, REX_BLOCK="test-block")
result = subprocess.run(
    ["/bin/sh", script, "UserPromptSubmit"],
    input=b"{}\n",
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    env=env,
    start_new_session=True,
    check=False,
)
if result.returncode or result.stdout or result.stderr:
    fail("missing controlling terminal should be a silent no-op")

print("PASS: lifecycle, compact, non-Rex, tmux, and no-terminal cases")
PY