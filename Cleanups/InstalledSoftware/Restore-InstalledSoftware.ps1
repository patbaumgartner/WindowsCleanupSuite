#requires -Version 5.1
<#
.SYNOPSIS
    Restores Win32 apps removed by Disable-InstalledSoftware.ps1.

.DESCRIPTION
    Reads the backup records (JSON) from WindowsCleanupSuite\Backups\InstalledSoftware
    and re-adds the Uninstall registry key values.

    Note: UWP apps removed via Remove-AppxPackage cannot be automatically
    re-installed - reinstall from the Microsoft Store (and re-run Windows
    Update for updates) if needed.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\InstalledSoftware\Restore-InstalledSoftware.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$backupRoot = Get-SuiteBackupRoot -CleanupName 'InstalledSoftware'

Write-Host 'Restoring removed Win32 apps'
foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'Win32' })) {
    if (-not $record.RegKeyPath -or -not $record.Values) { Write-Warning "Malformed backup record: $($record.Name)"; continue }
    if (-not (Test-Path $record.RegKeyPath)) { Write-Warning "  Restore: path not found: $($record.RegKeyPath)"; continue }
    if (-not $PSCmdlet.ShouldProcess($record.Name, 'Restore Win32 app registry entry')) { Write-Host "  Would restore Win32 app: $($record.Name)"; continue }
    try {
        foreach ($value in $record.Values) {
            Set-ItemProperty -Path $record.RegKeyPath -Name $value.Name -Value $value.Value -ErrorAction Stop
        }
        Write-Host "  Restored Win32 app: $($record.Name)"
    } catch {
        Write-Warning "  Failed to restore $($record.Name): $($_.Exception.Message)"
    }
}

Write-Host ''
Write-Host 'Note: UWP apps (Microsoft.*, Samsung, Dell, Social, Streaming) were removed via Remove-AppxPackage.'
Write-Host 'To get them back, reinstall from the Microsoft Store (and re-run Windows Update for updates).'
