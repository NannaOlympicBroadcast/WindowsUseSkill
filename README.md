# windows-use

A Claude skill for driving Windows GUI applications from a shell — switch window focus by process name, send keystrokes (modifier combos, function keys, literal text), and capture the foreground window. Think of it as "computer use lite": no screen reading, no mouse, just keyboard automation, which turns out to be enough for a surprising number of real workflows.

Built around two tiny upstream binaries — [`wmctrl-for-windows`](https://github.com/ebranlard/wmctrl-for-windows) and [`xdotool-for-windows`](https://github.com/ebranlard/xdotool-for-windows) — wrapped in PowerShell helpers and a `.NET`-based screenshot tool that fills in the one capability the upstream tools lack.

## What this is for

Any task that boils down to *focus a window → press some keys* on Windows. For example:

- Switch to Chrome and reload the active tab
- Bring VSCode/Cursor to the front and trigger Save All
- Focus MATLAB, clear the prompt, paste clipboard, run it
- Open WeChat, search a contact's name, hit Enter, screenshot the result
- Stop or restart a long-running demo window from a script
- Any keyboard-shortcut workflow you'd normally script with AutoHotkey but want callable from a Claude session

## What this is *not* for

These tools cannot:
- Move or click the mouse
- Press the Windows key (`{LWIN}` / Win+Shift+S won't work — system-level)
- Read text from the screen, do OCR, or interpret UI structure
- Focus a window by title (only by process name)
- Distinguish multiple instances of the same process — picks the first match

For mouse control or screen reading, use [AutoHotkey](https://www.autohotkey.com/), [PyAutoGUI](https://github.com/asweigart/pyautogui), or a real screen-using agent.

## Installation

```bash
git clone https://github.com/<YOUR_GITHUB_USER>/windows-use.git
cd windows-use
```

Then install the binaries (one-time setup):

```powershell
.\scripts\install-binaries.ps1
```

This fetches `wmctrl.exe` and `xdotool.exe` directly from the upstream maintainer's repos and verifies each against a known SHA256. After that the skill is fully offline.

To use this with Claude:

| Client                      | Where to put the skill folder                                                       |
|-----------------------------|-------------------------------------------------------------------------------------|
| Claude Code                 | Drop the `windows-use/` folder into `~/.claude/skills/` or your project's `.claude/skills/` |
| Claude Desktop              | Use the skill management UI (Settings → Capabilities → Skills) to install the folder       |

Claude will read `SKILL.md` automatically when a relevant task comes up — see the YAML frontmatter at the top of `SKILL.md` for the full triggering description.

## Quick examples

### Smoke test (run any time to verify everything works)

```powershell
Start-Process notepad
Start-Sleep -Seconds 1
.\scripts\focus-and-send.ps1 -Process notepad -Keys "Hello{ENTER}World{ENTER}{F5}"
```

You should see "Hello / World / <current timestamp>" in Notepad — F5 inserts the current date/time. If anything is off, you know it's the keystroke layer rather than your target app.

### Open a new tab in Chrome

```powershell
.\scripts\focus-and-send.ps1 -Process chrome -Keys "^t"
```

### Paste clipboard into MATLAB and run it

```powershell
.\scripts\focus-and-send.ps1 -Process MATLAB -Keys "{ESC}^v{ENTER}" -DelayMs 300
```

### Search WeChat for a chat and screenshot the result

```powershell
.\scripts\wechat-search-and-snap.ps1 -ChatName "项目101"
# → focuses WeChat, Ctrl+F, types name, Enter, screenshots window
# → saves to Pictures\Screenshots\wechat_<name>_<timestamp>.png
```

For more recipes (VSCode chord shortcuts, Chrome URL navigation, MATLAB multi-line paste-and-run, etc.) see [`references/recipes.md`](references/recipes.md).

## How it works

```
┌─────────────────────────┐
│ Your script / Claude    │
└────────────┬────────────┘
             │
             ▼
   ┌──────────────────┐         ┌────────────────────────┐
   │  wmctrl.exe -a   │ ──────▶ │  user32!SwitchTo-      │
   │  <process_name>  │         │  ThisWindow(hWnd)      │
   └──────────────────┘         └────────────────────────┘
             │
             ▼ (200 ms — focus settles)
   ┌──────────────────┐         ┌────────────────────────┐
   │  xdotool.exe     │ ──────▶ │  System.Windows.Forms. │
   │  key "<KEYS>"    │         │  SendKeys.SendWait()   │
   └──────────────────┘         └────────────────────────┘
```

The keystroke syntax is `.NET SendKeys` — `^` for Ctrl, `%` for Alt, `+` for Shift, `{F4}` `{UP}` etc. for special keys. Full table in [`references/sendkeys-syntax.md`](references/sendkeys-syntax.md).

For screenshots, since SendKeys can't trigger PrintScreen (Windows hooks it system-side before .NET sees it), `screenshot-active-window.ps1` uses `user32!GetForegroundWindow` + `GetWindowRect` + `System.Drawing.Graphics.CopyFromScreen` to capture whatever's in front.

## Repository layout

```
windows-use/
├── SKILL.md                          # the skill's instructions for Claude
├── README.md                         # this file
├── LICENSE                           # MIT (skill code only — see "Third-party content")
├── .gitignore
├── bin/
│   ├── README.md                     # explains the install-on-demand model
│   └── (.exe files appear here after install-binaries.ps1)
├── scripts/
│   ├── install-binaries.ps1          # one-time setup — downloads .exe files from upstream
│   ├── focus-and-send.ps1            # focus a process, then send keys (the everyday combo)
│   ├── focus-and-send.cmd            # cmd.exe equivalent
│   ├── screenshot-active-window.ps1  # capture foreground window to PNG
│   └── wechat-search-and-snap.ps1    # example: focus WeChat, search a chat, screenshot
└── references/
    ├── sendkeys-syntax.md            # full .NET SendKeys cheat sheet
    └── recipes.md                    # task-specific recipes (Chrome, VSCode, MATLAB, WeChat…)
```

## Third-party content

This repository does **not** redistribute the upstream `wmctrl.exe` and `xdotool.exe` binaries — `scripts/install-binaries.ps1` fetches them directly from the upstream maintainer's GitHub repos at install time:

- [ebranlard/wmctrl-for-windows](https://github.com/ebranlard/wmctrl-for-windows)
- [ebranlard/xdotool-for-windows](https://github.com/ebranlard/xdotool-for-windows)

The upstream repos do not currently carry an explicit license. Treat the binaries as third-party software belonging to E. Branlard ([@ebranlard](https://github.com/ebranlard)); credit and any future updates belong to the upstream author.

## License

The skill code in this repository (everything except the binaries `install-binaries.ps1` fetches at install time) is released under the MIT License — see [`LICENSE`](LICENSE).

## Contributing

Issues and pull requests welcome. Common contributions:

- New recipes in `references/recipes.md` for apps not yet covered
- Bug fixes for SendKeys edge cases on specific Windows versions
- Better process-name detection (e.g., handling the WeChat → Weixin rebrand more cleanly)

If you find that an upstream change has broken `install-binaries.ps1` (URL changed, binary rebuilt with a new hash), please open an issue with the new SHA256 so the script can be updated.

## Acknowledgements

- [E. Branlard](https://github.com/ebranlard) for the upstream wmctrl-for-windows and xdotool-for-windows projects
- The original Linux [wmctrl](https://www.freedesktop.org/wiki/Software/wmctrl/) and [xdotool](https://www.semicomplete.com/projects/xdotool/) authors, whose UX inspired this command surface
#   W i n d o w s U s e S k i l l  
 