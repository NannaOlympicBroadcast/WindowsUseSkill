<#
.SYNOPSIS
    Focus WeChat (微信), search for a chat by name/keyword, open it, and
    screenshot the WeChat window.

.DESCRIPTION
    Composes the three primitives in this skill:
        1. wmctrl -a   to focus the WeChat process
        2. xdotool key to drive WeChat's in-app search
        3. screenshot-active-window.ps1 to capture the result

    A "specific chat" inside WeChat is NOT a separate OS window — it's a
    pane inside the main WeChat window. So this script focuses the main
    WeChat window, navigates inside it via the search shortcut, and
    screenshots the whole window. Crop afterwards if you only want the
    chat pane on the right.

.PARAMETER ChatName
    Substring to type into WeChat's search box. Should be specific enough
    that the top result is the chat you want — WeChat sorts search results
    by relevance and recent activity.

.PARAMETER ProcessName
    WeChat's process name. Varies by version:
        WeChat       — older Windows builds
        Weixin       — newer "微信 / Weixin" rebrand on Windows
        WeChatAppEx  — the mini-program / sub-app process (NOT what you want)
    Default 'WeChat'. If wmctrl reports "no process found", try Weixin or
    run `wmctrl -l` to see what's actually there.

.PARAMETER SearchShortcut
    Keystroke that opens WeChat's search box once the main window has focus.
    Default '^f' (Ctrl+F) — works in current WeChat Windows builds. If your
    version uses a different binding, override here. Some users have
    rebound this in WeChat settings.

.PARAMETER OutPath
    Where to save the screenshot. Defaults to
    Pictures\Screenshots\wechat_<sanitized-chat-name>_<timestamp>.png.

.PARAMETER FocusDelayMs
    Time to wait after focusing WeChat before sending search keys.
    Default 250 — Electron-based WeChat is sometimes slow to accept input.

.PARAMETER SearchDelayMs
    Time to wait after typing the chat name before pressing Enter to open
    the top result. Default 600 — needs to be long enough for WeChat to
    populate the result list.

.PARAMETER OpenChatDelayMs
    Time to wait after pressing Enter (selecting the chat) before snapping
    the screenshot. Default 500.

.EXAMPLE
    .\wechat-search-and-snap.ps1 -ChatName "言言学姐"

.EXAMPLE
    .\wechat-search-and-snap.ps1 -ChatName "项目101" -ProcessName Weixin -OutPath "C:\tmp\proj101.png"

.NOTES
    WeChat's UI shortcuts can change between versions. If this script lands
    you in the wrong place:
      - Run `wmctrl -l` to confirm the process name
      - Open WeChat manually and check Settings → 通用设置 / Hotkeys for
        the current "open search" binding
      - Override SearchShortcut accordingly
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ChatName,

    [string]$ProcessName    = 'WeChat',
    [string]$SearchShortcut = '^f',
    [string]$OutPath,
    [int]$FocusDelayMs      = 250,
    [int]$SearchDelayMs     = 600,
    [int]$OpenChatDelayMs   = 500
)

$ErrorActionPreference = 'Stop'

$scripts = $PSScriptRoot
$focusAndSend = Join-Path $scripts 'focus-and-send.ps1'
$snap         = Join-Path $scripts 'screenshot-active-window.ps1'

# .NET SendKeys eats `+ ^ % ~ ( ) [ ] { }` literally — escape any that show
# up in the user-supplied chat name so it gets typed as text rather than
# interpreted as modifiers.
function Escape-SendKeysLiteral([string]$s) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        switch ($ch) {
            '+' { [void]$sb.Append('{+}') }
            '^' { [void]$sb.Append('{^}') }
            '%' { [void]$sb.Append('{%}') }
            '~' { [void]$sb.Append('{~}') }
            '(' { [void]$sb.Append('{(}') }
            ')' { [void]$sb.Append('{)}') }
            '[' { [void]$sb.Append('{[}') }
            ']' { [void]$sb.Append('{]}') }
            '{' { [void]$sb.Append('{{}') }
            '}' { [void]$sb.Append('{}}') }
            default { [void]$sb.Append($ch) }
        }
    }
    return $sb.ToString()
}

$escapedName = Escape-SendKeysLiteral $ChatName

# Default output path: include sanitized chat name for easier sorting.
if (-not $OutPath) {
    $sanitized = ($ChatName -replace '[\\/:*?"<>|]', '_').Trim()
    if ([string]::IsNullOrWhiteSpace($sanitized)) { $sanitized = 'chat' }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $dir = Join-Path $HOME 'Pictures\Screenshots'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $OutPath = Join-Path $dir "wechat_${sanitized}_${stamp}.png"
}

Write-Host "[1/4] Focusing process '$ProcessName'..."
& $focusAndSend -Process $ProcessName -Keys $SearchShortcut -DelayMs $FocusDelayMs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to focus WeChat. Try -ProcessName Weixin, or run 'bin\wmctrl.exe -l' to see what's running."
    exit 1
}

# Search box is now (presumably) open. Selecting all + deleting clears any
# stale text in case the search box remembers a previous query.
Write-Host "[2/4] Clearing search box and typing '$ChatName'..."
$clearAndType = "^a{DELETE}$escapedName"
& (Join-Path $PSScriptRoot '..\bin\xdotool.exe') key $clearAndType
Start-Sleep -Milliseconds $SearchDelayMs

# Top result → press Enter to open it.
Write-Host "[3/4] Opening top result..."
& (Join-Path $PSScriptRoot '..\bin\xdotool.exe') key '{ENTER}'
Start-Sleep -Milliseconds $OpenChatDelayMs

Write-Host "[4/4] Capturing WeChat window to $OutPath..."
& $snap -OutPath $OutPath -SettleMs 100
if ($LASTEXITCODE -ne 0) {
    Write-Error 'Screenshot failed.'
    exit 1
}

Write-Host "Done. Saved: $OutPath"
