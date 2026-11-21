#requires -Version 5.1
<#
.SYNOPSIS
    Restores the privacy/telemetry registry values backed up by Disable-Privacy.ps1.

.PARAMETER WhatIf
    Preview mode - shows what would be restored without touching the system.

.EXAMPLE
    & '.\Restore-Privacy.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$backupRoot = Get-SuiteBackupRoot -CleanupName 'Privacy'

Restore-SuiteRegistryRecords -BackupRoot $backupRoot -Preview:$WhatIfPreference

Write-Host 'Done.'
