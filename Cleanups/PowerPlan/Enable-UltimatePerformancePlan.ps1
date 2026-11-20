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

$manifest = Get-SuiteManifest -CleanupName 'PowerPlan'

if (-not (Test-SuiteIsAdmin)) {
    Write-Warning 'PowerPlan: service/powercfg changes require Administrator; run elevated for full effect.'
}

$powercfg = Join-Path $env:SystemRoot 'System32\powercfg.exe'
$plan = $manifest.PowerPlans[0]

if (-not $PSCmdlet.ShouldProcess($plan.GUID, "Duplicate and activate power plan '$($plan.Name)' (Ultimate Performance)")) {
    Write-Host "  Would activate power plan: $($plan.Name) ($($plan.GUID))"
    return
}

if (Test-Path $powercfg) {
    & $powercfg -duplicatescheme $plan.GUID 2>$null | Out-Null
    & $powercfg -setactive $plan.GUID 2>$null | Out-Null
    Write-Host "  Activated power plan: $($plan.Name) ($($plan.GUID))"
} else {
    Write-Warning "  powercfg.exe not found at $powercfg - skipping power plan activation"
}

foreach ($entry in @($manifest.RegistryEntries)) {
    if (-not $PSCmdlet.ShouldProcess($entry.Path, "Set $($entry.Name) = $($entry.Value)")) {
        Write-Host "  Would set: $($entry.Path)\$($entry.Name)"
        continue
    }
    try {
        if (-not (Test-Path $entry.Path)) { New-Item -Path $entry.Path -Force | Out-Null }
        Set-ItemProperty -Path $entry.Path -Name $entry.Name -Value $entry.Value -Type DWord -ErrorAction Stop
        Write-Host "  Set: $($entry.Path)\$($entry.Name) = $($entry.Value)"
    } catch {
        Write-Warning "  Failed: $($entry.Path)\$($entry.Name) - $($_.Exception.Message)"
    }
}

# Marvin700: set the SVCHost split threshold to match the installed RAM (LeDragoX Optimize-Performance).
try {
    $ramKB = (Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1024
    if ($ramKB -gt 0) {
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'SvcHostSplitThresholdInKB' -Type DWord -Value $ramKB -ErrorAction Stop
        Write-Host "  Set: HKLM:\SYSTEM\CurrentControlSet\Control\SvcHostSplitThresholdInKB = $ramKB"
    }
} catch {
    Write-Warning "  Failed to set SvcHostSplitThresholdInKB: $($_.Exception.Message)"
}

# Marvin700: enable hibernation
if (Test-Path $powercfg) {
    & $powercfg /HIBERNATE ON 2>$null | Out-Null
    Write-Host '  Enabled hibernation (full)'
}
