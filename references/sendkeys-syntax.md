# SendKeys syntax — full reference

`xdotool.exe key "<KEYS>"` is a one-liner around `System.Windows.Forms.SendKeys.SendWait(<KEYS>)`. Everything that follows is .NET SendKeys behavior, which is documented (somewhat) by Microsoft but has enough quirks to deserve a full table here.

Read this when the SKILL.md cheat sheet doesn't cover what you need.

## Modifier prefixes

A modifier applies to **the very next character or `{...}` group**, not the rest of the string. To apply a modifier across multiple keys, group them with `( )`.

| Char | Modifier | Example       | Means                  |
|------|----------|---------------|------------------------|
| `^`  | Ctrl     | `^a`          | Ctrl+A                 |
| `%`  | Alt      | `%{F4}`       | Alt+F4                 |
| `+`  | Shift    | `+a`          | Shift+A (capital A)    |
| `^+` | Ctrl+Shift | `^+t`       | Ctrl+Shift+T (reopen closed tab in Chrome) |
| `^%` | Ctrl+Alt | `^%{DELETE}` | Ctrl+Alt+Del (most apps will not actually receive this — Windows handles it specially) |

**Group across multiple keys:**

| Send                | What happens                       |
|---------------------|------------------------------------|
| `+ab`               | Shift+A, then plain b → "Ab"       |
| `+(ab)`             | Shift+A, Shift+B → "AB"            |
| `^+(home)`          | Ctrl+Shift+Home (extend selection to top of doc) — note braces around HOME below |
| `^+({HOME})`        | Same, with explicit special-key braces (more readable) |

## Special keys (use inside `{}`)

The braces are mandatory. Names are case-insensitive but conventionally uppercase.

### Navigation
`{UP}` `{DOWN}` `{LEFT}` `{RIGHT}` `{HOME}` `{END}` `{PGUP}` `{PGDN}`

### Editing
`{ENTER}` (or shorthand `~`) · `{TAB}` · `{ESC}` · `{BACKSPACE}` (alias `{BS}`, `{BKSP}`) · `{DELETE}` (alias `{DEL}`) · `{INSERT}` (alias `{INS}`) · `{CLEAR}`

### Function keys
`{F1}` … `{F16}`

### Misc
`{CAPSLOCK}` · `{NUMLOCK}` · `{SCROLLLOCK}` · `{BREAK}` · `{HELP}` (rarely useful)

### Numpad
`{ADD}` (numpad +) · `{SUBTRACT}` (numpad −) · `{MULTIPLY}` (numpad ×) · `{DIVIDE}` (numpad ÷) · plain digits go through the main keyboard row, there's no `{NUMPAD0}` etc. in standard SendKeys

### What is **not** available
- **Windows / Super key** (`{LWIN}` / `{RWIN}` are not in standard SendKeys; the upstream README confirms it doesn't work)
- **PrintScreen** (`{PRTSC}` is silently dropped — the OS hooks it system-side, before .NET sees the keystroke). Use the bundled `screenshot-active-window.ps1` instead.
- **Pause** key
- **Media keys** (volume, play/pause, etc.)
- **Mouse buttons** of any kind

If a workflow needs any of these, this skill is not the right tool — reach for AutoHotkey or PyAutoGUI.

## Repeating a key

`{KEY count}` — the count goes inside the braces with one space.

| Send         | What happens                |
|--------------|-----------------------------|
| `{UP 5}`     | Up arrow, 5 times           |
| `{TAB 3}`    | Tab 3 times                 |
| `{BACKSPACE 10}` | Delete 10 chars to the left |

This only works for keys-in-braces, not literal text. To type "aaaa" you'd write `aaaa` (no SendKeys repeat operator for plain chars).

## Escaping the eight metacharacters

These eight characters mean something special to SendKeys, so to send them literally you wrap them in braces:

| Char | Means              | Literal form |
|------|--------------------|--------------|
| `+`  | Shift modifier     | `{+}`        |
| `^`  | Ctrl modifier      | `{^}`        |
| `%`  | Alt modifier       | `{%}`        |
| `~`  | Enter shortcut     | `{~}`        |
| `(`  | start of group     | `{(}`        |
| `)`  | end of group       | `{)}`        |
| `[`  | reserved           | `{[}`        |
| `]`  | reserved           | `{]}`        |
| `{`  | start of named key | `{{}`        |
| `}`  | end of named key   | `{}}`        |

**Real-world example: typing an email address.** `user@example.com` is fine — neither `@` nor `.` are special. But `100% off` is **broken** because `%` opens an Alt modifier and consumes `o` as Alt+O. Write `100{%} off` instead.

For long strings with many specials, **paste from clipboard** instead of escaping by hand:

```powershell
"some long text with %many $special chars()" | Set-Clipboard
.\focus-and-send.ps1 -Process notepad -Keys "^v"
```

## Layout / locale gotchas

`SendKeys.SendWait("@")` types whatever the **current keyboard layout** maps to the `@` character. On a US layout that's Shift+2; on a German layout it's Ctrl+Alt+Q. The .NET implementation handles most of this for you by simulating the right scan codes for the current layout — but if you target a system in an unexpected layout, debug by sending raw scan-code-style sequences (e.g., `+2` for `@` on US specifically) rather than trusting the literal char.

## When SendKeys silently does the wrong thing

A few patterns produce no error but no effect. Watch for:

- **Sending to an admin-elevated window from a non-elevated process** — Windows blocks input across UIPI levels. If wmctrl/xdotool are running un-elevated and the target window is elevated, nothing happens. Solution: launch the shell elevated.
- **Sending while a UAC prompt is on screen** — the secure desktop locks input out. Wait for UAC to dismiss before retrying.
- **Sending into a remote desktop / VNC viewer that captures keys** — keys go to your local machine, not the remote one. (You'd have to run wmctrl/xdotool inside the remote session.)
- **Race with focus** — focus hasn't actually transferred yet. Increase the delay in `focus-and-send.ps1` (try 400-500 ms).

## Programmatic check: round-trip into Notepad

A quick smoke test for any keystroke recipe:

```powershell
Start-Process notepad
Start-Sleep -Seconds 1
.\focus-and-send.ps1 -Process notepad -Keys "Hello{ENTER}World{ENTER}{F5}"
```

You should see "Hello / World / <current date and time>" in Notepad (F5 in Notepad inserts a timestamp). If anything is off, you know it's the keystroke layer, not your target app.
