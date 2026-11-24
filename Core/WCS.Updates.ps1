<#
.SYNOPSIS
    Update integration: runs Chocolatey or Winget package updates, then re-runs the
    debloat suite so re-installed bloatware gets removed again.

.DESCRIPTION
    Features:
      - Detects available update managers (winget.exe / choco.exe / none).
      - Runs "winget upgrade --all" or "choco upgrade all" silently with logs.
      - Optional: upgrade specific packages only with -PackageIds (e.g. winget -Force support)
        or include unknown versions with -IncludeUnknown (the default for winget).
      - Re-debloats afterwards via Runners\Run-Menu.ps1 -NonInteractive -Apply (removes
        apps that updates reinstalled, e.g. wifi kill apps, and repairs update-side bloat).
    All commands are logged to Logs\updates-*.log with timestamps.
#>

. (Join-Path $PSScriptRoot 'CleanupEngine.ps1')

function Get-WCSActiveUpdateManager {
    <# Returns 'winget', 'choco', or $null when neither is available. #>
    if (Get-Command winget -ErrorAction SilentlyContinue) { return 'winget' }
    if (Get-Command choco -ErrorAction SilentlyContinue) { return 'choco' }
    return $null
}

function Invoke-WCSUpdateManager {
    <#
        Runs the detected update manager (applies updates immediately).
        -PackageIds upgrades only the given IDs (winget: --id <Id> --force with -Force).
        Returns hashtable: @{ Manager; Success; ExitCode; Output }
    #>
    param(
        [string[]]$PackageIds = @(),
        [switch]$Force,
        [switch]$IncludeUnknown
    )

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
        'winget' {
            $base = @('upgrade', '--silent', '--accept-source-agreements', '--accept-package-agreements')
            if ($PackageIds -and $PackageIds.Count) {
                $all = @()
                foreach ($id in $PackageIds) { $all += @('--id', $id) }
                if ($Force) { $all += '--force' }
                $base + $all
            } else {
                $cmds = $base + @('--all')
                if ($IncludeUnknown) { $cmds += '--include-unknown' }
                $cmds
            }
        }
        'choco'  {
            if ($PackageIds -and $PackageIds.Count) { @('upgrade') + $PackageIds + '-y' }
            else { @('upgrade', 'all', '-y') }
        }
        default { @('upgrade', '--all') }
    }
    Write-Host "  Command: $manager $($cmd -join ' ')" -ForegroundColor Gray

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
    <# Re-runs the menu non-interactively at the given level (removes apps re-installed by updates).
       Topics/AllowRisky are forwarded so the re-debloat matches the user's selection
       instead of silently applying every level-default topic. #>
    param(
        [ValidateSet('Safe', 'Balanced', 'Aggressive', 'Extreme')][string]$Level = 'Extreme',
        [string[]]$Topics = @(),
        [switch]$AllowRisky,
        [switch]$Apply
    )

    $menu = Join-Path (Split-Path -Parent $PSScriptRoot) 'Runners\Run-Menu.ps1'
    if (-not (Test-Path $menu)) { Write-Error "Run-Menu.ps1 not found at $menu"; return }
    # HASHTABLE splatting: array splatting ('-Topics', $csv) after named parameters
    # mis-binds positionally (the CSV lands on MaxParallel and throws). Named keys
    # always bind to the right parameter.
    $menuArgs = @{ NonInteractive = $true; Level = $Level }
    if ($Topics -and $Topics.Count) { $menuArgs['Topics'] = ($Topics -join ',') }
    if ($AllowRisky) { $menuArgs['AllowRisky'] = $true }
    Write-Host ''
    Write-Host "Re-debloating after updates (level: $Level)..." -ForegroundColor Cyan
    if ($Apply) {
        if (-not (Test-SuiteIsAdmin)) {
            Write-Warning 'Re-debloating after updates needs Administrator; running preview.'
            & $menu @menuArgs
        } else {
            $menuArgs['Apply'] = $true
            $menuArgs['AutoApprove'] = $true
            & $menu @menuArgs
        }
    } else {
        & $menu @menuArgs
    }
}
