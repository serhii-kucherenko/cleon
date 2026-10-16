<p align="center">
  <h1 align="center">👑 cleon</h1>
  <p align="center"><strong>Run Claude Code on all your Claude accounts. When one runs out, the next one carries on the same chat.</strong></p>
  <p align="center">
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
    <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey.svg" alt="Platform: macOS | Linux | Windows">
    <img src="https://img.shields.io/badge/shell-bash-4EAA25.svg" alt="Shell: bash">
    <a href="https://code.claude.com"><img src="https://img.shields.io/badge/for-Claude%20Code-D97757.svg" alt="For Claude Code"></a>
  </p>
</p>

---

<p align="center">
  <img src="demo/cleon.gif" alt="cleon demo: the work account reaches its weekly reserve, writes a handoff, and the personal account carries on the same chat" width="760">
</p>

## 😤 The problem

You are deep in a Claude Code session. Then the account hits its limit:

- The agent stops in the middle of a step.
- You log out, log in to your other account, and find the chat again.
- Your settings, hooks and skills are set up for one account only.
- You explain the task again, and the new chat makes the same mistakes again.

**You have the quota. You just cannot use it without breaking your flow.**

## ✨ The solution

`cleon` runs Claude Code on a list of accounts. Before an account runs out, it asks the agent to
stop at a safe point and write a handoff. Then it opens the **same chat** on the next account,
and the agent carries on from the handoff.

```text
 account "work"                               account "personal"
┌──────────────────────────────┐             ┌──────────────────────────────┐
│ you: finish the refactor     │             │ cleon: resume the paused work│
│ agent: runs the tests ...    │             │ agent: picking up from the   │
│ week at 95% ─▶ pause note    │──same chat─▶│        handoff ...           │
│ agent: writes the handoff    │             │ you keep working             │
└──────────────────────────────┘             └──────────────────────────────┘
```

The name comes from the Cleon emperors in *Foundation*. They are a line of clones. When one is
spent, the next one takes the throne, and the empire carries on.

## 🎯 What you get

- **🔄 One chat, many accounts.** The chat moves to the next account with its full history.
- **🛑 A safe stop.** At 95% of the weekly quota (you can change it), the agent finishes its step and writes a handoff. It does not break off in the middle of a change.
- **⚡ A hard limit is not the end.** On a usage limit or a dead login, `cleon` moves the chat at once and says "Continue where you stopped".
- **🧭 Smart start.** `cleon` starts on the first account in your order that has quota left.
- **📊 One view of all quota.** `cleon ls` shows each account's 5-hour and weekly use, with reset times.
- **⏳ Waits for you.** When every account is out, `cleon` waits for the first reset and carries on there.
- **🧩 One setup.** All accounts share your settings, hooks, skills, plugins and chat history. Each keeps its own login.
- **🖥️ Every system.** macOS, Linux, WSL and Windows (Git Bash). `cleon` finds the system by itself.
- **🔒 Local only.** Plain bash and a small Python status line. No server, no API keys, nothing leaves your machine.

## 🏗️ Claude Code alone vs Claude Code + cleon

| Situation | Claude Code alone | Claude Code + cleon |
|---|---|---|
| **The weekly quota runs low** | 🔴 You find out when it is gone, often in the middle of a change. | 🟢 At 95% (by default), the agent gets a note to reach a safe point and write a handoff. |
| **The quota runs out** | 🔴 The turn stops. You `/logout`, `/login`, and find the chat again. | 🟢 `cleon` resumes the same chat on the next account, by itself. |
| **Settings and skills** | 🔴 A second config folder means a second copy of everything. | 🟢 Every account links to one `~/.claude`. Change it once. |
| **Resume an old chat** | 🔴 A chat lives under the account that started it. | 🟢 Any account can `--resume` any chat. |
| **Which account to use** | 🟡 You guess, or check each one on claude.ai. | 🟢 `cleon` picks the first account with room. `cleon ls` shows all of them. |
| **Every account is out** | 🔴 You come back later and check by hand. | 🟢 `cleon` waits in the terminal until the first reset, then carries on. |

## 🚀 Quick start

