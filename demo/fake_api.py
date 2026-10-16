"""The API for the demo: python3 demo/fake_api.py <home> <port>

Plays one story. On account "work" the agent runs the tests. That pushes work to 96% of its week,
so the agent writes a handoff and cleon moves the chat to "personal", which carries on.
"""
from http.server import ThreadingHTTPServer
import json
import os
from pathlib import Path
import sys
import threading
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tests"))
from test_cleon import SSE, Api  # noqa: E402

HOME = Path(sys.argv[1])
TESTS = "echo '✓ 128 tests passed'"
REPLIES = [
    None,  # the first chat request runs the tests
    "All 128 tests pass. This account is at its weekly reserve, so here is the handoff.\n\n"
    "**Done:** the billing refactor, `invoice.py` split in three.\n"
    "**Next:** update `docs/billing.md` to the new names.",
    "Picking up from the handoff. The refactor is done, so I update `docs/billing.md` next.",
]


def quota(path, week, five):
    now = int(time.time())
    path.write_text(json.dumps({"updated_at": time.time(), "seven_day": {
        "used_percentage": week, "resets_at": now + 3 * 86400 + 4 * 3600}, "five_hour": {
        "used_percentage": five, "resets_at": now + 2 * 3600 + 600}}))


START = ("message_start", {**SSE[0][1], "message": {**SSE[0][1]["message"], "model": "claude-opus-5-5"}})
# 5-hour and weekly use per turn: work before and after the tests, then personal.
USE = [(0.58, 0.96), (0.58, 0.96), (0.12, 0.20)]


def text_events(text):
    return [START, SSE[1], ("content_block_delta", {"type": "content_block_delta", "index": 0,
            "delta": {"type": "text_delta", "text": text}}), *SSE[3:]]


def tool_events():
    return [START,
            ("content_block_start", {"type": "content_block_start", "index": 0, "content_block": {
                "type": "tool_use", "id": "toolu_demo", "name": "Bash", "input": {}}}),
            ("content_block_delta", {"type": "content_block_delta", "index": 0, "delta": {
                "type": "input_json_delta",
                "partial_json": json.dumps({"command": TESTS, "description": "Run the tests"})}}),
            ("content_block_stop", {"type": "content_block_stop", "index": 0}),
            ("message_delta", {"type": "message_delta", "usage": {"output_tokens": 1},
                               "delta": {"stop_reason": "tool_use", "stop_sequence": None}}),
            ("message_stop", {"type": "message_stop"})]


class Demo(Api):
    turn = 0

    def do_POST(self):
        req = json.loads(self.rfile.read(int(self.headers.get("content-length", 0))) or b"{}")
        if not (req.get("stream") and req.get("tools")):  # titles and other side requests
            return self.reply(200, "text/event-stream", self.stream(text_events("Billing refactor")),
                              self.limits(Demo.turn))
        turn, Demo.turn = Demo.turn, min(Demo.turn + 1, len(REPLIES) - 1)
        if turn == 0:
            quota(HOME / ".claude" / "quota.json", 96, 58)
        time.sleep(1.5)  # a model takes a moment to answer
        events = tool_events() if REPLIES[turn] is None else text_events(REPLIES[turn])
        self.reply(200, "text/event-stream", self.stream(events), self.limits(turn))

    @staticmethod
    def limits(turn):
        # The headers Claude Code reads its quota from; the status line shows them.
        five, week = USE[turn]
        now = int(time.time())
        return {"anthropic-ratelimit-unified-status": "allowed",
                "anthropic-ratelimit-unified-5h-utilization": str(five),
                "anthropic-ratelimit-unified-5h-reset": str(now + 2 * 3600 + 600),
                "anthropic-ratelimit-unified-7d-utilization": str(week),
                "anthropic-ratelimit-unified-7d-reset": str(now + 3 * 86400 + 4 * 3600)}

    @staticmethod
    def stream(events):
        return "".join(f"event: {e}\ndata: {json.dumps(d)}\n\n" for e, d in events)


if __name__ == "__main__":
    quota(HOME / ".claude" / "quota.json", 50, 41)
    quota(HOME / ".cleon" / "personal" / "quota.json", 20, 12)
    threading.Timer(120, os._exit, [0]).start()  # outlive no recording
    ThreadingHTTPServer(("127.0.0.1", int(sys.argv[2])), Demo).serve_forever()
