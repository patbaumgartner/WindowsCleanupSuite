#requires -Version 5.1
<#
.SYNOPSIS
    Restores OneDrive settings previously changed by Disable-OneDrive.ps1.

.DESCRIPTION
    - Run entries (Type='RunEntry'): re-adds the OneDrive Run entry.
    - Startup flags (Type='StartupApprovedFlag'): restores/removes the original flag.
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
        Write-Error "  [od]      Failed to re-add Run entry $($record.Name): $($_.Exception.Message)"
    }
}

foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'StartupApprovedFlag' })) {
    if (-not $PSCmdlet.ShouldProcess($record.Name, 'Restore StartupApproved flag')) {
        Write-Host "  [od]      Would restore startup flag: $($record.Name)"
        continue
    }
    try {
        if (-not (Test-Path $record.Path)) { New-Item -Path $record.Path -Force | Out-Null }
        if ($record.PSObject.Properties.Name -contains 'Existed' -and -not [bool]$record.Existed) {
            Remove-ItemProperty -Path $record.Path -Name $record.Name -ErrorAction SilentlyContinue
        } elseif ($record.ValueBase64) {
            Set-ItemProperty -Path $record.Path -Name $record.Name -Value ([Convert]::FromBase64String($record.ValueBase64)) -Type Binary -ErrorAction Stop
        } else {
            Remove-ItemProperty -Path $record.Path -Name $record.Name -ErrorAction SilentlyContinue
        }
        Write-Host "  [od]      Restored startup flag: $($record.Name)"
    } catch {
        Write-Error "  [od]      Failed to restore startup flag $($record.Name): $($_.Exception.Message)"
    }
}

foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'Service' })) {
    $svc = $null
    try { $svc = Get-Service -Name $record.Name -ErrorAction Stop } catch { $svc = $null }
    if (-not $svc) { Write-Warning "  [od]      Service '$($record.Name)' not found - skipping"; continue }

    # Older backups store StartType as a STRING - cast before the int-keyed map lookup.
    $st = 0
    if (-not [int]::TryParse([string]$record.StartType, [ref]$st) -or -not $startTypeMap.ContainsKey($st)) {
        Write-Warning "  [od]      Unknown start type '$($record.StartType)' - skipping"
        continue
    }
    $startType = $startTypeMap[$st]

    if (-not $PSCmdlet.ShouldProcess($record.Name, "Restore start type to $startType")) {
        Write-Host "  [od]      Would restore: $($record.Name) -> $startType"
        continue
    }
    try {
        Set-Service -Name $record.Name -StartupType $startType -ErrorAction Stop
        Write-Host "  [od]      Restored: $($record.Name) -> $startType"
    } catch {
        Write-Error "  [od]      Failed to restore $($record.Name): $($_.Exception.Message)"
    }
}

Write-Host 'Done.'
