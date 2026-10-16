#!/bin/bash
# install.sh [--uninstall] - set up cleon for this user. Safe to run again, for example after a move.
#
# 1. Links bin/cleon to ~/.local/bin/cleon.
# 2. Registers hooks/cleon-swap.sh (PostToolUse, Stop, StopFailure) in ~/.claude/settings.json.
# 3. Sets hooks/cleon-statusline.py as the status line. A status line you had keeps running: its
#    command moves to ~/.cleon/.statusline, and cleon-statusline.py runs it.
# --uninstall undoes all three. Your accounts in ~/.cleon stay.
set -eu
REPO="$(cd "$(dirname "$0")" && pwd -P)"
SETTINGS="$HOME/.claude/settings.json"
NEXT="${CLEON_HOME:-$HOME/.cleon}/.statusline"
BIN="$HOME/.local/bin"

for tool in claude jq python3; do
	command -v "$tool" >/dev/null || { echo "install.sh: '$tool' is missing. Install it, then run this again." >&2; exit 1; }
done
mkdir -p "$HOME/.claude" "$(dirname "$NEXT")" "$BIN"
[ -s "$SETTINGS" ] || echo '{}' >"$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak"

write() { # write <jq filter> [jq args]: edit settings.json in place, keeping it a link if it is one
	local tmp
	tmp="$(mktemp)"
	jq "$@" "$SETTINGS" >"$tmp" && cat "$tmp" >"$SETTINGS"
	rm -f "$tmp"
}
# Remove cleon's hooks, from any earlier install path.
write '.hooks //= {} | .hooks |= with_entries(.value |= map(select(tostring | contains("cleon-swap.sh") | not)))
	| .hooks |= with_entries(select(.value | length > 0))'
# Ours, from this or an earlier clone. Never chain it: cleon-statusline.py would run itself.
ours="$(jq -r '.statusLine.command // ""' "$SETTINGS" | grep -c 'hooks/cleon-statusline\.py' || true)"

if [ "${1:-}" = --uninstall ]; then
	if [ -s "$NEXT" ]; then
		write '.statusLine = {type: "command", command: $c}' --arg c "$(cat "$NEXT")"
		rm -f "$NEXT"
	elif [ "$ours" -gt 0 ]; then
		write 'del(.statusLine)'
	fi
	[ "$(readlink "$BIN/cleon" 2>/dev/null)" = "$REPO/bin/cleon" ] && rm -f "$BIN/cleon"
	echo "cleon is uninstalled. Your accounts are still in ~/.cleon."
	exit
fi

old="$(jq -r '.statusLine.command // ""' "$SETTINGS")"
if [ -n "$old" ] && [ "$ours" -eq 0 ]; then
	echo "$old" >"$NEXT"
	echo "Your status line still shows. cleon-statusline.py runs it: $old"
fi
hook="bash \"$REPO/hooks/cleon-swap.sh\""
write --arg h "$hook" --arg s "python3 \"$REPO/hooks/cleon-statusline.py\"" '
	{type: "command", command: $h, timeout: 10} as $cmd
	| .hooks.PostToolUse += [{matcher: "*", hooks: [$cmd]}]
	| .hooks.Stop += [{hooks: [$cmd]}]
	| .hooks.StopFailure += [{hooks: [$cmd]}]
	| .statusLine = {type: "command", command: $s}'
ln -sf "$REPO/bin/cleon" "$BIN/cleon"

echo "cleon is installed: $BIN/cleon -> $REPO/bin/cleon"
echo "Old settings saved to $SETTINGS.bak"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "Add $BIN to your PATH: echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >>~/.zshrc" ;; esac
echo "Next: cleon ls"
