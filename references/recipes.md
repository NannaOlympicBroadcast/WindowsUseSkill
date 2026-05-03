# Recipes

Drop-in patterns for common Windows automation tasks. Each recipe assumes you're invoking from the `windows-use/` skill directory in PowerShell unless noted otherwise. Adapt as needed.

## Discovering process names

Always the first step when targeting an unfamiliar app:

```powershell
.\bin\wmctrl.exe -l
```

Output is `PID\tProcessName\tWindowTitle`. The middle column is what you pass to `-a`. Note that the same app can have different process names across versions (e.g., WeChat → Weixin) — check rather than guess.

---

## Mouse operations (`mouse-click.ps1`)

`scripts/mouse-click.ps1` provides mouse control without any extra binaries: it calls `user32!SetCursorPos` + `mouse_event` directly via PowerShell P/Invoke.

**Finding coordinates:** take a screenshot with `screenshot-active-window.ps1`, open the PNG in Paint, and hover over the target element — the pixel position appears in the status bar. Or, while hovering over the element in the live window, run:

```powershell
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Cursor]::Position
```

### Quick reference

| Task | Command |
|------|---------|
| Left-click | `.\scripts\mouse-click.ps1 -X 960 -Y 540` |
| Right-click (context menu) | `.\scripts\mouse-click.ps1 -X 960 -Y 540 -Button Right` |
| Middle-click (open in new tab) | `.\scripts\mouse-click.ps1 -X 760 -Y 85 -Button Middle` |
| Double-click | `.\scripts\mouse-click.ps1 -X 400 -Y 300 -DoubleClick` |
| Move cursor only (hover) | `.\scripts\mouse-click.ps1 -X 960 -Y 540 -Button None` |
| Click-and-drag | `.\scripts\mouse-click.ps1 -X 100 -Y 200 -DragToX 500 -DragToY 200` |

### Focus then click

Always focus the target window before clicking — a click landing on an unfocused window may only bring it to the foreground without registering the intended action:

```powershell
# Focus Chrome, then click the address bar
.\scripts\focus-and-send.ps1 -Process chrome -Keys ""
Start-Sleep -Milliseconds 200
.\scripts\mouse-click.ps1 -X 760 -Y 48     # approximate address-bar Y for maximised Chrome
```

### Select text with drag

```powershell
# Drag to select a word or region in any text editor
.\scripts\focus-and-send.ps1 -Process notepad -Keys ""
Start-Sleep -Milliseconds 200
.\scripts\mouse-click.ps1 -X 150 -Y 120 -DragToX 350 -DragToY 120
```

### Screenshot → inspect coordinates → click workflow

```powershell
# 1. Focus the target app and snapshot it
.\scripts\focus-and-send.ps1 -Process SomeApp -Keys ""
Start-Sleep -Milliseconds 300
.\scripts\screenshot-active-window.ps1 -OutPath "$env:TEMP\snap.png"

# 2. Open the screenshot in Paint (or IrfanView) to read pixel coordinates
Start-Process mspaint "$env:TEMP\snap.png"
# Hover over the button you want to click; note the X, Y in the status bar.

# 3. Click at those coordinates
.\scripts\mouse-click.ps1 -X <X> -Y <Y>
```

---

## Chrome / Edge

Process names: `chrome`, `msedge`.

| Task                          | Command |
|-------------------------------|---------|
| Open new tab                  | `.\scripts\focus-and-send.ps1 -Process chrome -Keys "^t"` |
| Close current tab             | `.\scripts\focus-and-send.ps1 -Process chrome -Keys "^w"` |
| Reload current tab            | `.\scripts\focus-and-send.ps1 -Process chrome -Keys "^r"` |
| Hard reload (bypass cache)    | `.\scripts\focus-and-send.ps1 -Process chrome -Keys "^+r"` |
| Reopen last closed tab        | `.\scripts\focus-and-send.ps1 -Process chrome -Keys "^+t"` |
| Switch to tab N (1-8)         | `.\scripts\focus-and-send.ps1 -Process chrome -Keys "^N"` (e.g. `^3`) |
| Switch to last tab            | `.\scripts\focus-and-send.ps1 -Process chrome -Keys "^9"` |
| Toggle fullscreen             | `.\scripts\focus-and-send.ps1 -Process chrome -Keys "{F11}"` |
| DevTools                      | `.\scripts\focus-and-send.ps1 -Process chrome -Keys "{F12}"` |
| Address bar (focus URL)       | `.\scripts\focus-and-send.ps1 -Process chrome -Keys "^l"` |
| Navigate to URL               | see "navigate to URL" below |

