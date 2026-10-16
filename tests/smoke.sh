#!/bin/bash
# tests/smoke.sh - the parts of cleon that differ per system, with no real claude and no login.
# Runs the same on macOS, Linux, WSL and Windows (Git Bash). Needs bash, jq and node.
#   1. kill   the swap hook ends the claude above it (a copy of node, named claude)
#   2. share  a file in ~/.claude shows in another account
#   3. quota  cleon ls reads an account's quota (Windows jq writes \r\n)
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fails=0
check() { if eval "$2"; then echo "ok    $1"; else echo "FAIL  $1"; fails=$((fails + 1)); fi; }
case "$(uname -s)" in MINGW* | MSYS* | CYGWIN*) exe=.exe ;; *) exe= ;; esac

# 1. kill
mkdir -p "$T/bin"
# A copy on Windows. A link elsewhere: Homebrew's node needs the library beside it.
if [ -n "$exe" ]; then cp "$(command -v node)" "$T/bin/claude.exe"; else ln -s "$(command -v node)" "$T/bin/claude"; fi
export CLEON_SWAP_FILE="$T/swap"
hook="$REPO/hooks/cleon-swap.sh"
[ -n "$exe" ] && hook="$(cygpath -m "$hook")" CLEON_SWAP_FILE="$(cygpath -m "$T/swap")"
start=$SECONDS
"$T/bin/claude$exe" -e '
	require("child_process").execFileSync("bash", [process.argv[1]], {input: JSON.stringify(
		{session_id: "sid", hook_event_name: "StopFailure", error: "rate_limit"})});
	setTimeout(() => {}, 30000);' "$hook"
rc=$?
check "kill: the hook ends claude" '[ "$rc" -ne 0 ] && [ $((SECONDS - start)) -lt 20 ]'
check "kill: the hook tells cleon why" '[ "$(cat "$T/swap" 2>/dev/null)" = "sid limit" ]'
unset CLEON_SWAP_FILE

# 2. share and 3. quota, on a fake claude that answers only what cleon ls asks
export HOME="$T/home" CLEON_HOME="$T/home/.cleon" PATH="$T/fake:$PATH"
mkdir -p "$HOME/.claude/skills" "$CLEON_HOME/b" "$T/fake"
printf '#!/bin/bash\necho "{\\"loggedIn\\": true}"\n' >"$T/fake/claude"
chmod +x "$T/fake/claude"
echo '{"oauthAccount": {"emailAddress": "a@example.com"}}' >"$HOME/.claude.json"
echo '{"oauthAccount": {"emailAddress": "b@example.com"}}' >"$CLEON_HOME/b/.claude.json"
echo '{}' >"$HOME/.claude/settings.json"
echo "{\"account\": \"b@example.com\", \"updated_at\": $(date +%s), \"seven_day\": {\"used_percentage\": 50, \"resets_at\": $(($(date +%s) + 3600))}}" >"$CLEON_HOME/b/quota.json"
out="$(NO_COLOR=1 "$REPO/bin/cleon" ls 2>&1)"
echo 'shared' >"$HOME/.claude/skills/note"
echo '{"shared": true}' >"$HOME/.claude/settings.json"
check "share: a folder" '[ "$(cat "$CLEON_HOME/b/skills/note" 2>/dev/null)" = shared ]'
check "share: a file" 'grep -q shared "$CLEON_HOME/b/settings.json" 2>/dev/null'
check "quota: cleon ls reads 50%" 'grep -q "week .* 50%" <<<"$out"'
check "quota: no shell errors" '! grep -qiE "integer|syntax|command not found" <<<"$out"'
[ "$fails" -eq 0 ] || { printf '\n%s\n' "$out"; exit 1; }
