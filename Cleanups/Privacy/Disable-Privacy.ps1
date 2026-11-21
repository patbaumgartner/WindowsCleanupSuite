#requires -Version 5.1
<#
.SYNOPSIS
    Disables Windows telemetry, advertising ID, activity history, CEIP,
    consumer/cloud content and suggested apps (data-driven from Manifest.psd1).

.DESCRIPTION
    Every registry value is backed up to Backups\Privacy\ before it is changed;
    restore with Restore-Privacy.ps1. HKLM entries require Administrator.
    Entries flagged Risky in the manifest only apply with -AllowRisky.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.PARAMETER AllowRisky
    Also apply entries flagged Risky = $true in the manifest.

.EXAMPLE
    & '.\Disable-Privacy.ps1' -WhatIf
    & '.\Disable-Privacy.ps1' -AllowRisky
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$AllowRisky
)

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest   = Get-SuiteManifest -CleanupName 'Privacy'
$backupRoot = Get-SuiteBackupRoot -CleanupName 'Privacy'

foreach ($entry in @($manifest.Entries)) {
    Invoke-SuiteRegistryEntry -Entry $entry -Manifest $manifest -BackupRoot $backupRoot -Preview:$WhatIfPreference -AllowRisky:$AllowRisky
}

Write-Host ''
Write-Host "Done. Backups are in $backupRoot"
