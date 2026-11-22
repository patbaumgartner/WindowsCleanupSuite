#requires -Version 5.1
<#
.SYNOPSIS
    Marvin700 Windows Health: Windows system health checks.

.DESCRIPTION
    - DISM /Online /Cleanup-Image /ScanHealth (Based on Marvin700 Windows_Health.ps1) - read-only
    - DISM /Online /Cleanup-Image /RestoreHealth - repairs the component store (modifies system)
    - sfc /SCANNOW - scans and repairs protected system files (modifies system)

    The repair steps honor -WhatIf and should be run elevated.

.EXAMPLE
    & 'WindowsCleanupSuite\Audit\Check-SystemHealth.ps1'
    & 'WindowsCleanupSuite\Audit\Check-SystemHealth.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Core\CleanupEngine.ps1')

if (-not (Test-SuiteIsAdmin)) {
    Write-Warning 'Check-SystemHealth: DISM /RestoreHealth and sfc repairs require Administrator; run elevated for full effect.'
}

$steps = @(
    @{ Name = 'Dism /Online /Cleanup-Image /ScanHealth';    File = 'Dism.exe'; Args = @('/Online', '/Cleanup-Image', '/ScanHealth') },
    @{ Name = 'Dism /Online /Cleanup-Image /RestoreHealth'; File = 'Dism.exe'; Args = @('/Online', '/Cleanup-Image', '/RestoreHealth') },
    @{ Name = 'sfc /SCANNOW';                              File = 'sfc.exe';  Args = @('/SCANNOW') }
)

foreach ($step in $steps) {
    Write-Host $step.Name
    if (-not $PSCmdlet.ShouldProcess($step.Name, 'Run')) {
        Write-Host "  Would run: $($step.Name)"
        continue
    }
    & $step.File @($step.Args) 2>&1 | Out-Host
}
