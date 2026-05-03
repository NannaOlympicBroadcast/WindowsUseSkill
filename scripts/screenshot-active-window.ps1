<#
.SYNOPSIS
    Capture the current foreground window to a PNG file.

.DESCRIPTION
    Fills the gap left by xdotool/wmctrl: neither can screenshot, and SendKeys
    can't trigger PrintScreen (the OS hooks it system-side, before .NET sees it).

    Uses user32!GetForegroundWindow + GetWindowRect via P/Invoke to find the
    bounding rectangle of whatever has focus right now, then
    System.Drawing.Graphics.CopyFromScreen to copy that region.

    Run this AFTER focusing the target window — typically right after
    focus-and-send.ps1, with a brief pause to let any animations settle.

.PARAMETER OutPath
    Where to save the PNG. If omitted, defaults to:
        $HOME\Pictures\Screenshots\winuse_<yyyyMMdd_HHmmss>.png
    Parent directory is created if missing.

.PARAMETER FullScreen
    If set, capture the whole primary screen instead of just the active
    window. Useful when the target app spans multiple windows or when the
    foreground window detection picks the wrong target.

.PARAMETER SettleMs
    Milliseconds to wait before snapping. Default 150.
    Helpful when the window has just gained focus (animations, redraws).

.EXAMPLE
    .\screenshot-active-window.ps1
    # Saves to Pictures\Screenshots\winuse_20260503_154212.png

.EXAMPLE
    .\screenshot-active-window.ps1 -OutPath "C:\tmp\snap.png"

.EXAMPLE
    .\focus-and-send.ps1 -Process chrome -Keys "{F11}"
    Start-Sleep -Milliseconds 500
    .\screenshot-active-window.ps1 -OutPath "chrome-fullscreen.png"
#>

param(
    [string]$OutPath,
    [switch]$FullScreen,
    [int]$SettleMs = 150
)

$ErrorActionPreference = 'Stop'

# Default output path: Pictures\Screenshots\winuse_<timestamp>.png
if (-not $OutPath) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $dir   = Join-Path $HOME 'Pictures\Screenshots'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $OutPath = Join-Path $dir "winuse_$stamp.png"
}

# Make sure the output directory exists.
$outDir = Split-Path -Parent $OutPath
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# P/Invoke just enough of user32 to find the foreground window and its rect.
if (-not ('WinUseInterop.NativeMethods' -as [type])) {
    Add-Type -Namespace WinUseInterop -Name NativeMethods -MemberDefinition @'
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern System.IntPtr GetForegroundWindow();

        [System.Runtime.InteropServices.DllImport("user32.dll")]
        [return: System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.Bool)]
        public static extern bool GetWindowRect(System.IntPtr hWnd, out RECT lpRect);

        [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
        public struct RECT {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }
'@
}

# Brief settle time — useful when the window has just been focused.
if ($SettleMs -gt 0) { Start-Sleep -Milliseconds $SettleMs }

if ($FullScreen) {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $x = $bounds.X
    $y = $bounds.Y
    $w = $bounds.Width
    $h = $bounds.Height
} else {
    $hwnd = [WinUseInterop.NativeMethods]::GetForegroundWindow()
    if ($hwnd -eq [IntPtr]::Zero) {
        Write-Error 'No foreground window detected.'
        exit 1
    }
    $rect = New-Object WinUseInterop.NativeMethods+RECT
    if (-not [WinUseInterop.NativeMethods]::GetWindowRect($hwnd, [ref]$rect)) {
        Write-Error 'GetWindowRect failed.'
        exit 1
    }
    $x = $rect.Left
    $y = $rect.Top
    $w = $rect.Right  - $rect.Left
    $h = $rect.Bottom - $rect.Top

    if ($w -le 0 -or $h -le 0) {
        Write-Error "Foreground window has zero/negative size ($w x $h). It may be minimized."
        exit 1
    }
}

$bmp = New-Object System.Drawing.Bitmap $w, $h
try {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size $w, $h))
    } finally {
        $g.Dispose()
    }
    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $bmp.Dispose()
}

Write-Output $OutPath
