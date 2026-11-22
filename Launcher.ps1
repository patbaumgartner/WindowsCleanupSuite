#requires -Version 5.1
<#
.SYNOPSIS
    Self-executing launcher for WindowsCleanupSuite: downloads the latest GitHub
    Release zip (or, when no release exists yet, the branch source archive),
    extracts it, and launches the interactive menu (Runners\Run-Menu.ps1).

    Run directly with PowerShell (the Raphire/Win11Debloat style) - the `| iex`
    is what executes it; plain `irm <url>` only prints the script:

      irm https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/main/Launcher.ps1 | iex

    Or via curl (Windows):

      curl.exe -L https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/main/Launcher.ps1 -o "%TEMP%\Launcher.ps1"
      powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\Launcher.ps1"

    Works on Windows PowerShell 5.1 and PowerShell 7.x.

    It extracts the zip and runs the extracted menu, so you always get the
    latest published version (and can re-run the launcher to update later).

.PARAMETER ZipUrl
    Override the zip URL (for testing/forks; also skips the GitHub-API lookup).

.PARAMETER Branch
    Branch used for the source-archive fallback when no GitHub release exists
    (default: main, the repo's default branch).

.PARAMETER InstallDir
    Directory to extract to (default: %TEMP%\WindowsCleanupSuite).

.PARAMETER Launch
    Launch the interactive menu after extraction (default: $true). Pass -Launch:$false
    to extract only and print the menu path.

.PARAMETER WhatIf
    Preview the steps (URL, extract dir, menu path) without downloading or running.

.EXAMPLE
    irm https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/main/Launcher.ps1 | iex
#>
# NOTE: `irm <url>` alone only prints the script text - always pipe to `iex`
# (or download it and run with -File) to actually execute the launcher.
[CmdletBinding()]
param(
    [string]$ZipUrl,
    [string]$Branch = 'main',
    [string]$InstallDir,
    [switch]$Launch = $true,
    [switch]$WhatIf
)

# owner/repo for the GitHub API (NOT a full URL - the API path is /repos/{owner}/{repo})
$Repo    = 'patbaumgartner/WindowsCleanupSuite'
$RepoUrl = "https://github.com/$Repo"

# PS 5.1 on older Windows defaults to TLS 1.0/1.1 which GitHub rejects; force TLS 1.2+.
try {
    if ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12) { }
    else { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 }
} catch { }

# --- Dry run (before any network/download) -----------------------------------------
if ($WhatIf) {
    Write-Host 'Launcher (dry run):' -ForegroundColor Cyan
    if ($ZipUrl) { Write-Host "  Zip: $ZipUrl" }
    else {
        Write-Host "  Would query GitHub API for the latest release zip of $Repo"
        Write-Host "  Fallback (no release yet): branch archive $Branch -> https://codeload.github.com/$Repo/zip/refs/heads/$Branch"
    }
    if (-not $InstallDir) { $InstallDir = Join-Path $env:TEMP 'WindowsCleanupSuite' }
    Write-Host "  Extract to: $InstallDir"
    if ($Launch) { Write-Host '  Launch menu: Run-Menu.ps1 (located recursively in the extracted suite)' }
    exit 0
}

# --- Resolve the zip ------------------------------------------------------------
$zip = $null
if ($ZipUrl) {
    $zip = [pscustomobject]@{ Url = $ZipUrl; Name = (Split-Path -Path $ZipUrl -Leaf); Source = '-ZipUrl override' }
} else {
    $latest = $null
    try {
        $release = Invoke-WebRequest -Uri "https://api.github.com/repos/$Repo/releases/latest" -UseBasicParsing -ErrorAction Stop -TimeoutSec 60 | ConvertFrom-Json
        $asset = @($release.assets | Where-Object { $_.Name -like 'WindowsCleanupSuite-*.zip' }) | Select-Object -First 1
        if ($asset) { $latest = [pscustomobject]@{ Url = $asset.browser_download_url; Name = $asset.Name; Source = "release $($release.tag_name)" } }
    } catch { $latest = $null }

    if (-not $latest) {
        # No published release (yet): fall back to the branch source archive so the
        # one-liner works even before the first vX.Y.Z tag.
        $latest = [pscustomobject]@{
            Url    = "https://codeload.github.com/$Repo/zip/refs/heads/$Branch"
            Name   = "WindowsCleanupSuite-$Branch.zip"
            Source = "branch '$Branch' source archive (no release published yet)"
        }
        Write-Host "No release zip found on GitHub - falling back to $($latest.Source)" -ForegroundColor Yellow
    }
    $zip = $latest
}
Write-Host "Source: $($zip.Source)"

