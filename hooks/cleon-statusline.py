#!/usr/bin/env python3
"""Claude Code status line for cleon: saves this account's quota, then shows a status line.

cleon reads the saved <config dir>/quota.json to pick an account with room. Claude Code sends the
quota only to the status line (https://code.claude.com/docs/en/statusline), so this is the one
place to catch it. If ~/.cleon/.statusline holds a command (install.sh moves your old
status line there), that command gets the same input and prints the line. Otherwise this prints
"<email> | 5h left N% | 7d left N%". Before the first reply of a session, Claude Code sends no
quota yet, so this shows the last one saved for this login.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

CONFIG = Path(os.environ.get('CLAUDE_CONFIG_DIR') or Path.home() / '.claude')
LOGIN = CONFIG / '.claude.json' if os.environ.get('CLAUDE_CONFIG_DIR') else Path.home() / '.claude.json'
NEXT = Path(os.environ.get('CLEON_HOME') or Path.home() / '.cleon') / '.statusline'


def email():
    try:
        return (json.loads(LOGIN.read_text()).get('oauthAccount') or {}).get('emailAddress') or 'n/a'
    except (OSError, ValueError, AttributeError):
        return 'n/a'


def save_quota(limits):
    if not limits:
        return
    path = CONFIG / 'quota.json'
    tmp = path.with_suffix('.tmp')
    try:
        # The email says whose quota this is: a /login to another account keeps the file.
        tmp.write_text(json.dumps({'updated_at': time.time(), 'account': email(), **limits}))
        os.replace(tmp, path)
    except OSError:
        pass


def saved():
    try:
        data = json.loads((CONFIG / 'quota.json').read_text())
    except (OSError, ValueError):
        return {}
    return data if data.get('account', email()) == email() else {}


def left(label, window):
    window = window or {}
    used = window.get('used_percentage') if window.get('resets_at', time.time() + 1) > time.time() else 0
    return f'{label} left ' + ('n/a' if used is None else f'{max(0, round(100 - used))}%')


def main():
    raw = sys.stdin.read()
    try:
        data = json.loads(raw)
    except ValueError:
        data = {}
    limits = data.get('rate_limits') or {}
    save_quota(limits)
    command = NEXT.read_text().strip() if NEXT.exists() else ''
    if command:
        # Claude Code runs commands with Git Bash on Windows, so the old one may be bash too.
        run = ['bash', '-c', command] if os.name == 'nt' else command
        sys.stdout.write(subprocess.run(run, shell=os.name != 'nt', input=raw, text=True,
                                        capture_output=True).stdout)
        return
    limits = limits or saved()
    print(' | '.join([email(), left('5h', limits.get('five_hour')), left('7d', limits.get('seven_day'))]))


if __name__ == '__main__':
    main()