```bash
git clone https://github.com/serhii-kucherenko/cleon.git ~/cleon
~/cleon/install.sh
cleon add personal          # log in to your second account
```

Then use `cleon` where you used `claude`. All `claude` flags work.

## 📖 Set up, step by step

**1. Get the code.** Keep the clone: the install links to it, so `git pull` updates `cleon`.

```bash
git clone https://github.com/serhii-kucherenko/cleon.git ~/cleon
```

**2. Install.**

```bash
~/cleon/install.sh
```

```text
cleon is installed: /Users/you/.local/bin/cleon -> /Users/you/cleon/bin/cleon
Old settings saved to /Users/you/.claude/settings.json.bak
Next: cleon ls
```

If you had a status line, it still shows, and the installer says so. If `~/.local/bin` is not on
your `PATH`, the installer gives you the line to add.

**3. Name your current account (optional).** Your normal `~/.claude` login is the first account,
called `main`. Give it a clearer name:

```bash
cleon name work
```

**4. Add your other accounts.** Each one opens the Claude login page. Log in with that account.

```bash
cleon add personal
cleon add spare
```

`cleon` refuses an account whose login is already in the list. Names use lowercase letters, digits
and `-`.

**5. Set the order.** `cleon` uses the first account with quota left.

```bash
cleon order work personal spare
```

**6. Check.**

```bash
cleon ls
```

The quota bars show after the first chat on each account. To see them at once, run one short chat
on each: `cleon @personal "say hi"`.

**7. Use it.**

```bash
cleon                                   # a new chat on the first account with room
cleon "fix the failing test"            # a new chat with a prompt
cleon --resume                          # pick an old chat to resume
cleon @personal                         # use this account, whatever its quota
cleon --dangerously-skip-permissions    # flags pass through, and stay after a switch
```

## 📸 What it looks like

### `cleon ls`

```text
 cleon accounts   order = priority · cleon starts on the first with room · auto-resume on · reserve 5%

 ● work        work@example.com   ← cleon starts here
     ✓ logged in   max plan · worked 3m ago
     5h    ████████░░░░░░░░░░░░  41%   resets in 2h 9m
     week  ██████████░░░░░░░░░░  50%   resets in 3d 3h

 ○ personal    personal@example.com
     ✓ logged in   pro plan · worked 2h 5m ago
     5h    ██░░░░░░░░░░░░░░░░░░  12%   resets in 2h 9m
     week  ████░░░░░░░░░░░░░░░░  20%   resets in 3d 3h
```

The bar turns yellow 25 points before the limit and red at it.

### A switch

```text
$ cleon "finish the billing refactor"
  ...the agent runs the tests on "work", which reaches 96% of its week...
  ● All 128 tests pass. This account is at its weekly reserve, so here is the handoff.
    Done: the billing refactor, invoice.py split in three.
    Next: update docs/billing.md to the new names.

cleon: work paused its work at its 5% weekly reserve. Continuing on personal.

  ...the same chat opens on "personal"...
  > Resume the paused work: the last account reached its weekly reserve. Carry on from your handoff.
  ● Picking up from the handoff. The refactor is done, so I update docs/billing.md next.
```

## 🔧 How it works

```mermaid
flowchart LR
    cleon["cleon"] -->|"CLAUDE_CONFIG_DIR = account"| claude["claude"]
    claude -->|"status line input"| sl["cleon-statusline.py<br/>saves quota.json"]
    claude -->|"PostToolUse / Stop / StopFailure"| hook["cleon-swap.sh"]
    sl -.->|"quota.json"| hook
    sl -.->|"quota.json"| cleon
    hook -->|"near the limit: end claude,<br/>write session id + reason"| cleon
    cleon -->|"claude --resume &lt;id&gt; on the next account"| claude
```

| Part | What it does |
|---|---|
| `bin/cleon` | Picks an account, starts `claude` on it, and resumes the chat on the next account when told. |
| `hooks/cleon-statusline.py` | Saves each account's quota to `<config dir>/quota.json`. Claude Code sends the quota only to the status line, so this is where `cleon` catches it. |
| `hooks/cleon-swap.sh` | At the reserve, asks the agent to pause. At the end of that turn, or on a hard limit, it ends `claude` and tells `cleon` why. In a session that `cleon` did not start, it does nothing. |
| `install.sh` | Links `cleon` and registers the hook and the status line in `~/.claude/settings.json`. |

