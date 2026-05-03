<#
.SYNOPSIS
    Focus a Windows app by process name, then send keystrokes to it.

.DESCRIPTION
    Wraps the bundled wmctrl.exe + xdotool.exe with a tunable delay between
    the focus switch and the keystroke send. Default 200 ms is enough for
    most apps; bump to 300-500 ms for Electron / MATLAB / slow-to-focus apps.

    Resolves bin/ relative to this script's location, so PATH config is not
    required.

.PARAMETER Process
    Process name (no .exe suffix). Use `wmctrl -l` to discover.
    Examples: chrome, Code, Cursor, MATLAB, notepad, WeChat.

.PARAMETER Keys
    Keystrokes in .NET SendKeys syntax. See SKILL.md or
    references/sendkeys-syntax.md for the full table.

.PARAMETER DelayMs
    Milliseconds to wait after focusing before sending keys.
    Default 200.

.EXAMPLE
    .\focus-and-send.ps1 -Process chrome -Keys "^t"
    # Open a new tab in Chrome.

.EXAMPLE
    .\focus-and-send.ps1 -Process Code -Keys "^+p"
    # Open VSCode's command palette.

.EXAMPLE
    .\focus-and-send.ps1 -Process MATLAB -Keys "{ESC}^v{ENTER}" -DelayMs 400
    # In MATLAB: clear the prompt, paste clipboard, run it.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Process,

    [Parameter(Mandatory = $true)]
    [string]$Keys,

    [int]$DelayMs = 200
)

$ErrorActionPreference = 'Stop'

# Resolve bundled binaries relative to this script's folder.
$binDir  = Join-Path $PSScriptRoot '..\bin'
$wmctrl  = Join-Path $binDir 'wmctrl.exe'
$xdotool = Join-Path $binDir 'xdotool.exe'

foreach ($exe in @($wmctrl, $xdotool)) {
    if (-not (Test-Path $exe)) {
        Write-Error "Cannot find $exe. The bin/ directory next to scripts/ is missing or moved."
        exit 1
    }
}

# 1. Focus the target window.
& $wmctrl -a $Process
if ($LASTEXITCODE -ne 0) {
    Write-Error "wmctrl could not focus a window for process '$Process'. Run '$wmctrl -l' to see available processes."
    exit $LASTEXITCODE
}

# 2. Give Windows a moment to actually transfer focus.
Start-Sleep -Milliseconds $DelayMs

# 3. Send the keystrokes to the now-foreground window.
& $xdotool key $Keys
exit $LASTEXITCODE
