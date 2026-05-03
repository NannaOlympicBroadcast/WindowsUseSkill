---
name: windows-use
description: Drive Windows GUI applications from a shell using two bundled tiny binaries — wmctrl.exe (list windows / switch focus by process name) and xdotool.exe (send keystrokes to the active window, including modifier combos like Ctrl+V, Alt+F4, arrow keys, and literal text). Includes PowerShell helpers for the focus-then-send pattern and a .NET-based active-window screenshot tool that fills in the one capability the upstream binaries lack. Use this whenever the user wants to automate a Windows desktop app from the command line — switching focus between Chrome / VSCode / Cursor / MATLAB / WeChat / any other app, pasting clipboard contents into a foreground window, scripting keyboard shortcuts to trigger menu actions, building "computer use lite" workflows that don't need a full screen-reading agent, or capturing the current foreground window. Trigger on mentions of wmctrl, xdotool, SendKeys, "switch to <app> and …", "focus <app>", "send keys", "paste into <window>", "screenshot the active window", "automate Windows GUI", or any request that maps to focus-window + send-key + maybe-snap.
---

# Windows Use

Two tiny CLI binaries plus a few PowerShell helpers that together let you drive any Windows GUI app from a script: list windows, switch focus by process name, send keystrokes (including literal text), and snapshot the foreground window. Think of it as "computer use lite" — no screen reading, no mouse, just keyboard automation, which is enough for a surprising number of real workflows.

## What's bundled

```
windows-use/
├── bin/                              # fetched on first install (see Setup below)
│   ├── wmctrl.exe                    # list windows / switch focus
│   └── xdotool.exe                   # send keystrokes to the active window
├── scripts/
│   ├── install-binaries.ps1          # one-time setup: downloads the two .exe files
│   ├── focus-and-send.ps1            # the everyday combo (PowerShell, recommended)
│   ├── focus-and-send.cmd            # cmd.exe equivalent (with ^ escaping handled)
│   ├── screenshot-active-window.ps1  # capture current foreground window to PNG
│   └── wechat-search-and-snap.ps1    # example recipe: focus WeChat, search a chat, screenshot
└── references/
    ├── sendkeys-syntax.md            # full .NET SendKeys cheat sheet (read when sending non-trivial keys)
    └── recipes.md                    # task-specific recipes (VSCode, Chrome, MATLAB, WeChat …)
```

## Setup (first time only)

The two `.exe` files this skill drives are not redistributed by the repo — they're fetched from the upstream maintainer's GitHub at install time. From the skill root, run once:

```powershell
.\scripts\install-binaries.ps1
```

That populates `bin/` with `wmctrl.exe` (~5 KB) and `xdotool.exe` (~4 KB), verifying each against a known SHA256. After that, the rest of the skill works offline. If `bin/` is empty when you try to use any other script, the answer is "run install-binaries first".

The binaries are tiny .NET Framework PE32 assemblies built from <https://github.com/ebranlard/wmctrl-for-windows> and <https://github.com/ebranlard/xdotool-for-windows>. They run on any modern Windows (.NET Framework is preinstalled on Windows 7+); no extra install needed beyond the download.

## When to reach for this skill

Use it whenever the task boils down to *focus a window → press some keys* on Windows. Concrete examples:

- Switch to Chrome and reload the current tab
- Focus VSCode/Cursor and trigger "Save All" or "Run Code"
- Bring MATLAB to front, send `Escape` to clear the prompt, then paste clipboard
- Switch to a fiber optic detection demo window and send `q` to stop it
- Open WeChat, search a contact's name, hit Enter to open the chat, screenshot the result
- Any keyboard-shortcut-driven workflow you'd normally do with AutoHotkey but want callable from a Claude session

## When this skill is the wrong tool

Be honest about the limits. These tools **cannot**:

