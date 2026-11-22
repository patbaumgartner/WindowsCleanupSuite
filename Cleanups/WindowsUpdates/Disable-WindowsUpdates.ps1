#requires -Version 5.1
<#
.SYNOPSIS
    Adjusts Windows Update settings for speed/privacy.

.DESCRIPTION
    Data-driven from Cleanups\WindowsUpdates\WindowsUpdates.psd1:
      - Services: sets the named service to a startup type (Automatic/Manual/Disabled).
      - RegistryEntries: sets registry values; the original state is backed up.

    Changes are reversible via Restore-WindowsUpdates.ps1.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.PARAMETER Level
    Menu level (1-4). Registry entries with a higher Level than this are skipped
    (default 4 = apply everything).

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\WindowsUpdates\Disable-WindowsUpdates.ps1'
    & 'WindowsCleanupSuite\Cleanups\WindowsUpdates\Disable-WindowsUpdates.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateRange(1, 4)]
    [int]$Level = 4
)

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest   = Get-SuiteManifest -CleanupName 'WindowsUpdates'
$backupRoot = Get-SuiteBackupRoot -CleanupName 'WindowsUpdates'
$isAdmin    = Test-SuiteIsAdmin

# start-type constants as used by Get-Service / Set-Service
$targetMap   = @{ Automatic = 2; Manual = 3; Disabled = 4 }

# --- Services -----------------------------------------------------------------
foreach ($entry in @($manifest.Services)) {
    if (-not $isAdmin -and -not $WhatIfPreference) {
        Write-Warning "  [svc]     Skipped (requires Administrator): $($entry.Name)"
        continue
    }

    $obj = Get-Service -Name $entry.Name -ErrorAction SilentlyContinue
    if (-not $obj) {
        Write-Host "  [svc]     No match: $($entry.Name) - $($entry.Reason)"
        continue
    }

    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($entry.Name)"
    $start = $null
    try { $start = (Get-ItemProperty -Path $regPath -Name 'Start' -ErrorAction Stop).Start } catch { $start = $null }

    $target = $entry.Action
    if (-not $target) { $target = $entry.Mode }
    if (-not $targetMap.ContainsKey($target)) { $target = 'Manual' }

    if ($null -ne $start -and [int]$start -eq [int]$targetMap[$target]) {
        Write-Host "  [svc]     Already $($target): $($entry.Name)"
        continue
    }

    if (-not $PSCmdlet.ShouldProcess($entry.Name, "Set start type to $target ($($entry.Reason))")) {
        Write-Host "  [svc]     Would set: $($entry.Name) -> $target"
        continue
    }

    New-SuiteBackupFile -BackupRoot $backupRoot -FileName "svc_$($entry.Name).txt" -Record @{
        Type = 'Service'; Name = $entry.Name; StartType = [int]$start; Reason = $entry.Reason
    }

    try {
        Set-Service -Name $entry.Name -StartupType $target -ErrorAction Stop
        Write-Host "  [svc]     Set: $($entry.Name) -> $target"
    } catch {
        try {
            Set-ItemProperty -Path $regPath -Name 'Start' -Value $targetMap[$target] -Type DWord -ErrorAction Stop
            Write-Host "  [svc]     Set (registry): $($entry.Name) -> $target"
        } catch {
            Write-Warning "  [svc]     Failed: $($entry.Name) - $($_.Exception.Message)"
        }
    }
}

# --- Registry entries ------------------------------------------------------------
foreach ($entry in @($manifest.RegistryEntries | Where-Object { -not $_.Level -or [int]$_.Level -le $Level })) {
    Set-WCSRegistryEntry -Entry $entry -BackupRoot $backupRoot
}