$zipFile = Join-Path $env:TEMP $zip.Name

# --- Download + extract ------------------------------------------------------------
if (Test-Path $zipFile) { Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue }
Write-Host "Downloading: $($zip.Url)"
try {
    Invoke-WebRequest -Uri $zip.Url -OutFile $zipFile -UseBasicParsing -TimeoutSec 300 -ErrorAction Stop
} catch {
    Write-Error "Failed to download $($zip.Url): $($_.Exception.Message)"
    exit 1
}
if (-not (Test-Path $zipFile)) { Write-Error "Download failed (no file at $zipFile)"; exit 1 }

if (-not $InstallDir) { $InstallDir = Join-Path $env:TEMP 'WindowsCleanupSuite' }
Write-Host "Extracting to: $InstallDir"
# Wipe any previous extraction so stale files from an older release can never
# mix into the new one ("Missing script" warnings). Removal can fail on locked
# files (e.g. a suite instance still running from that dir) - retry, and if it
# still fails, fall back to a fresh timestamped directory instead of merging.
if (Test-Path $InstallDir) {
    $removed = $false
    for ($i = 0; $i -lt 3 -and -not $removed; $i++) {
        Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $InstallDir)) { $removed = $true } else { Start-Sleep -Seconds 2 }
    }
    if (-not $removed) {
        $InstallDir = Join-Path $env:TEMP ("WindowsCleanupSuite-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Write-Host "  Previous install dir was locked - using a fresh dir instead: $InstallDir" -ForegroundColor Yellow
    }
}
try {
    Expand-Archive -Path $zipFile -DestinationPath $InstallDir -Force -ErrorAction Stop
} catch {
    Write-Error "Failed to extract $zipFile to $InstallDir - $($_.Exception.Message)"
    exit 1
}
# Sanity: a correct release zip keeps the directory structure (Cleanups\, Runners\).
if (-not (Test-Path (Join-Path $InstallDir 'Cleanups')) -or -not (Test-Path (Join-Path $InstallDir 'Runners'))) {
    Write-Warning "Extracted suite at $InstallDir looks incomplete (no Cleanups\\ or Runners\\) - the archive layout may be wrong."
}

# --- Launch -------------------------------------------------------------------------
if ($Launch) {
    $menuPath = Get-ChildItem -Path $InstallDir -Recurse -Filter 'Run-Menu.ps1' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $menuPath) {
        Write-Error "Menu not found in extracted suite: $InstallDir (expected Runners\Run-Menu.ps1)"
        exit 1
    }
    Write-Host "Launching: $menuPath" -ForegroundColor Green
    & $menuPath.FullName
    exit $LASTEXITCODE
} else {
    # Branch archives extract with a top-level '<repo>-<branch>' folder; release
    # zips keep the repo layout (Runners\Run-Menu.ps1) - locate the menu
    # recursively anyway so both layouts work.
    $menuPath = Get-ChildItem -Path $InstallDir -Recurse -Filter 'Run-Menu.ps1' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($menuPath) {
        Write-Host "Suite extracted to $InstallDir. Launch with: & '$($menuPath.FullName)'" -ForegroundColor Gray
    } else {
        Write-Host "Suite extracted to $InstallDir, but Run-Menu.ps1 was not found - check the archive layout." -ForegroundColor Yellow
    }
    exit 0
}
