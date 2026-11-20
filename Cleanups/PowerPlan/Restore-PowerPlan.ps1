#requires -Version 5.1
<#
.SYNOPSIS
    Restores power plan settings changed by Enable-UltimatePerformancePlan.ps1.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\PowerPlan\Restore-PowerPlan.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest = Get-SuiteManifest -CleanupName 'PowerPlan'

foreach ($entry in @($manifest.RegistryEntries)) {
    if (-not $PSCmdlet.ShouldProcess($entry.Path, "Restore $($entry.Name)")) {
        Write-Host "  Would restore: $($entry.Path)\$($entry.Name)"
        continue
    }
    try {
        if (-not (Test-Path $entry.Path)) { New-Item -Path $entry.Path -Force | Out-Null }
        Set-ItemProperty -Path $entry.Path -Name $entry.Name -Value 0 -Type DWord -ErrorAction Stop
        Write-Host "  Restored: $($entry.Path)\$($entry.Name) = 0"
    } catch {
        Write-Warning "  Failed: $($entry.Path)\$($entry.Name)"
    }
}

Write-Host 'Done.'
