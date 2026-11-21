#requires -Version 5.1
<#
.SYNOPSIS
    Disables browser background modes and startup boost (Edge/Chrome/Firefox),
    data-driven from Manifest.psd1.

.DESCRIPTION
    Sets HKLM policy values (all users); each value is backed up to
    Backups\Browsers\ first. Requires Administrator. Restore with
    Restore-Browsers.ps1. Entries flagged Risky only apply with -AllowRisky.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.PARAMETER AllowRisky
    Also apply entries flagged Risky = $true in the manifest.

.EXAMPLE
    & '.\Disable-Browsers.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$AllowRisky
)

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest   = Get-SuiteManifest -CleanupName 'Browsers'
$backupRoot = Get-SuiteBackupRoot -CleanupName 'Browsers'

if (-not (Test-SuiteIsAdmin) -and -not $WhatIfPreference) {
    Write-Warning 'Browsers: HKLM policy changes require Administrator; nothing was applied.'
    return
}

foreach ($entry in @($manifest.Entries)) {
    Invoke-SuiteRegistryEntry -Entry $entry -Manifest $manifest -BackupRoot $backupRoot -Preview:$WhatIfPreference -AllowRisky:$AllowRisky
}

Write-Host ''
Write-Host "Done. Backups are in $backupRoot"