### Navigate to a URL

```powershell
$url = "https://github.com/anthropics"
.\scripts\focus-and-send.ps1 -Process chrome -Keys "^l"          # focus URL bar
Start-Sleep -Milliseconds 100
$url | Set-Clipboard                                             # avoid escaping in URLs
.\bin\xdotool.exe key "^v{ENTER}"                                # paste + go
```

URLs frequently contain `&`, `#`, `=`, `?`, etc. None of these are SendKeys-special, but `~` (tilde) is, so always paste rather than typing if the URL might contain unusual chars.

---

## VSCode / Cursor

Process names: `Code` (VSCode), `Cursor` (Cursor IDE). Same shortcuts work for both.

| Task                          | Keys           |
|-------------------------------|----------------|
| Command palette               | `^+p`          |
| Quick file open               | `^p`           |
| Save current file             | `^s`           |
| Save all files                | `^k s` (chord — see below) |
| Toggle terminal               | `^``` (backtick — escape as needed in shell, see below) |
| Toggle sidebar                | `^b`           |
| Run current file              | `^{F5}`        |
| Format document               | `+%f` (Shift+Alt+F) |
| Comment line(s)               | `^/`           |

### Chord shortcuts (Ctrl+K, S)

VSCode uses two-step chords for some commands. SendKeys doesn't have a "release Ctrl between keys" primitive; the workaround is to send each press of Ctrl separately:

```powershell
# Save All in VSCode = Ctrl+K, then S (Ctrl released between)
.\scripts\focus-and-send.ps1 -Process Code -Keys "^k"
Start-Sleep -Milliseconds 50
.\bin\xdotool.exe key "s"
```

### The backtick problem

