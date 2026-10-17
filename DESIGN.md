# Design

cleon has two surfaces: the terminal output of `bin/cleon`, and the README demo video that
`demo/video` renders. This file names the tokens both use. A new color, size or timing goes here
first.

## Terminal output (`bin/cleon`)

cleon prints ANSI colors only, so the user's terminal theme decides the real color, in light and
dark themes alike. With `NO_COLOR` set, or when the output is not a terminal, every token is empty.

| Token | ANSI | Means |
|---|---|---|
| `B` | bold | a name: the title, an account |
| `D` | dim | secondary facts: emails, reset times, hints |
| `GRN` | green | room: logged in, the start mark, a bar below its warning point |
| `YEL` | yellow | a bar within 25 points of its limit, a warning line |
| `RED` | red | a bar at its limit, not logged in, every account out |

Marks: `●` where cleon starts, `○` another account, `✓` logged in, `✗` not logged in, `⚠` a
reason the account is skipped. Each quota bar is 20 cells, `━` used and `─` left. Not a block
glyph such as `█`: it fills the whole cell, so the 5h and week bars of an account join into one
shape.

## Demo video (`demo/video/src/theme.js`)

The video frames a real recording, so it takes the recording's theme, Catppuccin Mocha, and its
font. It is dark only, like the recording.

| Token | Value | Use |
|---|---|---|
| `color.crust` | `#11111b` | the canvas around the terminal |
| `color.base` | `#1e1e2e` | the terminal |
| `color.surface1` | `#45475a` | the 2 px border of the terminal |
| `color.text` | `#cdd6f4` | the title and the captions |
| `color.subtext` | `#a6adc8` | the tagline |
| `font.mono` | Menlo | every text in the video, as in the recording |

Type sizes on the 1920 x 1200 canvas: title 140 bold, tagline 44, caption 40.

Motion: a fade or a caption change takes 250 to 400 ms, eased out (cubic). A zoom takes 600 ms in
and 500 ms out, eased in and out (cubic), and stays at 1.4 or less, so the 2520 x 1500 recording
stays sharp.

Rules:

- No fake window chrome (title bars, traffic-light dots). The terminal has a border only.
- A caption says only what the recording shows at that moment.
- The background is flat, so the GIF has no color bands.
