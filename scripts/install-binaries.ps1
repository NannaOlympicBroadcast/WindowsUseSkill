<#
.SYNOPSIS
    First-time setup: download wmctrl.exe and xdotool.exe from upstream into bin/.

.DESCRIPTION
    This skill does NOT redistribute the upstream binaries. Run this script
    once after cloning to fetch them directly from the original maintainer's
    repos on GitHub. After it succeeds, the rest of the skill works offline.

    Each binary is verified against a known SHA256 hash to detect upstream
    tampering or accidental corruption. If the upstream maintainer ever
    rebuilds the binaries (changing the hash), update the EXPECTED_HASHES
    table below or pass -SkipHashCheck.

.PARAMETER Force
    Re-download even if the binaries already exist in bin/.

.PARAMETER SkipHashCheck
    Skip the SHA256 verification. Use only if the upstream binaries have
    been legitimately rebuilt and you've manually verified them. The
    default behaviour (verify) is the safer one.

.EXAMPLE
    .\install-binaries.ps1
    # First-time setup. Downloads both .exe files into bin/ next to scripts/.

.EXAMPLE
    .\install-binaries.ps1 -Force
    # Force re-download (e.g., to refresh against a new upstream build).

.NOTES
    Upstream sources:
      wmctrl.exe  — https://github.com/ebranlard/wmctrl-for-windows
      xdotool.exe — https://github.com/ebranlard/xdotool-for-windows
    Both repos are public; both binaries live at /_bin/<name>.exe on the
    master branch. They're tiny .NET Framework PE32 assemblies (under 10 KB
    each) and run on any Windows 7+ machine without extra dependencies.
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipHashCheck
)

$ErrorActionPreference = 'Stop'

# Resolve bin/ directory (sibling of scripts/, where this file lives).
$binDir = Join-Path $PSScriptRoot '..\bin'
if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir | Out-Null
}

# Download targets. URLs point to the raw blobs on the upstream master branch.
# Hashes were captured from the binaries the skill author verified — if the
# upstream maintainer rebuilds, these will no longer match and you'll need to
# decide whether to trust the new build (then update this table).
$Targets = @(
    @{
        Name = 'wmctrl.exe'
        Url  = 'https://github.com/ebranlard/wmctrl-for-windows/raw/master/_bin/wmctrl.exe'
        Sha256 = 'A9E85D5BB09B2DAE8809B50407B782CED8D5FD95C09FBB37CF93548B99612274'
    },
    @{
        Name = 'xdotool.exe'
        Url  = 'https://github.com/ebranlard/xdotool-for-windows/raw/master/_bin/xdotool.exe'
        Sha256 = '682215F6259D397C888A2EA92805E6C17DA09C3A80CE30261A4E30C6F12F829A'
    }
)

# Force TLS 1.2+ — older PowerShell defaults block GitHub raw fetches on some Win10 builds.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

foreach ($t in $Targets) {
    $dest = Join-Path $binDir $t.Name

    if ((Test-Path $dest) -and -not $Force) {
        Write-Host "[skip] $($t.Name) already present at $dest. Pass -Force to re-download."
        continue
    }

    Write-Host "[download] $($t.Url)"
    try {
        # Invoke-WebRequest with -UseBasicParsing works on PS 5.1 (no IE engine needed).
        Invoke-WebRequest -Uri $t.Url -OutFile $dest -UseBasicParsing
    } catch {
        Write-Error "Download failed for $($t.Name): $_"
        exit 1
    }

    if (-not $SkipHashCheck) {
        $actual = (Get-FileHash -Path $dest -Algorithm SHA256).Hash
        if ($actual -ne $t.Sha256) {
            Write-Error @"
SHA256 mismatch for $($t.Name).
  expected: $($t.Sha256)
  actual:   $actual

This either means the upstream binary was rebuilt (in which case update the
hash in this script after manually verifying the new build) or something
between you and GitHub modified the file in transit. Either way, the file
has been left in place at $dest for inspection — delete it manually if you
do not trust it.
"@
            exit 1
        }
        Write-Host "[verified] $($t.Name) SHA256 matches expected"
    } else {
        Write-Warning "[skipped hash check] $($t.Name)"
    }
}

Write-Host ""
Write-Host "Done. Binaries are in: $binDir"
Write-Host "Next: try '.\scripts\focus-and-send.ps1 -Process notepad -Keys ""Hello{ENTER}""' as a smoke test."
