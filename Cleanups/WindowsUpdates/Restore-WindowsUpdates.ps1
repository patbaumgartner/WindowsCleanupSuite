#requires -Version 5.1
<#
.SYNOPSIS
    Restores Windows Update settings previously changed by Disable-WindowsUpdates.ps1.

.DESCRIPTION
    - Services: restores the original startup type from backups (Type='Service').
    - Registry entries: restores old values or removes them (Type='Registry').

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\WindowsUpdates\Restore-WindowsUpdates.ps1'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$backupRoot = Get-SuiteBackupRoot -CleanupName 'WindowsUpdates'

$startTypeMap = @{ 2 = 'Automatic'; 3 = 'Manual'; 4 = 'Disabled' }

# --- Services -----------------------------------------------------------------
foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'Service' })) {
    $svc = $null
    try { $svc = Get-Service -Name $record.Name -ErrorAction Stop } catch { $svc = $null }
    if (-not $svc) { Write-Warning "  [svc]     Service '$($record.Name)' not found - skipping"; continue }

    # Older backups store StartType as a STRING - cast before the int-keyed map lookup.
    $st = 0
    if (-not [int]::TryParse([string]$record.StartType, [ref]$st) -or -not $startTypeMap.ContainsKey($st)) {
        Write-Warning "  [svc]     Unknown start type '$($record.StartType)' for $($record.Name) - skipping"
        continue
    }
    $startType = $startTypeMap[$st]

    if (-not $PSCmdlet.ShouldProcess($record.Name, "Restore start type to $startType")) {
        Write-Host "  [svc]     Would restore: $($record.Name) -> $startType"
        continue
    }

    try {
        Set-Service -Name $record.Name -StartupType $startType -ErrorAction Stop
        Write-Host "  [svc]     Restored: $($record.Name) -> $startType"
    } catch {
        Write-Error "  [svc]     Failed to restore $($record.Name): $($_.Exception.Message)"
    }
}

# --- Registry entries ------------------------------------------------------------
foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'Registry' })) {
    $targetExists = $false
    if (Test-Path $record.Path) {
        $names = @((Get-Item -Path $record.Path -ErrorAction SilentlyContinue).Property)
        $targetExists = ($names -contains $record.Name)
    }

    if (-not $PSCmdlet.ShouldProcess("$($record.Path)\$($record.Name)", 'Restore previous value')) {
        Write-Host "  [winupdate] Would restore: $($record.Path)\$($record.Name)"
        continue
    }

    try {
        if ($record.OldExists) {
            # Engine helper restores with the ORIGINAL value kind (OldType, base64 for
            # Binary) - a bare Set-ItemProperty would lose the type.
            Restore-WCSRegistryRecordValue -Record $record -ErrorAction Stop
            Write-Host "  [winupdate] Restored: $($record.Path)\$($record.Name) = $($record.OldValue)"
        } elseif ($targetExists) {
            Remove-ItemProperty -Path $record.Path -Name $record.Name -ErrorAction Stop
            Write-Host "  [winupdate] Removed (did not exist before): $($record.Path)\$($record.Name)"
        } else {
            Write-Host "  [winupdate] Skipped (already absent): $($record.Path)\$($record.Name)"
        }
    } catch {
        Write-Error "  [winupdate] Failed: $($record.Path)\$($record.Name) - $($_.Exception.Message)"
    }
}

Write-Host 'Done.'
