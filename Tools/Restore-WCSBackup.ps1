#requires -Version 5.1
<#
.SYNOPSIS
    Restores changes made by the WindowsCleanupSuite, from JSON backups and/or a
    Windows System Restore point.

.DESCRIPTION
    -Backups (default):
      - Runs every cleanup's Restore-*.ps1 script (services, tasks, Run entries,
        startup apps, PowerPlan, DNS, InstalledSoftware, WindowsAI, PrivacySettings,
        WindowsUpdates, OneDrive, ExtremeExtras).
      - Restores generic Type='Registry' records found in Backups\**\*.json.
    -RestorePoint N (or -Latest):
      - Restores the System Restore point with sequence number N via Restore-Computer.
        Note: this triggers an automatic reboot after restoring.

.PARAMETER Backups
    Restore all backups (runs restore scripts + generic registry records).

.PARAMETER RestorePoint
    Restore the System Restore point with this sequence number.

.PARAMETER Latest
    With -RestorePoint: restore the newest System Restore point.

.PARAMETER WhatIf
    Preview mode - shows what would be restored without touching the system.

.EXAMPLE
    & 'Tools\Restore-WCSBackup.ps1'                        # restore all backups
    & 'Tools\Restore-WCSBackup.ps1' -RestorePoint -Latest  # restore most recent point
    & 'Tools\Restore-WCSBackup.ps1' -RestorePoint 3 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Backups')]
param(
    [Parameter(ParameterSetName = 'Backups')][switch]$Backups,

    [Parameter(ParameterSetName = 'RestorePoint')][int]$RestorePoint,
    [Parameter(ParameterSetName = 'RestorePoint')][switch]$Latest,

    [switch]$WhatIf
)

. (Join-Path $PWD 'Core\CleanupEngine.ps1')

$SuiteRoot = Get-SuiteRoot
$global:WCS_RestoreFailed = $false

# --- Generic registry restore (records written by Set-WCSRegistryEntry) -----------

function Restore-WCSCustomRegistryRecords {
    $root = Join-Path $SuiteRoot 'Backups'
    if (-not (Test-Path $root)) { return }

    foreach ($file in @(Get-ChildItem -Path $root -Recurse -File -Include '*.json' -ErrorAction SilentlyContinue)) {
        $content = $null
        try { $content = Get-Content -Raw -Path $file.FullName -ErrorAction Stop } catch { $content = $null }
        if ([string]::IsNullOrWhiteSpace($content)) { continue }
        try { $records = @((ConvertFrom-Json $content)) } catch { continue }

        foreach ($record in @($records | Where-Object { $_.Type -eq 'Registry' -and $_.Path -and $_.Name })) {
            $names = @()
            if (Test-Path $record.Path) { $names = @((Get-Item -Path $record.Path -ErrorAction SilentlyContinue).Property) }
            $targetExists = ($names -contains $record.Name)

            if (-not $PSCmdlet.ShouldProcess("$($record.Path)\$($record.Name)", 'Restore registry backup')) {
                Write-Host "  [reg]     Would restore: $($record.Path)\$($record.Name)"
                continue
            }

            try {
                if ($record.OldExists) {
                    Restore-WCSRegistryRecordValue -Record $record -ErrorAction Stop
                    Write-Host "  [reg]     Restored: $($record.Path)\$($record.Name) = $($record.OldValue)"
                } elseif ($targetExists) {
                    Remove-ItemProperty -Path $record.Path -Name $record.Name -ErrorAction Stop
                    Write-Host "  [reg]     Removed (did not exist before): $($record.Path)\$($record.Name)"
                } else {
                    Write-Host "  [reg]     Skipped (already absent): $($record.Path)\$($record.Name)"
                }
            } catch {
                Write-Warning "  [reg]     Failed: $($record.Path)\$($record.Name) - $($_.Exception.Message)"
            }
        }
    }
}

function Invoke-WCSToolRestore {
    param([string]$Tool)

    $path = Join-Path $SuiteRoot $Tool
    if (-not (Test-Path $path)) { Write-Warning "  Missing: $Tool - skipping"; return }

    Write-Host "--- $Tool ---"
    & $path -ErrorAction SilentlyContinue | Out-Null
    $exit = $LASTEXITCODE
    if ($exit -and $exit -ne 0) { $global:WCS_RestoreFailed = $true }
}

# --- Backups mode -------------------------------------------------------------------

if ($Backups) {
    Write-Host 'Restoring backups...'
    Restore-WCSCustomRegistryRecords

    foreach ($tool in @(
        'Cleanups\StartupBloat\Restore-StartupBloat.ps1',
        'Cleanups\WindowsSpeedup\Restore-ServicesAndTasks.ps1',
        'Cleanups\InstalledSoftware\Restore-InstalledSoftware.ps1',
        'Cleanups\WindowsAI\Restore-WindowsAI.ps1',
        'Cleanups\TempAndJunkFiles\Restore-TempAndJunkFiles.ps1',
        'Cleanups\PowerPlan\Restore-PowerPlan.ps1',
        'Cleanups\DNSReset\Restore-DNSReset.ps1',
        'Cleanups\Privacy\Restore-Privacy.ps1',
        'Cleanups\Browsers\Restore-Browsers.ps1',
        'Cleanups\Network\Restore-Network.ps1',
        'Cleanups\PrivacySettings\Restore-PrivacySettings.ps1',
        'Cleanups\WindowsUpdates\Restore-WindowsUpdates.ps1',
        'Cleanups\OneDrive\Restore-OneDrive.ps1',
        'Cleanups\ExtremeExtras\Restore-ExtremeExtras.ps1'
    )) {
        Invoke-WCSToolRestore -Tool $tool
    }

    Write-Host ''
    Write-Host 'Restore complete.' -ForegroundColor Green
    exit 0
}

# --- RestorePoint mode ---------------------------------------------------------------

if ($Latest) {
    $points = @(Get-ComputerRestorePoint | Where-Object { $_.SequenceNumber })
    if (-not $points.Count) { Write-Error 'No System Restore points found.'; exit 1 }
    $points = @($points | Sort-Object SequenceNumber)
    $RestorePoint = $points[-1].SequenceNumber
    Write-Host "Restoring newest point: #$RestorePoint"
}

if ($null -ne $RestorePoint) {
    if (-not (Test-SuiteIsAdmin)) {
        Write-Error 'Restoring a System Restore point requires Administrator privileges.'
        exit 1
    }

    $points = @(Get-ComputerRestorePoint | Where-Object { $_.SequenceNumber -eq $RestorePoint })
    if (-not $points.Count) { Write-Error "System Restore point #$RestorePoint not found."; exit 1 }

    if (-not $WhatIf) {
        $confirm = Read-Host "Restore point #$RestorePoint ($($points[0].Description))? This triggers a reboot after restoring. Type YES"
        if ($confirm -ne 'YES') { Write-Host 'Canceled.'; exit 0 }
    }

    if ($PSCmdlet.ShouldProcess("SequenceNumber $RestorePoint", 'Restore-Computer')) {
        Restore-Computer -SequenceNumber $RestorePoint -ErrorAction Stop -WhatIf:$WhatIf
        Write-Host "Restore initiated for point #$RestorePoint."
    }
    exit 0
}

Write-Error 'No action specified. Use -Backups or -RestorePoint N [-Latest].'
exit 1
