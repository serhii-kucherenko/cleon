#!/bin/bash
# source demo/setup.sh - a throwaway HOME with two example accounts and a fake API, for the demo.
# No real login, email or chat goes in: the accounts are work@example.com and personal@example.com.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DEMO="${TMPDIR:-/tmp}/cleon-demo"
PORT=8765
lsof -ti "tcp:$PORT" | xargs kill 2>/dev/null # an API left from an earlier run
rm -rf "$DEMO" && mkdir -p "$DEMO/.claude" "$DEMO/.cleon/personal" "$DEMO/billing-app"
DEMO="$(cd "$DEMO" && pwd -P)" # claude trusts the real path

for env in $(env | grep -o '^CLAUDE[A-Z_]*'); do unset "$env"; done
export HOME="$DEMO" PATH="$DEMO/.local/bin:$PATH" TERM=xterm-256color
export ANTHROPIC_BASE_URL="http://127.0.0.1:$PORT" ANTHROPIC_AUTH_TOKEN=demo
export CLAUDE_CODE_MAX_RETRIES=0 DISABLE_TELEMETRY=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

account() { # account <file> <email>
	jq -n --arg email "$2" --arg dir "$DEMO/billing-app" --arg v "$(claude --version | cut -d' ' -f1)" '{
		hasCompletedOnboarding: true, hasSeenAutoDefaultNotice: true, theme: "dark", lastOnboardingVersion: $v,
		lastReleaseNotesSeen: $v, oauthAccount: {emailAddress: $email},
		projects: {($dir): {hasTrustDialogAccepted: true}}}' >"$1"
}
account "$DEMO/.claude.json" work@example.com
account "$DEMO/.cleon/personal/.claude.json" personal@example.com
echo '{"skipDangerousModePermissionPrompt": true}' >"$DEMO/.claude/settings.json"
"$REPO/install.sh" >/dev/null
cleon name work >/dev/null
cleon order work personal >/dev/null

python3 "$REPO/demo/fake_api.py" "$DEMO" "$PORT" >/dev/null 2>&1 &
disown
cd "$DEMO/billing-app" || return
sleep 1
