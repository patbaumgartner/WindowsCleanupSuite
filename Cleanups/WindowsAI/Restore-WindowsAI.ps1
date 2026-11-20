#requires -Version 5.1
<#
.SYNOPSIS
    Restores WindowsAI settings (Copilot/AI policies) backed up by Disable-WindowsAI.ps1.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\WindowsAI\Restore-WindowsAI.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$backupRoot = Get-SuiteBackupRoot -CleanupName 'WindowsAI'

foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'Registry' })) {
    if (-not $record.RegistryKey -or -not $record.Name) { Write-Warning "Malformed backup record"; continue }
    if (-not (Test-Path $record.RegistryKey)) { Write-Warning "  Restore: path not found: $($record.RegistryKey)"; continue }
    if (-not $PSCmdlet.ShouldProcess($record.RegistryKey, "Restore $($record.Name)")) { Write-Host "  Would restore: $($record.RegistryKey)\$($record.Name)"; continue }
    try {
        if ($null -ne $record.PreviousValue) {
            Set-ItemProperty -Path $record.RegistryKey -Name $record.Name -Value $record.PreviousValue -Type DWord -ErrorAction Stop
        } else {
            Remove-ItemProperty -Path $record.RegistryKey -Name $record.Name -ErrorAction SilentlyContinue
        }
        Write-Host "  Restored: $($record.RegistryKey)\$($record.Name)"
    } catch {
        Write-Warning "  Failed: $($_.Exception.Message)"
    }
}

Write-Host "Done."
