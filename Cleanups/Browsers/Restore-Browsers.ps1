#requires -Version 5.1
<#
.SYNOPSIS
    Restores the browser policy values backed up by Disable-Browsers.ps1.

.PARAMETER WhatIf
    Preview mode - shows what would be restored without touching the system.

.EXAMPLE
    & '.\Restore-Browsers.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$backupRoot = Get-SuiteBackupRoot -CleanupName 'Browsers'

Restore-SuiteRegistryRecords -BackupRoot $backupRoot -Preview:$WhatIfPreference

Write-Host 'Done.'