- Move or click the mouse (no click, no drag, no hover)
- Press the Windows key (`{LWIN}` / `^{ESC}`-style tricks won't work — the upstream README confirms this)
- Read text from the screen or interpret what's on screen (no OCR, no UI tree)
- Focus a window by its title — only by **process name**
- Distinguish between multiple instances of the same process (always picks the first match)
- Send keys to a *background* / unfocused window (SendKeys goes to the foreground)
- Press PrintScreen via SendKeys (system-level hook bypasses .NET) — the bundled `screenshot-active-window.ps1` works around this with the .NET drawing API instead

If the user needs mouse control or screen reading, point them at AutoHotkey, PyAutoGUI, or a real "computer use" agent — don't try to fake it with this skill.

## The core loop

Almost every task uses the same three-step pattern:

1. **Discover** the process name with `wmctrl -l` (only needed once per app — process names are stable across runs)
2. **Focus** the window with `wmctrl -a <process_name>`
3. **Send** keystrokes with `xdotool key "<keys>"`

The bundled `scripts/focus-and-send.ps1` wraps steps 2 and 3 with a built-in delay so you don't have to remember the timing.

## Tool 1: `wmctrl.exe`

```
wmctrl [options] [args]

  -h           show help
  -l           list windows: prints PID, process name, window title for every visible window
  -a <PNAME>   switch focus to the first window whose process is named <PNAME>
```

**Critical point: `<PNAME>` is the process name (without `.exe`), not the window title and not a substring of either.** Some common ones:

| App                | Process name      |
|--------------------|-------------------|
| Google Chrome      | `chrome`          |
| Microsoft Edge     | `msedge`          |
| VSCode             | `Code`            |
| Cursor             | `Cursor`          |
| Notepad            | `notepad`         |
| MATLAB             | `MATLAB`          |
| WeChat (微信)      | `WeChat` or `Weixin` (varies by version — check with `-l`) |
| WeChat helper      | `WeChatAppEx`     |
| Windows Terminal   | `WindowsTerminal` |

Always run `wmctrl -l` first when targeting an unfamiliar app — process names are case-sensitive on some Windows versions and the matching is exact.

If multiple instances of the process exist, `-a` switches to the first one and prints a warning naming all of them. There's no built-in way to pick a specific one — if this matters, the user has to close the unwanted instances or live with it.

## Tool 2: `xdotool.exe`

```
xdotool key "<KEYS>"
```

`<KEYS>` follows **.NET `SendKeys.SendWait` syntax**, not the X11 xdotool syntax — same command, different language underneath. The cheat sheet:

| You want to send         | Write                  |
|--------------------------|------------------------|
| Literal text             | `hello world`          |
| Ctrl + key               | `^v` (Ctrl+V), `^c`    |
| Alt + key                | `%{F4}` (Alt+F4)       |
| Shift + key              | `+a` (Shift+A)         |
| Ctrl+Shift+key           | `^+t`                  |
| Function keys            | `{F1}` … `{F12}`       |
| Arrows                   | `{UP}` `{DOWN}` `{LEFT}` `{RIGHT}` |
| Enter                    | `{ENTER}` (or `~` in shorthand) |
| Tab / Esc / Backspace    | `{TAB}` `{ESC}` `{BACKSPACE}` |
| Home / End / PgUp / PgDn | `{HOME}` `{END}` `{PGUP}` `{PGDN}` |
| Delete / Insert          | `{DELETE}` `{INSERT}`  |
| Repeat a key             | `{UP 5}` (Up arrow 5×) |
| A literal `+ ^ % ~ ( ) [ ] { }` | wrap in `{}`: `{+}` `{^}` `{%}` `{~}` `{{}` `{}}` |
| Group modifier over multiple keys | `+(eh)` → Shift+E, Shift+H |

**Two real-world gotchas about `~`:** in SendKeys `~` is **Enter**, not tilde. To send a literal tilde, write `{~}`. And the `{ENTER}` form is more readable, so prefer it.

For anything beyond this table — mouse-modifier combos, keypad keys, the full repeat-syntax — read `references/sendkeys-syntax.md`.

## The shell-escaping trap (read this before composing commands)

The single most common way to break xdotool calls is shell-level character mangling **before** the string ever reaches the binary. The exact same `xdotool key "^v"` works or fails depending on which shell you run it in:

- **PowerShell**: `^`, `%`, `+` are not metacharacters. Quoting with `"..."` Just Works. ✅ **Default to PowerShell.**
- **cmd.exe interactive prompt**: `^` is the line-continuation character, but inside `"..."` it's preserved. So `xdotool key "^v"` works at the cmd prompt.
- **`.bat` / `.cmd` files**: `%` gets parsed twice (variable expansion), so `xdotool key "%{F4}"` in a .bat file becomes `xdotool key "{F4}"` (Alt is gone!). Workaround: use `%%` to escape, or use the `focus-and-send.cmd` helper which handles this.
- **`.bat` / `.cmd` files with `^`**: outside quotes, `^` is the escape char and gets eaten. Inside `"..."` it's preserved. So always quote the key string.

**Rule of thumb: when in doubt, write a `.ps1`. If the user is on cmd.exe, use the bundled `focus-and-send.cmd` which has the escaping right.**

## The everyday combo: `focus-and-send.ps1`

99% of real use is "switch to app, send some keys". The bundled helper does that with a tunable delay between focus and send (default 200 ms — needed because Windows takes a moment to actually transfer focus after `SwitchToThisWindow`).

```powershell
# From anywhere — the script auto-resolves bin/ relative to itself
.\scripts\focus-and-send.ps1 -Process chrome -Keys "^t"          # Ctrl+T (new tab)
.\scripts\focus-and-send.ps1 -Process Code -Keys "^+p"           # VSCode command palette
.\scripts\focus-and-send.ps1 -Process MATLAB -Keys "{ESC}^v{ENTER}" -DelayMs 300
.\scripts\focus-and-send.ps1 -Process notepad -Keys "Hello, world!{ENTER}"
```

There's an equivalent `focus-and-send.cmd` for cmd.exe / batch contexts.

## Sending literal text

`xdotool key "any plain text here"` types the characters one by one. Useful for filling form fields. The only thing to remember is that the eight chars `+ ^ % ~ ( ) [ ] { }` are SendKeys metacharacters and need brace-escaping:

```
xdotool key "user@example.com"          # works — @ . are normal
xdotool key "100% off!"                 # BROKEN — % means Alt
xdotool key "100{%} off!"               # works
xdotool key "(hello)"                   # BROKEN — parens are grouping
xdotool key "{(}hello{)}"               # works
```

For long text or text with many specials, prefer **putting it on the clipboard first then pasting with `^v`** — much more reliable than escaping. PowerShell:

```powershell
"some long text with %weird $chars" | Set-Clipboard
.\scripts\focus-and-send.ps1 -Process Code -Keys "^v"
```

## Screenshots — what's possible

The upstream binaries don't screenshot, and `{PRTSC}` doesn't work through SendKeys. The bundled `scripts/screenshot-active-window.ps1` fills the gap using `System.Drawing.Graphics.CopyFromScreen` against the foreground window's rect (via `user32!GetForegroundWindow` + `GetWindowRect`):

```powershell
.\scripts\screenshot-active-window.ps1 -OutPath "C:\Users\you\Desktop\snap.png"
# omit -OutPath to auto-save to Pictures\Screenshots\winuse_<timestamp>.png
```

Combine with `focus-and-send.ps1` to focus-then-snap any app. See `scripts/wechat-search-and-snap.ps1` for a worked example.

## Recipes

For task-specific cookbook entries (VSCode save-all, Chrome reload, MATLAB paste-and-run, the WeChat search-and-snap workflow, the `wechat-search-and-snap.ps1` script in detail), read `references/recipes.md`. Reach for it whenever the user names a specific app — that file's the right place to add new recipes too.

## Building new automation: a worked example

User: "switch to Cursor and run the current file."

Cursor's "Run File" shortcut is Ctrl+F5 (same as VSCode). Process name is `Cursor`. So:

```powershell
.\scripts\focus-and-send.ps1 -Process Cursor -Keys "^{F5}"
```

That's it. The pattern scales: figure out the process name (use `wmctrl -l` if unsure), figure out the keyboard shortcut (the app's docs / menu shortcut hints), pick the SendKeys spelling, done.

When the keystroke sequence gets long or branchy (e.g., open a panel, type a path, press Enter, wait, press another key), wrap it in a small `.ps1` rather than a single one-liner — easier to read and to add `Start-Sleep` between steps when the app is slow to react.

## Timing

Default 200 ms between focus and first keystroke is enough for most apps. Slower apps (MATLAB cold-start, Electron apps under load) may need 300–500 ms. If keys are arriving at the wrong window, the fix is almost always "increase the delay", not "send the keys faster".

For multi-step sequences inside the same window, .NET's `SendKeys.SendWait` is synchronous (blocks until the OS acknowledges the keystroke), so consecutive `xdotool key` calls don't need delays between them — but if you're sending into an app that does heavy work between keystrokes (compiles, dialog popups), insert `Start-Sleep -Milliseconds 200` in PowerShell or `timeout /t 1 /nobreak` in cmd.

## Source & attribution

- wmctrl-for-windows: <https://github.com/ebranlard/wmctrl-for-windows>
- xdotool-for-windows: <https://github.com/ebranlard/xdotool-for-windows>

The C# source is small (one file each) and worth a glance if behavior surprises you. See `bin/README.md` for the relevant excerpts and how to rebuild from source.
