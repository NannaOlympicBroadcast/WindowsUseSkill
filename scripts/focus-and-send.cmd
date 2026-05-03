@echo off
REM ============================================================================
REM focus-and-send.cmd — cmd.exe equivalent of focus-and-send.ps1
REM
REM Usage:
REM    focus-and-send.cmd <process_name> "<keys>" [delay_ms]
REM
REM Examples:
REM    focus-and-send.cmd chrome "^t"
REM    focus-and-send.cmd Code "^+p"
REM    focus-and-send.cmd MATLAB "{ESC}^v{ENTER}" 400
REM
REM IMPORTANT escaping notes for batch files:
REM   - Always quote the keys argument so cmd doesn't eat the ^.
REM   - To use % inside the keys string from a .bat/.cmd file, you must
REM     write %% (the .bat parser collapses it back to %). Example:
REM         focus-and-send.cmd notepad "100%% off"
REM     From an interactive cmd prompt (not a .bat), single % is fine.
REM ============================================================================

setlocal

if "%~1"=="" goto :usage
if "%~2"=="" goto :usage

set "PROC=%~1"
set "KEYS=%~2"
set "DELAY=%~3"
if "%DELAY%"=="" set "DELAY=200"

set "BIN=%~dp0..\bin"

if not exist "%BIN%\wmctrl.exe"  (echo [error] missing %BIN%\wmctrl.exe & exit /b 1)
if not exist "%BIN%\xdotool.exe" (echo [error] missing %BIN%\xdotool.exe & exit /b 1)

REM 1. Focus.
"%BIN%\wmctrl.exe" -a "%PROC%"
if errorlevel 1 (
    echo [error] wmctrl could not focus process '%PROC%'. Run "%BIN%\wmctrl.exe -l" to list options.
    exit /b 1
)

REM 2. Wait for focus to actually transfer. cmd.exe has no native millisecond
REM    sleep (timeout.exe only does whole seconds; the ping-127.0.0.1 trick
REM    returns instantly, defeating the purpose). The reliable cross-version
REM    way is to delegate to PowerShell, which adds maybe 100ms startup but
REM    gives accurate ms timing.
powershell.exe -NoProfile -NonInteractive -Command "Start-Sleep -Milliseconds %DELAY%"

REM 3. Send keys.
"%BIN%\xdotool.exe" key "%KEYS%"
exit /b %errorlevel%

:usage
echo Usage: %~nx0 ^<process_name^> "^<keys^>" [delay_ms]
echo.
echo Examples ^(at an interactive cmd prompt^):
echo   %~nx0 chrome "^t"
echo   %~nx0 Code "^+p"
echo   %~nx0 MATLAB "{ESC}^v{ENTER}" 400
echo.
echo From a .bat / .cmd file: ^^ inside double quotes is preserved as-is.
echo The one thing that DOES need doubling in .bat files is %%, e.g.
echo   %~nx0 notepad "100%%%% off"   ^(types "100%% off"^)
exit /b 1
