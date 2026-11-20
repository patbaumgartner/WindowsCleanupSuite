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

    [switch]$AutoApprove
)

$SuiteRoot = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $SuiteRoot 'Runners\Run-Cleanup.ps1'
if (-not (Test-Path $runner)) {
    Write-Error "Runner script not found: $runner"
    exit 1
}

$powershellExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }

# 1. Preview.
$loginSafeFlag = if ($LoginSafe) { '-LoginSafe' } else { '-LoginSafe:$false' }
$previewArgs = @('-File', $runner, '-Profile', $Profile, $loginSafeFlag)
if ($SkipProcessStops) { $previewArgs += '-SkipProcessStops' }

Write-Host 'Running cleanup preview...'
& $powershellExe @previewArgs

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
$applyArgs = @('-File', $runner, '-Profile', $Profile, '-Apply', $loginSafeFlag)
if ($SkipProcessStops) { $applyArgs += '-SkipProcessStops' }

Write-Host 'Applying cleanup run...'
& $powershellExe @applyArgs
