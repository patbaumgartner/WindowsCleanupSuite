#requires -Version 5.1
<#
.SYNOPSIS
    Resets the DNS resolver cache and network stack settings.

.DESCRIPTION
    Commands from the DNSReset manifest. Note: netsh winsock reset and the IP
    stack resets require a reboot to take full effect.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\DNSReset\Disable-DNSReset.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest = Get-SuiteManifest -CleanupName 'DNSReset'

foreach ($cmd in @($manifest.Commands)) {
    if (-not $PSCmdlet.ShouldProcess($cmd, 'Run DNS reset command')) { Write-Host "  Would run: $cmd"; continue }
    try { & cmd /c $cmd 2>&1 | Out-Null; Write-Host "  Ran: $cmd" } catch { Write-Warning "  Failed: $cmd - $($_.Exception.Message)" }
}

Write-Host 'Note: netsh winsock reset requires a reboot to take full effect.'
