<#
.SYNOPSIS
    Move the mouse cursor and optionally click or drag at a screen coordinate.

.DESCRIPTION
    Uses user32!SetCursorPos and mouse_event (via P/Invoke) to position the
    cursor at absolute screen coordinates and fire mouse-button events.
    Supports left-click, right-click, middle-click, double-click, and
    click-and-drag — no extra binaries required beyond what ships with Windows.

    Coordinates are physical screen pixels; origin (0,0) is at the top-left
    corner of the primary monitor. On multi-monitor setups the origin shifts
    to the top-left corner of the virtual desktop (the leftmost/topmost monitor
    in your display arrangement).

    Tip: use screenshot-active-window.ps1 to capture the target window first,
    then read pixel coordinates from any image viewer (Paint, IrfanView, …).

.PARAMETER X
    Horizontal screen coordinate in pixels (from the left edge of the screen).

.PARAMETER Y
    Vertical screen coordinate in pixels (from the top edge of the screen).

.PARAMETER Button
    Which mouse button to press and release:
        Left    — primary / left click (default)
        Right   — secondary / right click (opens context menu)
        Middle  — middle click (often opens a link in a new browser tab)
        None    — move the cursor only, without clicking

.PARAMETER DoubleClick
    Send two clicks in rapid succession (double-click timing).
    Cannot be combined with -DragToX / -DragToY.

.PARAMETER DragToX
    Horizontal destination for a drag operation. Must be used together with
    -DragToY. When provided, the script holds the button down at (X, Y),
    moves to (DragToX, DragToY), then releases — useful for drag-and-drop or
    selecting a screen region.

.PARAMETER DragToY
    Vertical destination for a drag operation (see -DragToX).

.PARAMETER SettleMs
    Milliseconds to wait after each cursor move before the next action.
    Default 50. Increase for apps that react to hover or are slow to repaint.

.EXAMPLE
    .\mouse-click.ps1 -X 960 -Y 540
    # Left-click at the center of a 1920x1080 display.

.EXAMPLE
    .\mouse-click.ps1 -X 200 -Y 150 -Button Right
    # Right-click at (200, 150) to open a context menu.

.EXAMPLE
    .\mouse-click.ps1 -X 400 -Y 300 -DoubleClick
    # Double-click at (400, 300) — typical for opening a file or folder.

.EXAMPLE
    .\mouse-click.ps1 -X 100 -Y 200 -DragToX 500 -DragToY 200
    # Click-and-drag from (100, 200) to (500, 200), e.g. to select a text range.

.EXAMPLE
    .\mouse-click.ps1 -X 960 -Y 540 -Button None
    # Move cursor to (960, 540) without clicking (hover / tooltip trigger).

.EXAMPLE
    # Focus a window first, then click a specific button inside it.
    .\scripts\focus-and-send.ps1 -Process notepad -Keys ""
    Start-Sleep -Milliseconds 200
    .\scripts\mouse-click.ps1 -X 120 -Y 30   # click the File menu
#>

param(
    [Parameter(Mandatory = $true)]
    [int]$X,

    [Parameter(Mandatory = $true)]
    [int]$Y,

    [ValidateSet('Left', 'Right', 'Middle', 'None')]
    [string]$Button = 'Left',

    [switch]$DoubleClick,

    [int]$DragToX,
    [int]$DragToY,

    [int]$SettleMs = 50
)

$ErrorActionPreference = 'Stop'

# Validate drag parameters: both or neither must be supplied.
$hasDragToX = $PSBoundParameters.ContainsKey('DragToX')
$hasDragToY = $PSBoundParameters.ContainsKey('DragToY')
$dragging   = $hasDragToX -or $hasDragToY

if ($dragging) {
    if (-not $hasDragToX -or -not $hasDragToY) {
        Write-Error '-DragToX and -DragToY must both be provided together for a drag operation.'
        exit 1
    }
    if ($DoubleClick) {
        Write-Error '-DoubleClick and -DragToX/-DragToY cannot be combined.'
        exit 1
    }
    if ($Button -eq 'None') {
        Write-Error "-Button None cannot be combined with -DragToX/-DragToY (a drag requires a button)."
        exit 1
    }
}

# Load P/Invoke stubs once per PowerShell session.
if (-not ('WinUseMouse.NativeMethods' -as [type])) {
    Add-Type -Namespace WinUseMouse -Name NativeMethods -MemberDefinition @'
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        [return: System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.Bool)]
        public static extern bool SetCursorPos(int X, int Y);

        // mouse_event is the legacy (but still fully functional on modern Windows)
        // mouse-input API. We use SetCursorPos to position first, then fire button
        // events at (0,0) because the coordinates here are ignored when using
        // MOUSEEVENTF_ABSOLUTE without MOUSEEVENTF_MOVE.
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern void mouse_event(uint dwFlags, uint dx, uint dy,
                                              uint cButtons, uint dwExtraInfo);
'@
}

# mouse_event flag constants.
$MOUSEEVENTF_LEFTDOWN   = [uint32]0x0002
$MOUSEEVENTF_LEFTUP     = [uint32]0x0004
$MOUSEEVENTF_RIGHTDOWN  = [uint32]0x0008
$MOUSEEVENTF_RIGHTUP    = [uint32]0x0010
$MOUSEEVENTF_MIDDLEDOWN = [uint32]0x0020
$MOUSEEVENTF_MIDDLEUP   = [uint32]0x0040

function Move-Cursor([int]$cx, [int]$cy) {
    if (-not [WinUseMouse.NativeMethods]::SetCursorPos($cx, $cy)) {
        Write-Error "SetCursorPos($cx, $cy) failed — coordinate may be outside the virtual desktop bounds."
        exit 1
    }
    if ($SettleMs -gt 0) { Start-Sleep -Milliseconds $SettleMs }
}

function Send-ButtonEvent([uint32]$flag) {
    [WinUseMouse.NativeMethods]::mouse_event($flag, 0, 0, 0, 0)
}

# Resolve which button flags to use.
$downFlag = $null
$upFlag   = $null
if ($Button -ne 'None') {
    switch ($Button) {
        'Left'   { $downFlag = $MOUSEEVENTF_LEFTDOWN;   $upFlag = $MOUSEEVENTF_LEFTUP   }
        'Right'  { $downFlag = $MOUSEEVENTF_RIGHTDOWN;  $upFlag = $MOUSEEVENTF_RIGHTUP  }
        'Middle' { $downFlag = $MOUSEEVENTF_MIDDLEDOWN; $upFlag = $MOUSEEVENTF_MIDDLEUP }
    }
}

# 1. Move cursor to start position.
Move-Cursor $X $Y

if ($dragging) {
    # Drag: press down at (X,Y), glide to destination, release.
    Send-ButtonEvent $downFlag
    Start-Sleep -Milliseconds 30   # brief pause so the OS registers the press
    Move-Cursor $DragToX $DragToY
    Send-ButtonEvent $upFlag
    Write-Output "Dragged ($Button) from ($X, $Y) to ($DragToX, $DragToY)"
} elseif ($Button -ne 'None') {
    # Click (single or double).
    Send-ButtonEvent $downFlag
    Send-ButtonEvent $upFlag
    if ($DoubleClick) {
        Start-Sleep -Milliseconds 50   # inter-click gap for OS double-click recognition
        Send-ButtonEvent $downFlag
        Send-ButtonEvent $upFlag
        Write-Output "Double-$Button-clicked at ($X, $Y)"
    } else {
        Write-Output "$Button-clicked at ($X, $Y)"
    }
} else {
    Write-Output "Moved cursor to ($X, $Y)"
}
