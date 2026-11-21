#requires -Version 5.1
<#
.SYNOPSIS
    Fully disables extreme level-4 services (push notifications, Store broker, etc.).

.DESCRIPTION
    Data-driven from Cleanups\ExtremeExtras\ExtremeExtras.psd1:
      - Services: sets the named service to Disabled (backup of the original
        start type recorded first).

.PARAMETER Level
    Selected level (default 4). Entries with a higher Level are skipped.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\ExtremeExtras\Disable-ExtremeExtras.ps1'
    & 'WindowsCleanupSuite\Cleanups\ExtremeExtras\Disable-ExtremeExtras.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateRange(1, 4)]
    [int]$Level = 4
)

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest   = Get-SuiteManifest -CleanupName 'ExtremeExtras'
$backupRoot = Get-SuiteBackupRoot -CleanupName 'ExtremeExtras'
$isAdmin    = Test-SuiteIsAdmin

foreach ($entry in @($manifest.Services)) {
    if ($entry.Level -gt $Level) {
        Write-Host "  [ext]     Skipped (requires level $($entry.Level)): $($entry.Name)"
        continue
    }
    if (-not $isAdmin -and -not $WhatIfPreference) {
        Write-Warning "  [ext]     Skipped (requires Administrator): $($entry.Name)"
        continue
    }

    $obj = Get-Service -Name $entry.Name -ErrorAction SilentlyContinue
    if (-not $obj) {
        Write-Host "  [ext]     No match: $($entry.Name) - $($entry.Reason)"
        continue
    }

    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($entry.Name)"
    $start = $null
    try { $start = (Get-ItemProperty -Path $regPath -Name 'Start' -ErrorAction Stop).Start } catch { $start = $null }

    if ($null -ne $start -and [int]$start -eq 4) {
        Write-Host "  [ext]     Already Disabled: $($entry.Name)"
        continue
    }

    if (-not $PSCmdlet.ShouldProcess($entry.Name, "Set start type to Disabled - $($entry.Reason)")) {
        Write-Host "  [ext]     Would disable: $($entry.Name)"
        continue
    }

    New-SuiteBackupFile -BackupRoot $backupRoot -FileName "svc_$($entry.Name).txt" -Record @{
        Type = 'Service'; Name = $entry.Name; StartType = [int]$start; Reason = $entry.Reason
    }

    try {
        Set-Service -Name $entry.Name -StartupType 'Disabled' -ErrorAction Stop
        Write-Host "  [ext]     Disabled: $($entry.Name)"
    } catch {
        try {
            Set-ItemProperty -Path $regPath -Name 'Start' -Value 4 -Type DWord -ErrorAction Stop
            Write-Host "  [ext]     Disabled (registry): $($entry.Name)"
        } catch {
            Write-Warning "  [ext]     Failed: $($entry.Name) - $($_.Exception.Message)"
        }
    }
}
