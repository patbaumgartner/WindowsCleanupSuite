#requires -Version 5.1
<#
.SYNOPSIS
    Restores OneDrive settings previously changed by Disable-OneDrive.ps1.

.DESCRIPTION
    - Run entries (Type='RunEntry'): re-adds the OneDrive Run entry.
    - Services (Type='Service'): restores the original startup type.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\OneDrive\Restore-OneDrive.ps1'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$backupRoot = Get-SuiteBackupRoot -CleanupName 'OneDrive'
$startTypeMap = @{ 2 = 'Automatic'; 3 = 'Manual'; 4 = 'Disabled' }

foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'RunEntry' })) {
    if (-not $PSCmdlet.ShouldProcess($record.Name, 'Re-add Run entry')) {
        Write-Host "  [od]      Would re-add Run entry: $($record.Name)"
        continue
    }
    try {
        Set-ItemProperty -Path $record.Path -Name $record.Name -Value $record.Value -ErrorAction Stop
        Write-Host "  [od]      Restored Run entry: $($record.Name)"
    } catch {
        Write-Warning "  [od]      Failed to re-add Run entry $($record.Name): $($_.Exception.Message)"
    }
}

foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'Service' })) {
    $svc = Get-Service -Name $record.Name -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Warning "  [od]      Service '$($record.Name)' not found - skipping"; continue }

    $startType = $startTypeMap[$record.StartType]
    if (-not $startType) { Write-Warning "  [od]      Unknown start type '$($record.StartType)' - skipping"; continue }

    if (-not $PSCmdlet.ShouldProcess($record.Name, "Restore start type to $startType")) {
        Write-Host "  [od]      Would restore: $($record.Name) -> $startType"
        continue
    }
    try {
        Set-Service -Name $record.Name -StartupType $startType -ErrorAction Stop
        Write-Host "  [od]      Restored: $($record.Name) -> $startType"
    } catch {
        Write-Warning "  [od]      Failed to restore $($record.Name): $($_.Exception.Message)"
    }
}

Write-Host 'Done.'
