# bin/

This directory is **intentionally empty in version control**. The two `.exe`
files this skill needs are *not* redistributed by this repo — they're fetched
directly from the upstream maintainer's repos at install time.

## First-time setup

From the skill root (one directory up from here), run:

```powershell
.\scripts\install-binaries.ps1
```

That fetches:

| File          | Source                                                                       |
|---------------|------------------------------------------------------------------------------|
| `wmctrl.exe`  | https://github.com/ebranlard/wmctrl-for-windows/raw/master/_bin/wmctrl.exe   |
| `xdotool.exe` | https://github.com/ebranlard/xdotool-for-windows/raw/master/_bin/xdotool.exe |

Both are PE32 console executables built from C# against .NET Framework
(preinstalled on Windows 7+). The script verifies the SHA256 of each download
against a known-good hash before declaring success. Pass `-Force` to
re-download an existing copy, or `-SkipHashCheck` if you've intentionally
updated to a newer upstream build (and update the hash table in
`scripts/install-binaries.ps1` while you're at it).

## Why not just bundle the binaries?

The upstream repos don't carry an explicit LICENSE file, so redistributing
the binaries in this repo would be on legally fuzzy ground. Fetching them
fresh from the upstream URLs at install time sidesteps that question — every
user is downloading the binaries directly from the maintainer.

If `install-binaries.ps1` ever fails because the upstream URL or layout
changed, the binaries are 5–10 KB each and you can drop them into this
directory by hand from any working install — no build step needed.

## What each binary does internally

For when something behaves unexpectedly and you want to know which Win32 API
is in play:

- **`wmctrl.exe`**
  - `-l` — enumerates `Process.GetProcesses()` and prints `PID\tProcessName\tMainWindowTitle` for every process whose `MainWindowTitle` is non-empty
  - `-a <name>` — calls `Process.GetProcessesByName(name)`, takes the first match, and calls `user32!SwitchToThisWindow(hWnd)` on its `MainWindowHandle`

- **`xdotool.exe`**
  - `key <keys>` — calls `System.Windows.Forms.SendKeys.SendWait(keys)`. That's the entire implementation. Every quirk of the key syntax is a quirk of .NET SendKeys.

## Rebuilding from source

If you ever need to modify behaviour, the C# source is one short file per
tool in the upstream repos. Build with:

```bash
csc wmctrl.cs                                   # MSVC toolchain
csc xdotool.cs /r:System.Windows.Forms.dll
# or with Mono:
mcs wmctrl.cs
mcs xdotool.cs /r:System.Windows.Forms.dll
```

Drop the resulting `.exe` into this directory and pass `-SkipHashCheck` (or
update the expected hashes in `install-binaries.ps1`) and you're set.

## Attribution

Credit and any future updates to the binaries belong to the upstream author
(E. Branlard / [@ebranlard](https://github.com/ebranlard)).
