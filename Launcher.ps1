#requires -Version 5.1
<#
.SYNOPSIS
    Self-executing launcher for WindowsCleanupSuite: downloads the latest GitHub
    Release zip (or, when no release exists yet, the branch source archive),
    extracts it, and launches the interactive menu (Runners\Run-Menu.ps1).

    Run directly with PowerShell (the Raphire/Win11Debloat style):

      irm https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/main/Launcher.ps1

    Or via curl (Windows):

      curl.exe https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/main/Launcher.ps1 -o "%TEMP%\Launcher.ps1"
      powershell -File "%TEMP%\Launcher.ps1"

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
    irm https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/main/Launcher.ps1
#>
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
    # Branch archives extract with a top-level '<repo>-<branch>' folder; release
    # zips are flat - locate the menu recursively and print the real path.
    $menuPath = Get-ChildItem -Path $InstallDir -Recurse -Filter 'Run-Menu.ps1' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($menuPath) {
        Write-Host "Suite extracted to $InstallDir. Launch with: & '$($menuPath.FullName)'" -ForegroundColor Gray
    } else {
        Write-Host "Suite extracted to $InstallDir, but Run-Menu.ps1 was not found - check the archive layout." -ForegroundColor Yellow
    }
    exit 0
}
