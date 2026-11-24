#requires -Version 5.1
<#
.SYNOPSIS
    Restores startup registry entries previously disabled by Disable-StartupBloat.ps1.

.DESCRIPTION
    Reads the backup records (JSON) from <SuiteRoot>\Backups\StartupBloat and writes
    each value back to the correct registry key. HKLM restorations are skipped with
    a warning when not elevated.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\StartupBloat\Restore-StartupBloat.ps1' -WhatIf
    & 'WindowsCleanupSuite\Cleanups\StartupBloat\Restore-StartupBloat.ps1'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$backupRoot = Get-SuiteBackupRoot -CleanupName 'StartupBloat'
$isAdmin    = Test-SuiteIsAdmin

foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot)) {
    if (-not $record.Path -or -not $record.Name) {
        Write-Warning "Skipping malformed backup record in $backupRoot."
        continue
    }

    if ($record.Hive -eq 'HKLM' -and -not $isAdmin) {
        Write-Host "  Skipped [HKLM] $($record.Name) (requires elevation)"
        continue
    }

    if (-not (Test-Path $record.Path)) {
        Write-Warning "  Skipping: registry path not found: $($record.Path)"
        continue
    }

    if (-not $PSCmdlet.ShouldProcess($record.Name, "Restore Run entry [$($record.Hive)]")) {
        Write-Host "  Would restore [$($record.Hive)] $($record.Name)"
        continue
    }

    try {
        if (-not (Test-Path $record.Path)) { New-Item -Path $record.Path -Force | Out-Null }
        Set-ItemProperty -Path $record.Path -Name $record.Name -Value $record.Value -ErrorAction Stop
        Write-Host "  Restored [$($record.Hive)] $($record.Name)"
    } catch {
        Write-Error "  Failed to restore '$($record.Name)': $($_.Exception.Message)"
    }
}

Write-Host "Done."
