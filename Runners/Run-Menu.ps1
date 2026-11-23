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
    [switch]$AutoApprove,
    [switch]$NonInteractive,
    [switch]$SavePreferences,
    [switch]$AllowRisky,
    [switch]$Quick,
    [switch]$NoParallel,
    [int]$MaxParallel = 4,
    [int]$ScheduleDays = -1,
    [switch]$ReviewBackups
)

$MenuPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Core\WCS.Menu.ps1'
if (-not (Test-Path $MenuPath)) { Write-Error "Menu script not found: $MenuPath"; exit 1 }

$exitCode = 0
& $MenuPath @PSBoundParameters
$exitCode = $LASTEXITCODE
exit $exitCode
