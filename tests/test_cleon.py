"""Run with: python3 tests/test_cleon.py

Drives the real `claude` through `cleon` in a terminal, in a throwaway HOME, against a local API.
install.sh writes the hooks into that HOME, so a broken install fails here too. Needs `claude`,
`jq` and a real login in ~/.claude.json (only its settings are copied, never the login).
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import pty
import select
import shutil
import subprocess
import tempfile
import threading
import time
import unittest

REPO = Path(__file__).resolve().parents[1]
CLEON = REPO / "bin" / "cleon"
REAL = Path.home()
SSE = [
    ("message_start", {"type": "message_start", "message": {
        "id": "msg_test", "type": "message", "role": "assistant", "model": "test", "content": [],
        "stop_reason": None, "stop_sequence": None,
        "usage": {"input_tokens": 1, "output_tokens": 1}}}),
    ("content_block_start", {"type": "content_block_start", "index": 0,
                             "content_block": {"type": "text", "text": ""}}),
    ("content_block_delta", {"type": "content_block_delta", "index": 0,
                             "delta": {"type": "text_delta", "text": "hi"}}),
    ("content_block_stop", {"type": "content_block_stop", "index": 0}),
    ("message_delta", {"type": "message_delta", "usage": {"output_tokens": 1},
                       "delta": {"stop_reason": "end_turn", "stop_sequence": None}}),
    ("message_stop", {"type": "message_stop"}),
]


# The agent's one step in mode "tool": run `true` in the shell.
TOOL_SSE = [SSE[0],
            ("content_block_start", {"type": "content_block_start", "index": 0, "content_block": {
                "type": "tool_use", "id": "toolu_test", "name": "Bash", "input": {}}}),
            ("content_block_delta", {"type": "content_block_delta", "index": 0, "delta": {
                "type": "input_json_delta",
                "partial_json": json.dumps({"command": "true", "description": "one step"})}}),
            ("content_block_stop", {"type": "content_block_stop", "index": 0}),
            ("message_delta", {"type": "message_delta", "usage": {"output_tokens": 1},
                               "delta": {"stop_reason": "tool_use", "stop_sequence": None}}),
            ("message_stop", {"type": "message_stop"})]


def quota(path, used, age=0, resets_in=86400):
    path.write_text(json.dumps({"updated_at": time.time() - age, "seven_day": {
        "used_percentage": used, "resets_at": int(time.time()) + resets_in}}))


class Api(BaseHTTPRequestHandler):
    """mode "limit": refuse every request. mode "ok": answer, and mark main's week 96% used.
    mode "tool": main's week is 96% used at once, and the first chat request runs one tool."""
    mode, home, tool_ran, nudged = "limit", Path(), False, False

    def do_POST(self):
        req = json.loads(self.rfile.read(int(self.headers.get("content-length", 0))) or b"{}")
        if self.mode == "limit":
            body = json.dumps({"type": "error", "error": {"type": "rate_limit_error",
                                                          "message": "test usage limit"}})
            return self.reply(429, "application/json", body,
                              {"anthropic-ratelimit-unified-status": "rejected",
                               "x-should-retry": "false"})
        events = SSE
        if self.mode == "tool":
            quota(self.home / ".claude" / "quota.json", 96)
            Api.nudged = Api.nudged or "safe stopping point" in json.dumps(req)
            if req.get("stream") and req.get("tools") and not Api.tool_ran:
                Api.tool_ran, events = True, TOOL_SSE
        else:
            # Like the status line: the new figure lands just after the reply, as the turn ends.
            threading.Timer(1, quota, (self.home / ".claude" / "quota.json", 96)).start()
        if req.get("stream"):
            body = "".join(f"event: {e}\ndata: {json.dumps(d)}\n\n" for e, d in events)
            return self.reply(200, "text/event-stream", body)
        msg = dict(SSE[0][1]["message"], content=[{"type": "text", "text": "hi"}],
                   stop_reason="end_turn")
        self.reply(200, "application/json", json.dumps(msg))

    def reply(self, code, kind, body, headers={}):
        data = body.encode()
        self.send_response(code)
        for k, v in {"content-type": kind, "content-length": str(len(data)), **headers}.items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        self.reply(404, "application/json", "{}")

    def log_message(self, format, *args):
        pass


