# Records the raw demo run that demo/video frames. demo/record.sh runs it.
# It runs the real cleon and claude in a throwaway HOME against demo/fake_api.py.

Output demo/video/public/run.mp4
Require vhs
Require claude
Require jq

Set Shell bash
Set FontFamily "Menlo"
Set FontSize 30
Set Width 2520
Set Height 1500
Set Padding 48
Set Theme "Catppuccin Mocha"
Set TypingSpeed 45ms
Set WaitTimeout 40s
Set Framerate 25

Hide
Type `PS1='\[\e[1;35m\]~/billing-app\[\e[0m\] $ '; source demo/setup.sh; clear` Enter
Wait /billing-app \$\s*$/
Sleep 500ms
Show

Type "cleon ls" Sleep 400ms Enter
Wait /billing-app \$\s*$/
Sleep 2500ms

Type `cleon "finish the billing refactor"` Sleep 400ms Enter
Wait+Screen@60s /Picking up from the handoff/
Sleep 4s