Your normal `~/.claude` login is the first account. Each other account is a folder
`~/.cleon/<name>`, used as `CLAUDE_CONFIG_DIR`. It has its own login and its own
`.claude.json`. The shared parts are symlinks to `~/.claude`. To keep the accounts in another
folder, set `CLEON_HOME`, for example `export CLEON_HOME=~/my-accounts` in your `~/.zshrc`.

## 🛠️ Commands

| Command | What it does |
|---|---|
| `cleon [@name] [claude args]` | Start `claude` on the first account with room, or on `name`. |
| `cleon add <name>` | Add an account and log in to it. Run it again to log in again. |
| `cleon ls` | List the accounts, their logins, and their 5-hour and weekly quota. |
| `cleon order <name...>` | Set the order `cleon` uses the accounts in. |
| `cleon name <name>` | Name the `~/.claude` account (default `main`). |
| `cleon resume [on\|off]` | After a switch, the next account carries on by itself (`on`, the default), or opens the chat and waits for you (`off`). |
| `cleon reserve [percent]` | Show or set the weekly quota each account keeps back (default 5). |
| `cleon help` | Show the commands. |

## ⏱️ What happens at a limit

| Event | What `cleon` does | You see |
|---|---|---|
| Weekly use reaches the reserve during a turn | The agent gets a note to finish its step and write a handoff. At the end of the turn, the next account resumes the chat with "Resume the paused work". | `cleon: work paused its work at its 5% weekly reserve. Continuing on personal.` |
| Weekly use reaches the reserve at the end of a turn | The next account opens the chat and waits for your next prompt. | `cleon: work is down to its 5% weekly reserve. Continuing on personal.` |
| A hard usage limit (5-hour or weekly) | The next account resumes the chat with "Continue where you stopped". | `cleon: work hit its limit. Continuing on personal.` |
| The login stopped working | The same as a limit. | `cleon: personal has a login that no longer works (cleon add personal). ...` |
| Every account is out | `cleon` waits in the terminal until the first reset. Ctrl+C stops the wait. | `cleon: every account is out of room. Waiting until 14:05 (in 1h 12m).` |

### Change the reserve

The 5% weekly reserve keeps each account usable for small jobs.

```bash
cleon reserve 15
```

```text
weekly reserve: 15% (cleon skips an account at 85% weekly use)
```

The value is saved in `~/.cleon/.reserve`. A `cleon` that runs now keeps its old value.
The next `cleon` you start uses the new one. `cleon reserve 0` turns the reserve off, so `cleon`
switches only at a hard limit.

## 🤔 Why not just...

| Alternative | Limitation |
|---|---|
| **`/logout` and `/login` by hand** | The turn stops first. Then you find the chat again and explain where you were. |
| **Two terminals with `CLAUDE_CONFIG_DIR`** | Two copies of your settings, hooks and skills. A chat from one account cannot be resumed on the other. |
| **`claude setup-token`** | The token is for inference only. claude.ai connectors and Claude in Chrome do not load with it. |
| **Pay for the API instead** | You pay for each token, on top of the plans you already have. |

## 📦 What `install.sh` does

```text
✓ Links bin/cleon to ~/.local/bin/cleon
✓ Registers hooks/cleon-swap.sh for PostToolUse, Stop and StopFailure in ~/.claude/settings.json
✓ Sets hooks/cleon-statusline.py as the status line
✓ Keeps your old status line: its command moves to ~/.cleon/.statusline, and cleon's status line runs it
✓ Saves your old settings to ~/.claude/settings.json.bak
```

It is safe to run again, for example after you move the clone.

## 🧩 Share more files between accounts

`cleon` shares a fixed, safe list: settings, `CLAUDE.md`, hooks, commands, agents, skills,
plugins, output styles, mods, chat history, todos, plans and tasks. It never shares a login, a
quota or a cache. To share more, put the names in `~/.cleon/.shared`, one per line:

