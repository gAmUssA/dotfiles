"""Regression checks: python3 -B -m unittest discover -s herdr-plugins/notify."""

import importlib.util
import json
import os
from pathlib import Path
import shlex
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("focus", Path(__file__).with_name("focus.py"))
focus = importlib.util.module_from_spec(spec)
spec.loader.exec_module(focus)

PANE = {"pane_id": "w2:p3", "terminal_id": "term_target", "workspace_id": "w2",
        "tab_id": "w2:t2", "focused": True, "agent": None}


class ClientTests(unittest.TestCase):
    def test_exact_session_and_supported_attach_forms(self):
        env = {"HOME": "/home/test"}
        for args in (["herdr", "--session", "work"],
                     ["herdr", "--session=work"],
                     ["herdr", "session", "attach", "work"]):
            with self.subTest(args=args):
                self.assertEqual(focus.client_socket(args, env),
                                 "/home/test/.config/herdr/sessions/work/herdr.sock")
        self.assertNotEqual(focus.client_socket(["herdr", "--session", "work-extra"], env),
                            focus.client_socket(["herdr", "--session", "work"], env))

    def test_default_and_inherited_session(self):
        env = {"HOME": "/home/test", "HERDR_SESSION": "work"}
        self.assertIn("/sessions/work/", focus.client_socket(["herdr"], env))
        self.assertEqual(focus.client_socket(["herdr", "--session", "default"], env),
                         "/home/test/.config/herdr/herdr.sock")
        self.assertEqual(focus.client_socket(["herdr"], {"HOME": "/home/test"}),
                         "/home/test/.config/herdr/herdr.sock")

    def test_socket_precedence_and_custom_config_root(self):
        env = {"XDG_CONFIG_HOME": "/config space", "HERDR_SESSION": "other",
               "HERDR_SOCKET_PATH": "/custom/server.sock"}
        self.assertEqual(focus.client_socket(["herdr"], env), "/custom/server.sock")
        self.assertEqual(focus.client_socket(["herdr", "--session", "work"], env),
                         "/config space/herdr/sessions/work/herdr.sock")
        self.assertIsNone(focus.client_socket(["herdr"], {"HERDR_CLIENT_SOCKET_PATH": "/legacy"}))

    def test_remote_and_cli_processes_are_not_local_clients(self):
        for args in (["--remote", "host", "--session", "work"],
                     ["--session", "work", "server"],
                     ["--session", "work", "agent", "get", "w1:p1"],
                     ["session", "list"], ["--help"], ["--session"]):
            with self.subTest(args=args):
                self.assertIsNone(focus.client_socket(["herdr", *args], {}))

    def test_procargs_preserves_spaces_and_filters_environment(self):
        data = (struct.pack("i", 3) + b"/opt/herdr\0\0herdr\0--session\0work\0"
                b"HOME=/home/test user\0SECRET=do-not-retain\0"
                b"HERDR_SOCKET_PATH=/tmp/socket space/herdr.sock\0\0")
        executable, args, env = focus.decode_procargs(data)
        self.assertEqual(executable, "/opt/herdr")
        self.assertEqual(args, ["herdr", "--session", "work"])
        self.assertEqual(env, {"HOME": "/home/test user",
                               "HERDR_SOCKET_PATH": "/tmp/socket space/herdr.sock"})

    def test_all_matching_client_ttys_are_considered(self):
        with patch.object(focus.subprocess, "run") as run, patch.object(focus, "process_context") as context:
            run.return_value.stdout = "1 ?? /opt/herdr\n2 ttys001 /opt/herdr\n3 ttys002 herdr\n4 ttys003 herdr\n"
            context.side_effect = [
                ("herdr", ["herdr", "--session", "work-extra"], {"HOME": "/home/test"}),
                ("herdr", ["herdr", "--session=work"], {"HOME": "/home/test"}),
                ("herdr", ["herdr"], {"HERDR_SOCKET_PATH": "/home/test/.config/herdr/sessions/work/herdr.sock"}),
            ]
            self.assertEqual(focus.client_ttys("/home/test/.config/herdr/sessions/work/herdr.sock", "/opt/herdr"),
                             ["/dev/ttys002", "/dev/ttys003"])