`` ` `` is PowerShell's escape character. To pass a literal backtick to xdotool from PowerShell, use a single-quoted string:

```powershell
.\scripts\focus-and-send.ps1 -Process Code -Keys '^`'        # toggle terminal
```

---

## MATLAB

Process name: `MATLAB`. The Command Window must have focus, which `wmctrl -a MATLAB` should provide for the main IDE.

| Task                          | Recipe |
|-------------------------------|--------|
| Clear command prompt input    | `.\scripts\focus-and-send.ps1 -Process MATLAB -Keys "{ESC}"` |
| Paste from clipboard and run  | `.\scripts\focus-and-send.ps1 -Process MATLAB -Keys "{ESC}^v{ENTER}" -DelayMs 300` |
| Stop current execution        | `.\scripts\focus-and-send.ps1 -Process MATLAB -Keys "^c"` |
| Run current section           | `.\scripts\focus-and-send.ps1 -Process MATLAB -Keys "^+{ENTER}"` |

The `-DelayMs 300` bump is recommended — MATLAB's main window is slow to accept input right after focus on cold start.

### Paste-and-run a Python-style multi-line block

MATLAB's Command Window doesn't accept multi-line paste with internal newlines well. Instead, paste into the Editor:

```powershell
$code = @"
x = 0:0.01:2*pi;
y = sin(x) .* cos(2*x);
plot(x, y);
"@
$code | Set-Clipboard
.\scripts\focus-and-send.ps1 -Process MATLAB -Keys "^n" -DelayMs 300       # new editor window
Start-Sleep -Milliseconds 200
.\bin\xdotool.exe key "^v"                                                  # paste
Start-Sleep -Milliseconds 100
.\bin\xdotool.exe key "{F5}"                                                # run
```

---

## Notepad (and any plain edit-control app)

Process name: `notepad`. Useful as a sanity check for keystroke recipes.

```powershell
Start-Process notepad
Start-Sleep -Seconds 1
.\scripts\focus-and-send.ps1 -Process notepad -Keys "Test the skill{ENTER}{F5}"
# F5 in Notepad inserts a timestamp — confirms keys are reaching the right window
```

---

## WeChat (微信) — search, open chat, screenshot

Process names: `WeChat` (older builds) or `Weixin` (newer "Weixin / 微信 4.0+" rebrand on Windows). Use `wmctrl -l` to confirm.

The bundled `wechat-search-and-snap.ps1` automates the full flow:

```powershell
.\scripts\wechat-search-and-snap.ps1 -ChatName "言言学姐"
# → focuses WeChat, Ctrl+F, types name, Enter, screenshots window
# → saves to Pictures\Screenshots\wechat_<name>_<timestamp>.png
```

If your WeChat build uses `Weixin` instead:

```powershell
.\scripts\wechat-search-and-snap.ps1 -ChatName "言言学姐" -ProcessName Weixin
```

If `Ctrl+F` doesn't open the search box on your version, override:

```powershell
.\scripts\wechat-search-and-snap.ps1 -ChatName "言言学姐" -SearchShortcut "^k"
```

### What the script does, step by step

1. `wmctrl -a WeChat` — focuses the main WeChat window (the chat list pane on the left, message pane on the right)
2. `xdotool key "^f"` — opens the in-app search box
3. `xdotool key "^a{DELETE}"` — clears any leftover query
4. `xdotool key "<chat name>"` — types the search term as literal text (with metachar escaping for `+ ^ % ~ ( ) [ ] { }`)
5. waits 600 ms for WeChat to populate results
6. `xdotool key "{ENTER}"` — opens the top result
7. waits 500 ms for the chat to render
8. calls `screenshot-active-window.ps1` to capture the WeChat window

### Common reasons it lands on the wrong chat

- **Chat name too generic** — WeChat's search returns multiple matches sorted by recency. Use a more specific substring, or part of the contact's WeChat ID.
- **Search shortcut rebound** — check WeChat → Settings → Hotkeys (设置 → 通用设置 → 快捷按键).
- **Wrong process focused** — `WeChatAppEx` is the mini-program runtime, not the main app. `-ProcessName WeChat` (or `Weixin`) is the right target.

### Cropping to just the message pane

The screenshot includes the whole WeChat window (sidebar + chat list + message pane). To crop to just the message pane, post-process with `System.Drawing`:

```powershell
$src = '...wechat_xxx.png'
$bmp = [System.Drawing.Image]::FromFile($src)
# Message pane is typically the right ~65% of the window. Adjust as needed.
$crop = New-Object System.Drawing.Rectangle ([int]($bmp.Width * 0.35)), 0, ([int]($bmp.Width * 0.65)), $bmp.Height
$cropped = New-Object System.Drawing.Bitmap $crop.Width, $crop.Height
$g = [System.Drawing.Graphics]::FromImage($cropped)
$g.DrawImage($bmp, 0, 0, $crop, [System.Drawing.GraphicsUnit]::Pixel)
$cropped.Save($src.Replace('.png', '_pane.png'))
$g.Dispose(); $cropped.Dispose(); $bmp.Dispose()
```

---

## Generic recipe template

When the user asks for a new app you haven't automated before, work through these questions:

1. **What's the process name?** Run `.\bin\wmctrl.exe -l` and look for the app. Note: `Process.GetProcessesByName` matching is exact, no substring.
2. **What keyboard shortcut performs the task?** Check the app's menus — most expose shortcuts in tooltips. If the task is mouse-only in the UI, this skill can't help; suggest AutoHotkey instead.
3. **Does the action involve typing text?** If yes, decide between literal text (escape `+ ^ % ~ ( ) [ ] { }`) and clipboard paste (`Set-Clipboard` then `^v`). Clipboard is more reliable for anything non-trivial.
4. **Is there a confirm dialog?** Build delays + Enter / Escape into the sequence.
5. **Wrap into a `.ps1` if it's more than two steps** — easier to debug and re-run than a one-liner.

Then test on Notepad first — if your keystroke spelling works there, it'll work in your real target.
