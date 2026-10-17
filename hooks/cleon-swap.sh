#!/bin/bash
# PostToolUse, Stop and StopFailure hook for sessions that `cleon` started (CLEON_SWAP_FILE set); any
# other session: does nothing. Near a quota reserve it asks the agent to pause; then it ends
# claude and tells cleon why, so cleon resumes the chat on the next account:
#   PostToolUse, at a reserve  -> tells the agent to reach a safe point and end its turn
#   Stop, at a reserve         -> "paused" (after that message) or "reserve", and the window
#   StopFailure, usage limit   -> "limit"
#   StopFailure, dead login    -> "login"
# A reserve: 5-hour use at CLEON_MAX_5H%, or weekly use at CLEON_MAX_WEEKLY%.
[ -n "${CLEON_SWAP_FILE:-}" ] || exit 0
case "$(uname -s)" in MINGW* | MSYS* | CYGWIN*) windows=1 ;; *) windows= ;; esac # Git Bash on Windows
# Windows jq ends each line with \r\n: drop the \r, so numbers compare.
[ -n "$windows" ] && jq() { command jq "$@" | tr -d '\r'; return "${PIPESTATUS[0]}"; }
input="$(cat)"
config="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
asked="$CLEON_SWAP_FILE.asked" # the pause levels already sent to this claude

used() { # used <five_hour|seven_day>: this login's percent used in that window, 0 when unknown
	local login="$HOME/.claude.json" acct
	[ -n "${CLAUDE_CONFIG_DIR:-}" ] && login="$CLAUDE_CONFIG_DIR/.claude.json"
	acct="$(jq -r '.oauthAccount.emailAddress // ""' "$login" 2>/dev/null)"
	jq -r --argjson now "$(date +%s)" --arg acct "$acct" --arg w "$1" \
		'if (.account // $acct) == $acct and ((.[$w].resets_at // 0) > $now)
		 then .[$w].used_percentage // 0 | floor else 0 end' "$config/quota.json" 2>/dev/null || echo 0
}
at_reserve() { # the window at its reserve and its use, as "five_hour 96"; nothing when none is
	local u
	u="$(used seven_day)" && [ "$u" -ge "${CLEON_MAX_WEEKLY:-95}" ] && { echo "seven_day $u"; return; }
	u="$(used five_hour)" && [ "$u" -ge "${CLEON_MAX_5H:-95}" ] && echo "five_hour $u"
}

end_claude() { # end_claude <why>: hand cleon the session id and the reason, then end claude
	echo "$(printf '%s' "$input" | jq -r .session_id) $1" >"$CLEON_SWAP_FILE"
	# The hook runs under a shell that claude started; end the nearest claude above it.
	[ -n "$windows" ] && { end_windows_claude; exit 0; }
	local p=$PPID
	while [ "${p:-1}" -gt 1 ]; do
		case "$(/bin/ps -o comm= -p "$p")" in
		claude | */claude | */claude/versions/*) kill -TERM "$p"; exit 0 ;;
		esac
		p="$(/bin/ps -o ppid= -p "$p" | tr -d ' ')"
	done
}

end_windows_claude() { # Git Bash's ps cannot see claude.exe, a Windows process, so ask Windows
	local ps1='$all = @{}; Get-CimInstance Win32_Process | ForEach-Object { $all[[int]$_.ProcessId] = $_ }
		$p = [int]$env:CLEON_WINPID
		for ($i = 0; $i -lt 30 -and $all.ContainsKey($p); $i++) {
			$x = $all[$p]
			if ($x.Name -eq "claude.exe" -or ($x.Name -eq "node.exe" -and $x.CommandLine -match "claude")) { $p; break }
			$p = [int]$x.ParentProcessId
		}' p
	# -EncodedCommand takes the script as base64 UTF-16, so no quote in it is lost on the way.
	p="$(CLEON_WINPID="$(cat "/proc/$$/winpid")" powershell.exe -NoProfile -NonInteractive \
		-EncodedCommand "$(printf '%s' "$ps1" | iconv -t UTF-16LE | base64 -w0)" | tr -d '\r')"
	[ -n "$p" ] && MSYS_NO_PATHCONV=1 taskkill /F /PID "$p" >/dev/null
}

case "$(printf '%s' "$input" | jq -r '.hook_event_name + ":" + (.error // "")')" in
PostToolUse:*)
	read -r win used <<<"$(at_reserve)"
	[ -n "$win" ] || exit 0
	quota=weekly
	[ "$win" = five_hour ] && quota=5-hour
	level="$win reserve" text="This account is at $used% of its $quota quota, its reserve. Reach a safe stopping point: finish the step you are in, start no new long or risky command, then write a short handoff (what is done, what is next, anything half done) and end your turn. The next account resumes from your handoff."
	[ "$used" -ge 98 ] && level="$win 98" text="This account is at $used% of its $quota quota. Stop now: start no new step, write the handoff (what is done, what is next, anything half done) and end your turn."
	grep -qx "$level" "$asked" 2>/dev/null && exit 0
	echo "$level" >>"$asked"
	jq -n --arg text "$text" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $text}}' ;;
Stop:*)
	# The status line writes quota.json when the reply arrives, so after a short reply (or on an
	# account's first chat) it can land just after this hook starts. Wait up to 3 s for a fresh one.
	for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
		jq -e --argjson now "$(date +%s)" '(.updated_at // 0) > $now - 10' "$config/quota.json" >/dev/null 2>&1 && break
		sleep 0.25
	done
	read -r win _ <<<"$(at_reserve)"
	[ -n "$win" ] || exit 0
	if [ -s "$asked" ]; then end_claude "paused $win"; else end_claude "reserve $win"; fi ;;
StopFailure:rate_limit | StopFailure:billing_error | StopFailure:account_on_hold) end_claude limit ;;
StopFailure:authentication_failed | StopFailure:oauth_org_not_allowed) end_claude login ;;
esac
exit 0