def run_in_terminal(argv, env, cwd, until=None, timeout=120):
    """Run argv in a terminal; stop at exit, at timeout, or 3 s after `until` shows."""
    main, child = pty.openpty()
    proc = subprocess.Popen(argv, stdin=child, stdout=child, stderr=child, env=env, cwd=cwd,
                            start_new_session=True)
    os.close(child)
    out, deadline = b"", time.time() + timeout
    while time.time() < deadline:
        if select.select([main], [], [], 0.5)[0]:
            try:
                chunk = os.read(main, 65536)
            except OSError:
                break
            if not chunk:  # every writer closed the terminal
                break
            out += chunk
            if until and until.encode() in out:
                deadline = min(deadline, time.time() + 3)
        elif proc.poll() is not None:
            break
    # Close the terminal first: a process that exits waits until its output is read.
    os.close(main)
    try:
        os.killpg(proc.pid, 9)  # cleon, and anything claude left in its group
    except OSError:
        pass
    return proc.wait(), out.decode("utf8", "replace")


class CleonTest(unittest.TestCase):
    def setUp(self):
        self.home = Path(tempfile.mkdtemp()).resolve()  # claude trusts the real path
        self.cwd = self.home / "project"
        self.cwd.mkdir()
        claude = self.home / ".claude"
        claude.mkdir()
        # Your own status line, at the same file name as cleon's: install.sh must keep it.
        (claude / "hooks").mkdir()
        (claude / "hooks" / "statusline.py").write_text("print('mine')\n")
        (claude / "settings.json").write_text(json.dumps({
            "skipDangerousModePermissionPrompt": True, "statusLine": {
                "type": "command", "command": f'python3 "{claude}/hooks/statusline.py"'}}))
        config = json.loads((REAL / ".claude.json").read_text())
        config["projects"] = {str(self.cwd): {"hasTrustDialogAccepted": True}}
        (self.home / ".claude.json").write_text(json.dumps(config))
        (self.home / ".cleon" / "b").mkdir(parents=True)
        config["oauthAccount"] = {"emailAddress": "b@test"}
        (self.home / ".cleon" / "b" / ".claude.json").write_text(json.dumps(config))
        Api.home, Api.tool_ran, Api.nudged = self.home, False, False
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Api)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.env = {k: v for k, v in os.environ.items() if not k.startswith("CLAUDE")}
        self.env.update(HOME=str(self.home), TERM="xterm-256color", CLAUDE_CODE_MAX_RETRIES="0",
                        ANTHROPIC_BASE_URL=f"http://127.0.0.1:{self.server.server_port}",
                        ANTHROPIC_AUTH_TOKEN="test")
        subprocess.run([str(REPO / "install.sh")], env=self.env, check=True, capture_output=True)

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        shutil.rmtree(self.home)

    def chat(self):
        chats = list((self.home / ".claude" / "projects").glob("*/*.jsonl"))
        self.assertEqual(len(chats), 1, chats)
        return chats[0].read_text(errors="replace")

    def test_limit_moves_the_chat_to_the_next_account(self):
        Api.mode = "limit"
        # Superset starts claude with this flag; the resumed chat must keep it.
        argv = [str(CLEON), "--dangerously-skip-permissions", "say hi"]
        waiting = "every account is out of room. Waiting until"
        _, out = run_in_terminal(argv, self.env, self.cwd, until=waiting)
        self.assertIn("main hit its limit. Continuing on b.", out)
        self.assertIn(waiting, out)
        self.assertTrue((self.home / ".cleon" / "b" / "projects").is_symlink())
        resumed = [line for line in self.chat().splitlines() if "Continue where you stopped." in line]
        self.assertIn('"permissionMode":"bypassPermissions"', resumed[0])

    def test_limit_with_auto_resume_off_opens_the_chat_and_waits(self):
        subprocess.run([str(CLEON), "resume", "off"], env=self.env, check=True, capture_output=True)
        Api.mode = "limit"
        moved = "main hit its limit. Continuing on b (auto-resume is off)."
        _, out = run_in_terminal([str(CLEON), "say hi"], self.env, self.cwd, until=moved)
        self.assertIn(moved, out)
        self.assertNotIn("Continue where you stopped.", self.chat())

    def test_reserve_pauses_the_work_and_the_next_account_resumes_it(self):
        Api.mode = "tool"
        quota(self.home / ".claude" / "quota.json", 50, age=60)
        moved = "main paused its work at its 5% weekly reserve. Continuing on b."
        _, out = run_in_terminal([str(CLEON), "do the task"], self.env, self.cwd, until="Resume the paused work")
        self.assertTrue(Api.nudged, "the agent was asked to pause at a safe point")
        self.assertIn(moved, out)
        self.assertIn("Resume the paused work", self.chat())

    def test_install_keeps_your_status_line_and_runs_twice(self):
        subprocess.run([str(REPO / "install.sh")], env=self.env, check=True, capture_output=True)
        settings = json.loads((self.home / ".claude" / "settings.json").read_text())
        self.assertEqual(len(settings["hooks"]["Stop"]), 1, "a second install adds no hooks")
        self.assertIn("hooks/cleon-statusline.py", settings["statusLine"]["command"])
        line = subprocess.run(["sh", "-c", settings["statusLine"]["command"]], env=self.env,
                              input='{"rate_limits": {"seven_day": {"used_percentage": 40, '
                                    '"resets_at": 9999999999}}}',
                              capture_output=True, text=True).stdout
        self.assertEqual(line.strip(), "mine")
        saved = json.loads((self.home / ".claude" / "quota.json").read_text())
        self.assertEqual(saved["seven_day"]["used_percentage"], 40)

        subprocess.run([str(REPO / "install.sh"), "--uninstall"], env=self.env, check=True,
                       capture_output=True)
        settings = json.loads((self.home / ".claude" / "settings.json").read_text())
        self.assertIn(".claude/hooks/statusline.py", settings["statusLine"]["command"])
        self.assertNotIn("cleon-swap.sh", json.dumps(settings))

    def test_the_reserve_can_be_changed(self):
        subprocess.run([str(CLEON), "reserve", "60"], env=self.env, check=True, capture_output=True)
        quota(self.home / ".claude" / "quota.json", 50)
        _, out = run_in_terminal([str(CLEON), "--version"], self.env, self.cwd)
        self.assertIn("cleon: main is down to its 60% weekly reserve. Starting on b.", out)

    def test_an_upper_case_name_is_refused(self):
        run = subprocess.run([str(CLEON), "add", "WORK"], env=self.env, capture_output=True,
                             text=True)
        self.assertEqual(run.returncode, 2)
        self.assertIn("not a valid name", run.stderr)
        self.assertFalse((self.home / ".cleon" / "WORK").exists())

    def test_reserve_moves_the_chat_before_the_limit(self):
        Api.mode = "ok"
        quota(self.home / ".claude" / "quota.json", 50, age=60)  # from an earlier turn
        moved = "main is down to its 5% weekly reserve. Continuing on b."
        _, out = run_in_terminal([str(CLEON), "say hi"], self.env, self.cwd, until=moved)
        self.assertIn(moved, out)
        self.assertNotIn("Continue where you stopped.", self.chat())

        # main is still in its reserve, so a new cleon skips it, though main is first in the order.
        _, out = run_in_terminal([str(CLEON), "--version"], self.env, self.cwd)
        self.assertIn("cleon: main is down to its 5% weekly reserve. Starting on b.", out)

        # A figure saved for another login of main (before a /login) does not count.
        stale = json.loads((self.home / ".claude" / "quota.json").read_text())
        (self.home / ".claude" / "quota.json").write_text(json.dumps(dict(stale, account="x@y")))
        _, out = run_in_terminal([str(CLEON), "--version"], self.env, self.cwd)
        self.assertNotIn("reserve", out)

        # A used-up 5-hour window counts too.
        (self.home / ".claude" / "quota.json").write_text(json.dumps({"five_hour": {
            "used_percentage": 100, "resets_at": int(time.time()) + 3600}}))
        _, out = run_in_terminal([str(CLEON), "--version"], self.env, self.cwd)
        self.assertIn("cleon: main used its 5-hour quota. Starting on b.", out)

        # Every account is at its reserve: cleon waits for the first reset, then starts there.
        quota(self.home / ".claude" / "quota.json", 96, resets_in=2)
        quota(self.home / ".cleon" / "b" / "quota.json", 97)
        code, out = run_in_terminal([str(CLEON), "--version"], self.env, self.cwd)
        self.assertIn("every account is out of room. Waiting until", out)
        self.assertIn("cleon: main has room again.", out)
        self.assertIn("(Claude Code)", out)
        self.assertEqual(code, 0)

        quota(self.home / ".claude" / "quota.json", 96)
        _, out = run_in_terminal([str(CLEON), "ls"], self.env, self.cwd)
        self.assertIn(" 97%", out)
        self.assertIn("every account is out of room", out)


if __name__ == "__main__":
    unittest.main()
