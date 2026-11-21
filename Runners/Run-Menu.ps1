#requires -Version 5.1
<#
.SYNOPSIS
    Interactive menu for WindowsCleanupSuite: choose Level and Topics, preview or apply.

    Entry point; implementation is in Core\WCS.Menu.ps1.

.EXAMPLE
    Runners\Run-Menu.ps1
    Runners\Run-Menu.ps1 -Level 2 -Topics 'ServicesTasks,PrivacySettings' -Apply
#>
[CmdletBinding()]
param(
    [string[]]$Topics,
    [string]$Level,
    [switch]$Apply,
    [switch]$NonInteractive,
    [switch]$SavePreferences
)

$MenuPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Core\WCS.Menu.ps1'
if (-not (Test-Path $MenuPath)) { Write-Error "Menu script not found: $MenuPath"; exit 1 }

$exitCode = 0
& $MenuPath @PSBoundParameters
$exitCode = $LASTEXITCODE
exit $exitCode
