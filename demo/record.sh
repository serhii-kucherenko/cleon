#!/bin/bash
# demo/record.sh - makes demo/cleon.mp4 and demo/cleon.gif, the README demo.
#   1. VHS records the real cleon and claude (demo/cleon.tape) against demo/fake_api.py, in a
#      throwaway HOME with example accounts (demo/setup.sh). No login, email or chat of yours.
#   2. The times in that run's event log become demo/video/src/timeline.json.
#   3. Remotion (demo/video) frames the recording with a title, zooms and captions.
# Needs vhs, claude, jq, python3, ffmpeg and node.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$REPO"
vhs demo/cleon.tape
python3 - "${TMPDIR:-/tmp}/cleon-demo/events.log" demo/video/public/run.mp4 >demo/video/src/timeline.json <<'PY'
import json, subprocess, sys

log, video = sys.argv[1:]
wall = {}
for line in open(log):
    t, what = line.rstrip("\n").split(" ", 1)
    if what == "cleon ls":
        wall["ls"] = float(t)
    elif what.startswith('cleon "'):
        wall["run"] = float(t)
    elif what == "exit" and "run" in wall and "switch" not in wall:
        wall["exit"] = float(t)  # the first account's claude ends, after the handoff
    elif what == "claude --resume":
        wall["switch"] = float(t) - 2  # bin/cleon waits 2 s after its switch message
    elif what in ("tests", "handoff", "pickup"):
        wall[what] = float(t)
# VHS takes frames more slowly than it plays them back, and unevenly, so a wall time is not a video
# time. Three moments are known in both: the start (0.76 s before the Enter on `cleon ls`: 8
# characters typed at 45 ms, then 400 ms), the first claude's last frame (after it, its orange logo,
# top left, is gone), and the end (the last reply shows, then the tape waits 4 s).
# Times map linearly between them.
probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                        "stream=r_frame_rate:format=duration", "-of", "json", video],
                       capture_output=True, text=True).stdout
info = json.loads(probe)
num, den = info["streams"][0]["r_frame_rate"].split("/")
fps, duration = int(num) / int(den), float(info["format"]["duration"])
w, h = 60, 38  # every 4th pixel of the top-left corner, 240 x 150
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", video, "-vf", f"crop=240:150:30:60,scale={w}:{h}:flags=neighbor",
                      "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
size = w * h * 3
logo = [any(r > 170 and 80 < g < 160 and b < 130 for r, g, b in zip(f[0::3], f[1::3], f[2::3]))
        for f in (raw[i:i + size] for i in range(0, len(raw), size))]
exit_video = (logo.index(False, logo.index(True)) - 0.5) / fps  # the middle of that last frame
anchors = [(wall["ls"] - (8 * 0.045 + 0.4), 0), (wall["exit"], exit_video), (wall["pickup"] + 4.2, duration)]


def video_time(t):
    for (w0, v0), (w1, v1) in zip(anchors, anchors[1:]):
        if t <= w1 or (w1, v1) == anchors[-1]:
            return v0 + (t - w0) * (v1 - v0) / (w1 - w0)


events = {k: round(video_time(v), 3) for k, v in wall.items()}
order = [events[k] for k in ("ls", "run", "tests", "handoff", "exit", "switch", "pickup")]
assert 0 < order[0] and order == sorted(order) and order[-1] < duration, f"events out of order: {events}"
json.dump({"duration": duration, "events": events}, sys.stdout, indent=2)
PY
cd demo/video
npm ci --no-fund --no-audit
npm run render