```bash
echo "my-notes.md" >> ~/.cleon/.shared
```

`cleon` links them the next time it starts each account.

## 🪐 Use with [Superset](https://superset.sh)

Set the Claude agent command to `cleon` (Settings, Agents, Claude, Agent command). Then every
Claude tab, resume and fork goes through `cleon`. Leave the account in Superset's Usage tab unset.
Superset sets `CLAUDE_CONFIG_DIR` from it, and that replaces the account `cleon` picks.

## 📋 Requirements

- [Claude Code](https://code.claude.com), logged in once in the normal way. Tested on 2.1.301.
- `bash`, `jq` and Python 3.
- Two or more Claude accounts on a Pro or Max plan. Claude Code reports quota only for these plans.

| System | Install the tools | Notes |
|---|---|---|
| **macOS** | `brew install jq` | Python 3 comes with the Xcode tools. |
| **Linux** | `sudo apt install jq python3` | |
| **WSL** | `sudo apt install jq python3` | Install Claude Code inside WSL too. Then it is the same as Linux. |
| **Windows** | [Git for Windows](https://git-scm.com/download/win), then `winget install jqlang.jq` and `winget install Python.Python.3.12` | Run `cleon` in Git Bash. Turn on Developer Mode (Settings, System, For developers), so `cleon` can make real links. |

`cleon` finds the system by itself, with `uname -s`. In Git Bash on Windows it ends `claude.exe`
through Windows, passes `C:/...` paths to it, and links folders with junctions when it cannot
make symlinks. On macOS, Linux and WSL it runs the plain Unix path.

Windows support is new. To check your machine, run `bash tests/smoke.sh` in Git Bash. It needs
`node`, and it does not need a login.

## 🩺 Troubleshooting

| Problem | Fix |
|---|---|
| `cleon: command not found` | Add `~/.local/bin` to your `PATH`, then open a new terminal. |
| `cleon ls` says "no quota seen yet" | Run one chat on that account: `cleon @<name> "say hi"`. |
| `cleon ls` says "not logged in" | It shows the command to log in again: `cleon add <name>`, or `claude auth login` for the `~/.claude` account. |
| `cleon` does not switch at a limit | Check that the hook is registered: `grep cleon-swap ~/.claude/settings.json`. If not, run `install.sh` again. |
| Windows: `cleon: ... is a hard link` | A hard link stops being shared when a program saves the file anew. Turn on Developer Mode, delete that file in the account folder, and start `cleon` again. It makes a real link. |
| A resumed chat lost a flag | `cleon` keeps `--dangerously-skip-permissions`, `--model`, `--permission-mode`, `--agent`, `--add-dir`, `--settings` and any `--flag=value`. Add others to the `keep` list in `bin/cleon`. |

## 🧑‍💻 Development

```bash
python3 tests/test_cleon.py     # end-to-end tests (macOS and Linux)
bash tests/smoke.sh             # the parts that differ per system (also Windows Git Bash)
vhs demo/cleon.tape             # makes demo/cleon.gif again
```

The tests run the real `claude` through `cleon` in a terminal, in a throwaway `HOME`, against a
fake API on your machine. They cover a hard limit, the reserve, the pause and the handoff, the
wait when every account is out, `cleon reserve`, and `install.sh`. They need `claude`, `jq`, and
one real login in `~/.claude.json` (only its settings are copied).

The demo also runs the real `cleon` and `claude`, against `demo/fake_api.py`. It uses a throwaway
`HOME` with two example accounts, so no real login or chat shows. It needs
[vhs](https://github.com/charmbracelet/vhs).

## 🗑️ Uninstall

```bash
~/cleon/install.sh --uninstall
```

This removes the link, the hook and the status line, and puts back your old status line. Your
accounts stay in `~/.cleon`. Delete that folder to remove them too.

## 📄 License

[MIT](LICENSE)

---

<p align="center">
  <strong>Built for people who have more quota than patience.</strong><br>
  <a href="https://github.com/serhii-kucherenko/cleon/issues">Issues</a> · <a href="#-quick-start">Quick start</a> · <a href="#-how-it-works">How it works</a>
</p>