class RoutingTests(unittest.TestCase):
    def test_automation_failure_preserves_the_os_error(self):
        with patch.object(focus.subprocess, "run") as run:
            run.return_value.returncode = 1
            run.return_value.stderr = "Not authorized to send Apple events to iTerm. (-1743)"
            with self.assertRaisesRegex(focus.RoutingError, "Not authorized"):
                focus.applescript(focus.FOCUS_ITERM, ["/dev/ttys001"])

    def test_moved_pane_and_exited_agent_use_terminal_identity_and_pane_focus(self):
        with patch.object(focus, "request") as request:
            request.side_effect = [{"snapshot": {"panes": [PANE]}}, {"pane": PANE}]
            self.assertEqual(focus.focus_terminal("/session.sock", "term_target"), PANE)
            self.assertEqual(request.call_args_list[1].args,
                             ("/session.sock", "pane.focus", {"pane_id": "w2:p3"}))

    def test_closed_or_replaced_terminal_cannot_focus_another_pane(self):
        with patch.object(focus, "request") as request:
            request.return_value = {"snapshot": {"panes": [{**PANE, "terminal_id": "term_replacement"}]}}
            with self.assertRaises(focus.RoutingError):
                focus.focus_terminal("/session.sock", "term_target")
            self.assertEqual(request.call_count, 1)

    def test_failed_focus_never_raises_iterm(self):
        with patch.object(focus, "focus_terminal", side_effect=focus.RoutingError("missing")), \
                patch.object(focus, "applescript") as script:
            with self.assertRaises(focus.RoutingError):
                focus.route("/session.sock", "term_target", "/opt/herdr")
            script.assert_not_called()

    def test_attached_client_reapplies_focus_after_selecting_iterm(self):
        with patch.object(focus, "focus_terminal", return_value=PANE) as pane_focus, \
                patch.object(focus, "client_ttys", return_value=["/dev/ttys001"]), \
                patch.object(focus, "applescript", return_value="matched|/dev/ttys001") as script:
            self.assertIn("w2/w2:t2/w2:p3", focus.route("/session.sock", "term_target", "/opt/herdr"))
            self.assertEqual(pane_focus.call_count, 2)
            self.assertEqual(script.call_count, 1)

    def test_unmatched_tty_opens_the_originating_socket(self):
        with patch.object(focus, "focus_terminal", return_value=PANE), \
                patch.object(focus, "client_ttys", return_value=["/dev/ttys001"]), \
                patch.object(focus, "applescript", side_effect=["nomatch", "opened", "matched|/dev/ttys002"]) as script:
            focus.route("/socket space/session.sock", "term_target", "/opt/bin/herdr")
            command = shlex.split(script.call_args_list[1].args[1][0])
            self.assertIn("HERDR_SOCKET_PATH=/socket space/session.sock", command)
            self.assertEqual(command[-1], "/opt/bin/herdr")
            self.assertNotIn("--session", command)

    def test_detached_client_is_focused_after_attach(self):
        with patch.object(focus, "focus_terminal", return_value=PANE), \
                patch.object(focus, "client_ttys", side_effect=[[], ["/dev/ttys002"]]), \
                patch.object(focus, "applescript", side_effect=["opened", "matched|/dev/ttys002"]) as script:
            focus.route("/session.sock", "term_target", "/opt/herdr")
            self.assertEqual(script.call_args_list[0].args[0], focus.OPEN_ITERM)

    def test_attach_command_quotes_shell_metacharacters(self):
        command = focus.attach_command("/tmp/'$(bad)/server.sock", "/app space/herdr")
        self.assertEqual(shlex.split(command)[-2:],
                         ["HERDR_SOCKET_PATH=/tmp/'$(bad)/server.sock", "/app space/herdr"])


class NotificationTests(unittest.TestCase):
    def run_hook(self, socket_path, pane="w1:p1", status="done", click="@TIMEOUT", terminal="term_target"):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            alerter = root / "alerter"
            alerter.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > "$TEST_ARGS"\nprintf "%s" "$TEST_CLICK"\n')
            alerter.chmod(0o755)
            herdr = root / "herdr"
            herdr.write_text('#!/bin/bash\nprintf "%s" "$TEST_DETAIL"\n')
            herdr.chmod(0o755)
            python = root / "python3"
            python.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > "$TEST_ROUTE"\n')
            python.chmod(0o755)
            env = {**os.environ, "HERDR_BIN_PATH": str(herdr), "HERDR_NOTIFY_ALERTER": str(alerter),
                   "HERDR_SOCKET_PATH": socket_path, "HERDR_PLUGIN_STATE_DIR": directory,
                   "HERDR_NOTIFY_DEBUG": "1", "PATH": directory + ":" + os.environ["PATH"],
                   "TEST_ARGS": str(root / "args"), "TEST_CLICK": click, "TEST_ROUTE": str(root / "route"),
                   "TEST_DETAIL": json.dumps({"result": {"agent": {"terminal_id": terminal}}}),
                   "HERDR_PANE_ID": "w9:p9",  # payload must win over caller context
                   "HERDR_PLUGIN_EVENT_JSON": json.dumps({"data": {"pane_id": pane, "agent_status": status}})}
            subprocess.run(["bash", str(Path(__file__).with_name("notify.sh"))], env=env,
                           capture_output=True, check=True, timeout=5)
            args = (root / "args").read_text().splitlines() if (root / "args").exists() else []
            route = (root / "route").read_text().splitlines() if (root / "route").exists() else []
            return args, route

    def test_group_is_scoped_to_socket_and_pane(self):
        def group(socket, pane="w1:p1"):
            args, _ = self.run_hook(socket, pane)
            return args[args.index("--group") + 1]
        self.assertNotEqual(group("/one.sock"), group("/two.sock"))
        self.assertNotEqual(group("/one.sock"), group("/one.sock", "w1:p2"))
        self.assertEqual(group("/one.sock"), group("/one.sock"))

    def test_content_click_carries_socket_and_terminal_identity(self):
        _, route = self.run_hook("/one.sock", click="@CONTENTCLICKED")
        self.assertEqual(route[1:5], ["--socket", "/one.sock", "--terminal", "term_target"])

    def test_timeout_dismiss_and_missing_identity_do_not_route(self):
        for click in ("@TIMEOUT", "@CLOSED"):
            self.assertEqual(self.run_hook("/one.sock", click=click)[1], [])
        self.assertEqual(self.run_hook("/one.sock", click="@CONTENTCLICKED", terminal="")[1], [])

    def test_only_actionable_states_notify(self):
        for status in ("working", "idle", "unknown"):
            self.assertEqual(self.run_hook("/one.sock", status=status), ([], []))
        self.assertIn("needs your input", self.run_hook("/one.sock", status="blocked")[0])


if __name__ == "__main__":
    unittest.main()
