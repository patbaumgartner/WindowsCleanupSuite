#requires -Version 5.1
<#
.SYNOPSIS
    Runs the WindowsCleanupSuite cleanups: startup bloat and Windows speedup.

.DESCRIPTION
    Default mode is a preview (dry-run): nothing is modified. Pass -Apply to
    make the changes. The Windows speedup cleanup requires Administrator.

.PARAMETER Profile
    Balanced (safe, default) or Maximum (aggressive).

.PARAMETER LoginSafe
    Default: on - keeps login/session-critical components enabled.

.PARAMETER Apply
    Actually change system state (requires Administrator).

.PARAMETER SkipProcessStops
    Skip stopping already-running user applications.

.EXAMPLE
    & 'WindowsCleanupSuite\Runners\Run-Cleanup.ps1' -Profile Balanced          # preview
    & 'WindowsCleanupSuite\Runners\Run-Cleanup.ps1' -Profile Balanced -Apply   # apply
#>
[CmdletBinding()]
param(
    [ValidateSet('Balanced', 'Maximum')]
    [string]$Profile = 'Balanced',

    [switch]$LoginSafe = $true,

    [switch]$Apply,

    [switch]$SkipProcessStops
)

$SuiteRoot = Split-Path -Parent $PSScriptRoot
$LogsRoot  = Join-Path $SuiteRoot 'Logs'
$LogFile   = Join-Path $LogsRoot "$(Get-Date -Format 'yyyyMMdd-HHmmss')-run-cleanup.log"

if (-not (Test-Path $LogsRoot)) { New-Item -ItemType Directory -Path $LogsRoot -Force | Out-Null }

function Invoke-SuiteStep {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    "`n=== $Title ===" | Tee-Object -FilePath $LogFile -Append | Out-Host
    & $Action 2>&1 | Tee-Object -FilePath $LogFile -Append | Out-Host
}

$preview = -not $Apply

Invoke-SuiteStep -Title 'Startup Bloat' -Action {
    if ($preview) {
        & (Join-Path $SuiteRoot 'Cleanups\StartupBloat\Disable-StartupBloat.ps1') -WhatIf
    } else {
        & (Join-Path $SuiteRoot 'Cleanups\StartupBloat\Disable-StartupBloat.ps1')
    }
}

Invoke-SuiteStep -Title "Windows Speedup ($Profile)" -Action {
    $script = Join-Path $SuiteRoot 'Cleanups\WindowsSpeedup\Disable-ServicesAndTasks.ps1'
    if ($preview) {
        & $script -WhatIf -Profile $Profile -LoginSafe:$LoginSafe -SkipProcessStops:$SkipProcessStops
    } else {
        & $script -Profile $Profile -LoginSafe:$LoginSafe -SkipProcessStops:$SkipProcessStops
    }
}

Invoke-SuiteStep -Title 'Post-Run Audit' -Action {
    & (Join-Path $SuiteRoot 'Audit\Audit-State.ps1') -Profile $Profile -LoginSafe:$LoginSafe
}

if ($Apply) {
    Write-Host "`nMode: APPLY (changes were made)."
    Write-Host "Log: $LogFile"
} else {
    Write-Host "`nMode: PREVIEW (dry-run; nothing was modified)."
    Write-Host "Preview log: $LogFile"
}
