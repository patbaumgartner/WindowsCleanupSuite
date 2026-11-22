#requires -Version 5.1
<#
.SYNOPSIS
    Enables the Ultimate Performance power plan and applies performance tweaks.

.DESCRIPTION
    - Duplicates + activates the Ultimate Performance scheme (Marvin700 uses
      e9a42b02-d5df-448d-aa00-03f14749eb61; Chainski uses 95533644-e700-4a79-a56c-a89e8cb109d9).
    - Applies the LeDragoX Optimize-Performance registry tweaks (HwSchMode,
      network throttling, SVCHost split threshold, timeouts, etc.).
    - Sets SvcHostSplitThresholdInKB to the installed RAM size.
    - Enables hibernation (Marvin700).

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\PowerPlan\Enable-UltimatePerformancePlan.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest   = Get-SuiteManifest -CleanupName 'PowerPlan'
$backupRoot = Get-SuiteBackupRoot -CleanupName 'PowerPlan'
$isAdmin    = Test-SuiteIsAdmin

if (-not $isAdmin) {
    Write-Warning 'PowerPlan: service/powercfg changes require Administrator; run elevated for full effect.'
}

$powercfg = Join-Path $env:SystemRoot 'System32\powercfg.exe'
$plan = $manifest.PowerPlans[0]

if (-not $PSCmdlet.ShouldProcess($plan.GUID, "Duplicate and activate power plan '$($plan.Name)' (Ultimate Performance)")) {
    Write-Host "  Would activate power plan: $($plan.Name) ($($plan.GUID))"
} elseif (Test-Path $powercfg) {
    & $powercfg -duplicatescheme $plan.GUID 2>$null | Out-Null
    & $powercfg -setactive $plan.GUID 2>$null | Out-Null
    Write-Host "  Activated power plan: $($plan.Name) ($($plan.GUID))"
} else {
    Write-Warning "  powercfg.exe not found at $powercfg - skipping power plan activation"
}

# Registry tweaks are backed up (Set-WCSRegistryEntry) so Restore-PowerPlan.ps1 can revert them.
foreach ($entry in @($manifest.RegistryEntries)) {
    if ($entry.Path -like 'HKLM:*' -and -not $isAdmin) {
        Write-Host "  [reg]     Skipped (Admin): $($entry.Path)\$($entry.Name) - $($entry.Reason)"
        continue
    }
    if ($entry.Type) { Set-WCSRegistryEntry -Entry $entry -BackupRoot $backupRoot -Type $entry.Type }
    else { Set-WCSRegistryEntry -Entry $entry -BackupRoot $backupRoot }
}

# Marvin700: set the SVCHost split threshold to match the installed RAM (LeDragoX Optimize-Performance).
try {
    $ramKB = (Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1024
    if ($ramKB -gt 0) {
        if ($isAdmin) {
            Set-WCSRegistryEntry -Entry @{
                Path = 'HKLM:\SYSTEM\CurrentControlSet\Control'; Name = 'SvcHostSplitThresholdInKB'
                Value = [int]$ramKB; Type = 'DWord'; Reason = 'SvcHost split threshold = installed RAM (KB)'
            } -BackupRoot $backupRoot -Type DWord
        } else {
            Write-Host '  [reg]     Skipped (Admin): HKLM:\SYSTEM\CurrentControlSet\Control\SvcHostSplitThresholdInKB'
        }
    }
} catch {
    Write-Warning "  Failed to set SvcHostSplitThresholdInKB: $($_.Exception.Message)"
}

# Debloat: disable hibernate entirely (faster boot, less disk churn; fast startup
# is separately disabled by the WindowsUpdates cleanup via HiberbootEnabled=0).
if (Test-Path $powercfg) {
    if ($PSCmdlet.ShouldProcess('powercfg', 'HIBERNATE ON then OFF (disable hibernation for faster boot)')) {
        & $powercfg /HIBERNATE ON 2>$null | Out-Null
        $hiberOff = & $powercfg /HIBERNATE OFF 2>$null
        Write-Host "  Disabled hibernate: $hiberOff"
    } else {
        Write-Host '  Would disable hibernate (powercfg /HIBERNATE OFF)'
    }
}
