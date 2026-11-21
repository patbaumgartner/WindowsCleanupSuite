#requires -Version 5.1
<#
.SYNOPSIS
    Disables Windows telemetry and personalization/advertising privacy settings.

.DESCRIPTION
    Data-driven from Cleanups\PrivacySettings\PrivacySettings.psd1: sets HKCU/HKLM
    privacy values. Each change is backed up (JSON record in Backups\PrivacySettings)
    so Restore-PrivacySettings.ps1 can restore the previous state.

    Level gating (the menu maps menu levels 1-4 to these):
      - Level 1: advertising ID, Tailored experiences, speech consent, TipPC,
                 implicit ink/text collection, contact harvesting, privacy policy.
      - Level 2: app launch tracking, AllowTelemetry, PublishUserActivities.
      - Level 3: content delivery manager (Spotlight, suggested apps in Settings/Start).
      - Level 4: telemetry off (except on Windows 11, where AllowTelemetry=1 minimum).

.PARAMETER Level
    Minimum level (1-4, default 1) to apply entries for.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\PrivacySettings\Disable-PrivacySettings.ps1' -Level 4
    & 'WindowsCleanupSuite\Cleanups\PrivacySettings\Disable-PrivacySettings.ps1' -WhatIf -Level 2
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateRange(1, 4)]
    [int]$Level = 1
)

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest   = Get-SuiteManifest -CleanupName 'PrivacySettings'
$backupRoot = Get-SuiteBackupRoot -CleanupName 'PrivacySettings'

function Test-IsWindows11 {
    $p = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
    if (-not $p) { return $false }
    return ([regex]::IsMatch([string]$p.ProductName, '\b11\b'))
}

foreach ($entry in @($manifest.Entries)) {
    if ($entry.Level -gt $Level) { continue }

    # Windows 11 has a hard floor of telemetry level 1; never go below it.
    if ($entry.Level -eq 4 -and $entry.Name -eq 'AllowTelemetry' -and (Test-IsWindows11)) {
        $entry.Value = 1
    }

    Set-WCSRegistryEntry -Entry $entry -BackupRoot $backupRoot
}
