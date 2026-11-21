#requires -Version 5.1
<#
.SYNOPSIS
    Self-executing launcher for WindowsCleanupSuite: downloads the latest GitHub
    Release zip, extracts it, and launches the interactive menu (Runners\Run-Menu.ps1).

    Run directly with PowerShell (the Raphire/Win11Debloat style):

      irm https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/master/Launcher.ps1

    Or via curl (Windows):

      curl.exe https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/master/Launcher.ps1 -o "%TEMP%\Launcher.ps1"
      powershell -File "%TEMP%\Launcher.ps1"

    It extracts the release zip and runs the extracted menu, so you always get the
    latest published version (and can re-run the launcher to update later).

.PARAMETER ZipUrl
    Override the release zip URL (for testing/forks; also skips the GitHub-API lookup).

.PARAMETER InstallDir
    Directory to extract to (default: %TEMP%\WindowsCleanupSuite).

.PARAMETER Launch
    Launch the interactive menu after extraction (default: $true). Pass -Launch:$false
    to extract only and print the menu path.

.PARAMETER WhatIf
    Preview the steps (URL, extract dir, menu path) without downloading or running.

.EXAMPLE
    irm https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/master/Launcher.ps1
#>
[CmdletBinding()]
param(
    [string]$ZipUrl,
    [string]$InstallDir,
    [switch]$Launch = $true,
    [switch]$WhatIf
)

$RepoUrl = 'https://github.com/patbaumgartner/WindowsCleanupSuite'

# --- Dry run (before any network/download) -----------------------------------------
if ($WhatIf) {
    Write-Host 'Launcher (dry run):' -ForegroundColor Cyan
    if ($ZipUrl) { Write-Host "  Zip: $ZipUrl" } else { Write-Host '  Would query GitHub API for the latest release zip' }
    if (-not $InstallDir) { $InstallDir = Join-Path $env:TEMP 'WindowsCleanupSuite' }
    Write-Host "  Extract to: $InstallDir"
    if ($Launch) { Write-Host "  Launch menu: $InstallDir\Runners\Run-Menu.ps1" }
    exit 0
}

# --- Resolve the zip ------------------------------------------------------------
$zip = $null
if ($ZipUrl) {
    $zip = [pscustomobject]@{ Url = $ZipUrl; Name = (Split-Path -Path $ZipUrl -Leaf) }
} else {
    $latest = $null
    try {
        $release = Invoke-WebRequest -Uri "https://api.github.com/repos/$RepoUrl/releases/latest" -UseBasicParsing -ErrorAction Stop -TimeoutSec 60 | ConvertFrom-Json
        $asset = @($release.assets | Where-Object { $_.Name -like 'WindowsCleanupSuite-*.zip' }) | Select-Object -First 1
        if ($asset) { $latest = [pscustomobject]@{ Url = $asset.browser_download_url; Name = $asset.Name } }
    } catch { $latest = $null }

    if (-not $latest) {
        Write-Error "Could not resolve the latest release zip. Pass -ZipUrl <url>, or check releases: $RepoUrl/releases"
        exit 1
    }
    $zip = $latest
}

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
if (Test-Path $InstallDir) { Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue }
try {
    Expand-Archive -Path $zipFile -DestinationPath $InstallDir -Force -ErrorAction Stop
} catch {
    Write-Error "Failed to extract $zipFile to $InstallDir - $($_.Exception.Message)"
    exit 1
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
    Write-Host "Suite extracted to $InstallDir. Launch with: & '$InstallDir\Runners\Run-Menu.ps1'" -ForegroundColor Gray
    exit 0
}

