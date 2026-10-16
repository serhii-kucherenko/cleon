# Makes demo/cleon.gif. Run from the repo root: vhs demo/cleon.tape
# It runs the real cleon and claude in a throwaway HOME against demo/fake_api.py.

Output demo/cleon.gif
Require vhs
Require claude
Require jq

Set Shell bash
Set FontFamily "Menlo"
Set FontSize 15
Set Width 1240
Set Height 760
Set Padding 24
Set Theme "Catppuccin Mocha"
Set TypingSpeed 45ms
Set WindowBar Colorful
Set WaitTimeout 40s
Set Framerate 20

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
