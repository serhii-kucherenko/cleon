#!/bin/bash
# PostToolUse, Stop and StopFailure hook for sessions that `cl` started (CL_SWAP_FILE set); any
# other session: does nothing. Near the weekly reserve it asks the agent to pause; then it ends
# claude and tells cl why, so cl resumes the chat on the next account:
#   PostToolUse, week at CL_MAX_WEEKLY% -> tells the agent to reach a safe point and end its turn
#   Stop, week at CL_MAX_WEEKLY%        -> "paused" (after that message) or "reserve"
#   StopFailure with a usage limit      -> "limit"
#   StopFailure with a dead login       -> "login"
[ -n "${CL_SWAP_FILE:-}" ] || exit 0
input="$(cat)"
config="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
max="${CL_MAX_WEEKLY:-95}"
asked="$CL_SWAP_FILE.asked" # the pause levels already sent to this claude

weekly() { # this login's weekly percent used, 0 when unknown
	local login="$HOME/.claude.json" acct
	[ -n "${CLAUDE_CONFIG_DIR:-}" ] && login="$CLAUDE_CONFIG_DIR/.claude.json"
	acct="$(jq -r '.oauthAccount.emailAddress // ""' "$login" 2>/dev/null)"
	jq -r --argjson now "$(date +%s)" --arg acct "$acct" \
		'if (.account // $acct) == $acct and ((.seven_day.resets_at // 0) > $now)
		 then .seven_day.used_percentage // 0 | floor else 0 end' "$config/quota.json" 2>/dev/null || echo 0
}

end_claude() { # end_claude <why>: hand cl the session id and the reason, then end claude
	echo "$(printf '%s' "$input" | jq -r .session_id) $1" >"$CL_SWAP_FILE"
	# The hook runs under a shell that claude started; end the nearest claude above it.
	local p=$PPID
	while [ "${p:-1}" -gt 1 ]; do
		case "$(/bin/ps -o comm= -p "$p")" in
		claude | */claude | */claude/versions/*) kill -TERM "$p"; exit 0 ;;
		esac
		p="$(/bin/ps -o ppid= -p "$p" | tr -d ' ')"
	done
}

case "$(printf '%s' "$input" | jq -r '.hook_event_name + ":" + (.error // "")')" in
PostToolUse:*)
	used="$(weekly)"
	[ "$used" -ge "$max" ] || exit 0
	level=$max text="This account is at $used% of its weekly quota, its reserve. Reach a safe stopping point: finish the step you are in, start no new long or risky command, then write a short handoff (what is done, what is next, anything half done) and end your turn. The next account resumes from your handoff."
	[ "$used" -ge 98 ] && level=98 text="This account is at $used% of its weekly quota. Stop now: start no new step, write the handoff (what is done, what is next, anything half done) and end your turn."
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
	[ "$(weekly)" -ge "$max" ] || exit 0
	if [ -s "$asked" ]; then end_claude paused; else end_claude reserve; fi ;;
StopFailure:rate_limit | StopFailure:billing_error | StopFailure:account_on_hold) end_claude limit ;;
StopFailure:authentication_failed | StopFailure:oauth_org_not_allowed) end_claude login ;;
esac
exit 0
