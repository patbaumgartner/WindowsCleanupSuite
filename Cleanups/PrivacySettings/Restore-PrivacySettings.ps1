#requires -Version 5.1
<#
.SYNOPSIS
    Restores privacy settings previously changed by Disable-PrivacySettings.ps1.

.DESCRIPTION
    Reads backup records (Type='Registry') from Backups\PrivacySettings and
    restores the original values (or removes keys/values that did not exist
    before the change).

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\PrivacySettings\Restore-PrivacySettings.ps1'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$backupRoot = Get-SuiteBackupRoot -CleanupName 'PrivacySettings'

foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'Registry' })) {
    if (-not $PSCmdlet.ShouldProcess("$($record.Path)\$($record.Name)", 'Restore previous privacy value')) {
        Write-Host "  [priv]    Would restore: $($record.Path)\$($record.Name)"
        continue
    }

    $targetExists = $false
    if (Test-Path $record.Path) {
        $names = @((Get-Item -Path $record.Path -ErrorAction SilentlyContinue).Property)
        $targetExists = ($names -contains $record.Name)
    }

    try {
        if ($record.OldExists) {
            Restore-WCSRegistryRecordValue -Record $record -ErrorAction Stop
            Write-Host "  [priv]    Restored: $($record.Path)\$($record.Name) = $($record.OldValue)"
        } elseif ($targetExists) {
            Remove-ItemProperty -Path $record.Path -Name $record.Name -ErrorAction Stop
            Write-Host "  [priv]    Removed (did not exist before): $($record.Path)\$($record.Name)"
        } else {
            Write-Host "  [priv]    Skipped (already absent): $($record.Path)\$($record.Name)"
        }
    } catch {
        Write-Error "  [priv]    Failed to restore $($record.Path)\$($record.Name): $($_.Exception.Message)"
    }
}

Write-Host 'Done.'
