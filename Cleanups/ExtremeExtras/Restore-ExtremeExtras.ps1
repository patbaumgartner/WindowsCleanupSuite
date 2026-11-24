#requires -Version 5.1
<#
.SYNOPSIS
    Restores services previously disabled by Disable-ExtremeExtras.ps1.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\ExtremeExtras\Restore-ExtremeExtras.ps1'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$backupRoot   = Get-SuiteBackupRoot -CleanupName 'ExtremeExtras'
$startTypeMap = @{ 2 = 'Automatic'; 3 = 'Manual'; 4 = 'Disabled' }

foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'Service' })) {
    $svc = $null
    try { $svc = Get-Service -Name $record.Name -ErrorAction Stop } catch { $svc = $null }
    if (-not $svc) { Write-Warning "  [ext]     Service '$($record.Name)' not found - skipping"; continue }

    # Older backups store StartType as a STRING - cast before the int-keyed map lookup.
    $st = 0
    if (-not [int]::TryParse([string]$record.StartType, [ref]$st) -or -not $startTypeMap.ContainsKey($st)) {
        Write-Warning "  [ext]     Unknown start type '$($record.StartType)' - skipping"
        continue
    }
    $startType = $startTypeMap[$st]

    if (-not $PSCmdlet.ShouldProcess($record.Name, "Restore start type to $startType")) {
        Write-Host "  [ext]     Would restore: $($record.Name) -> $startType"
        continue
    }
    try {
        Set-Service -Name $record.Name -StartupType $startType -ErrorAction Stop
        Write-Host "  [ext]     Restored: $($record.Name) -> $startType"
    } catch {
        Write-Error "  [ext]     Failed to restore $($record.Name): $($_.Exception.Message)"
    }
}

Write-Host 'Done.'
