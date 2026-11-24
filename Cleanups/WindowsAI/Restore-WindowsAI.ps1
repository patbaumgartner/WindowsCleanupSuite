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
    if (-not $PSCmdlet.ShouldProcess($record.RegistryKey, "Restore $($record.Name)")) { Write-Host "  Would restore: $($record.RegistryKey)\$($record.Name)"; continue }
    try {
        if (-not (Test-Path $record.RegistryKey)) { New-Item -Path $record.RegistryKey -Force | Out-Null }
        if ($record.HadPrevious -and $null -ne $record.PreviousValue) {
            # Prefer the OLD value's recorded kind; ValueType is the NEW kind (fallback only).
            $type = 'DWord'
            if ($record.PSObject.Properties.Name -contains 'PreviousType' -and $record.PreviousType) { $type = [string]$record.PreviousType }
            elseif ($record.ValueType) { $type = [string]$record.ValueType }
            Set-ItemProperty -Path $record.RegistryKey -Name $record.Name -Value $record.PreviousValue -Type $type -ErrorAction Stop
        } else {
            Remove-ItemProperty -Path $record.RegistryKey -Name $record.Name -ErrorAction SilentlyContinue
        }
        Write-Host "  Restored: $($record.RegistryKey)\$($record.Name)"
    } catch {
        Write-Error "  Restore failed: $($record.RegistryKey)\$($record.Name) - $($_.Exception.Message)"
    }
}
