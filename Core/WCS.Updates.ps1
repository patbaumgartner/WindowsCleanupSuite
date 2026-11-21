<#
.SYNOPSIS
    Update integration: runs Chocolatey or Winget package updates, then re-runs the
    debloat suite so re-installed bloatware gets removed again.

.DESCRIPTION
    Features:
      - Detects available update managers (winget.exe / choco.exe / none).
      - Runs "winget upgrade --all" or "choco upgrade all" silently with logs.
      - Re-deboates afterwards via Runners\Run-Cleanup.ps1 -Apply (removes apps that
        updates reinstalled, e.g. wifi kill apps, and repairs update-side bloat).
    All commands are logged to Logs\updates-*.log with timestamps.
#>

function Get-WCSActiveUpdateManager {
    <# Returns 'winget', 'choco', or $null when neither is available. #>
    if (Get-Command winget -ErrorAction SilentlyContinue) { return 'winget' }
    if (Get-Command choco -ErrorAction SilentlyContinue) { return 'choco' }
    return $null
}

function Invoke-WCSUpdateManager {
    <#
        Runs the detected update manager (applies updates immediately).
        Returns hashtable: @{ Manager; Success; ExitCode; Output }
    #>
    param()

    $manager = Get-WCSActiveUpdateManager
    $root = Split-Path -Parent $PSScriptRoot
    $logsDir = Join-Path $root 'Logs'
    if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force | Out-Null }
    $logFile = Join-Path $logsDir "$(Get-Date -Format 'yyyyMMdd-HHmmss')-updates.log"

    if (-not $manager) {
        Write-Host 'No update manager found (winget or choco). Install one first, then re-run.' -ForegroundColor Yellow
        return [pscustomobject]@{ Manager = $null; Success = $false; ExitCode = 1; Output = '' }
    }

    Write-Host "Running updates via $manager..." -ForegroundColor Cyan
    $cmd = switch ($manager) {
        'winget' { @('upgrade', '--all', '--silent', '--accept-source-agreements', '--accept-package-agreements', '--include-unknown') }
        'choco'  { @('upgrade', 'all', '-y') }
    }

    $result = [pscustomobject]@{ Manager = $manager; Success = $false; ExitCode = 0; Output = '' }
    try {
        $output = & $manager @cmd 2>&1
        $exit = $LASTEXITCODE
        $result.ExitCode = if ($null -eq $exit) { 0 } else { [int]$exit }
        $result.Success = ($result.ExitCode -eq 0)
        $result.Output = [string]$output
        foreach ($line in ($output -split "`n")) {
            if ($line.Trim()) { Write-Host "  $($line.Trim())" }
        }
    } catch {
        $result.Success = $false
        $result.ExitCode = 1
        $result.Output = "Error: $($_.Exception.Message)"
        Write-Warning "  $($result.Output)"
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logText = "WindowsCleanupSuite updates - $timestamp`nManager: $manager`nCommand: $manager $($cmd -join ' ')`nExit code: $($result.ExitCode)`nSuccess: $($result.Success)`n---`n$($result.Output)"
    Set-Content -Path $logFile -Value $logText -Encoding UTF8
    Write-Host "  Updates finished. Log: $logFile" -ForegroundColor Gray
    return $result
}

function Invoke-WCSDebloatAfterUpdates {
    <# Re-runs Run-Cleanup.ps1 -Apply (removes apps re-installed by updates). #>
    param(
        [ValidateSet('Balanced', 'Maximum')][string]$Profile,
        [switch]$Apply
    )

    $runner = Join-Path (Split-Path -Parent $PSScriptRoot) 'Runners\Run-Cleanup.ps1'
    Write-Host ''
    Write-Host "Re-debloating after updates (profile: $Profile)..." -ForegroundColor Cyan
    if ($Apply) {
        if (-not (Test-SuiteIsAdmin)) {
            Write-Warning 'Re-debloating after updates needs Administrator; running preview.'
            & $runner -Profile $Profile
        } else {
            & $runner -Profile $Profile -Apply
        }
    } else {
        & $runner -Profile $Profile
    }
}
