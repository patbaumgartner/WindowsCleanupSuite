#requires -Version 5.1
<#
.SYNOPSIS
    Monthly wrapper around Runners\Run-Cleanup.ps1: preview first, then ask for
    explicit confirmation before applying changes.
#>
[CmdletBinding()]
param(
    [ValidateSet('Balanced', 'Maximum')]
    [string]$Profile = 'Balanced',

    [switch]$LoginSafe = $true,

    [switch]$SkipProcessStops,

    [switch]$AllowRisky,

    [switch]$AutoApprove
)

$SuiteRoot = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $SuiteRoot 'Runners\Run-Cleanup.ps1'
if (-not (Test-Path $runner)) {
    Write-Error "Runner script not found: $runner"
    exit 1
}

# Note: the runner is invoked directly (& $runner ...) in this same process -
# spawning a nested powershell.exe is avoided on purpose.

# 1. Preview.
Write-Host 'Running cleanup preview...'
& $runner -Profile $Profile -LoginSafe:$LoginSafe -SkipProcessStops:$SkipProcessStops -AllowRisky:$AllowRisky

# 2. Confirm.
$approved = $AutoApprove
if (-not $approved) {
    $answer = Read-Host 'Apply these changes now? Type YES to continue'
    $approved = ($answer -eq 'YES')
}
if (-not $approved) {
    Write-Host 'Canceled after preview. No changes were applied.'
    exit 0
}

# 3. Apply.
Write-Host 'Applying cleanup run...'
& $runner -Profile $Profile -Apply -LoginSafe:$LoginSafe -SkipProcessStops:$SkipProcessStops -AllowRisky:$AllowRisky
