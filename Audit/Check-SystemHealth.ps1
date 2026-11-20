#requires -Version 5.1
<#
.SYNOPSIS
    Marvin700 Windows Health: Windows system health checks.

.DESCRIPTION
    - DISM /Online /Cleanup-Image /ScanHealth (Based on Marvin700 Windows_Health.ps1)
    - DISM /Online /Cleanup-Image /RestoreHealth
    - sfc /SCANNOW

.EXAMPLE
    & 'WindowsCleanupSuite\Audit\Check-SystemHealth.ps1'
#>
[CmdletBinding()]
param()

Write-Host 'Windows health check'
Write-Host 'Dism /Online /Cleanup-Image /ScanHealth'
Dism /Online /Cleanup-Image /ScanHealth 2>&1 | Out-Host
Write-Host 'Dism /Online /Cleanup-Image /RestoreHealth'
Dism /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-Host
Write-Host 'sfc /SCANNOW'
sfc /scannow 2>&1 | Out-Host
