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

.PARAMETER AllowRisky
    Also apply entries flagged Risky = $true in the manifests
    (e.g. NetBIOS off, static DNS resolvers, VPN/Citrix services).

.EXAMPLE
    & 'WindowsCleanupSuite\Runners\Run-Cleanup.ps1' -Profile Balanced          # preview
    & 'WindowsCleanupSuite\Runners\Run-Cleanup.ps1' -Profile Balanced -Apply   # apply
    & 'WindowsCleanupSuite\Runners\Run-Cleanup.ps1' -Profile Maximum -Apply -AllowRisky
#>
[CmdletBinding()]
param(
    [ValidateSet('Balanced', 'Maximum')]
    [string]$Profile = 'Balanced',

    [switch]$LoginSafe = $true,

    [switch]$Apply,

    [switch]$SkipProcessStops,

    [switch]$AllowRisky
)

$SuiteRoot = Split-Path -Parent $PSScriptRoot
$LogsRoot  = Join-Path $SuiteRoot 'Logs'
# Unique suffix avoids file-lock collisions when two runs start in the same second
# or when a scheduled re-run overlaps with a manual one.
$unique = [System.Guid]::NewGuid().ToString('N').Substring(0, 6)
$LogFile = Join-Path $LogsRoot "$(Get-Date -Format 'yyyyMMdd-HHmmss')-run-cleanup-$unique.log"

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

Invoke-SuiteStep -Title 'Perf Snapshot (Before)' -Action {
    & (Join-Path $SuiteRoot 'Audit\Perf-Snapshot.ps1') -Phase Before
}

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
        & $script -WhatIf -Profile $Profile -LoginSafe:$LoginSafe -SkipProcessStops:$SkipProcessStops -AllowRisky:$AllowRisky
    } else {
        & $script -Profile $Profile -LoginSafe:$LoginSafe -SkipProcessStops:$SkipProcessStops -AllowRisky:$AllowRisky
    }
}

Invoke-SuiteStep -Title 'Installed Software' -Action {
    & (Join-Path $SuiteRoot 'Cleanups\InstalledSoftware\Disable-InstalledSoftware.ps1') -WhatIf:$preview
}

Invoke-SuiteStep -Title 'Windows AI' -Action {
    & (Join-Path $SuiteRoot 'Cleanups\WindowsAI\Disable-WindowsAI.ps1') -WhatIf:$preview
}

Invoke-SuiteStep -Title 'Privacy (telemetry/ads/suggestions)' -Action {
    & (Join-Path $SuiteRoot 'Cleanups\Privacy\Disable-Privacy.ps1') -WhatIf:$preview -AllowRisky:$AllowRisky
}

Invoke-SuiteStep -Title 'Browsers (background mode / startup boost)' -Action {
    & (Join-Path $SuiteRoot 'Cleanups\Browsers\Disable-Browsers.ps1') -WhatIf:$preview -AllowRisky:$AllowRisky
}

Invoke-SuiteStep -Title 'Network (LLMNR / Delivery Optimization / DNS)' -Action {
    & (Join-Path $SuiteRoot 'Cleanups\Network\Disable-Network.ps1') -WhatIf:$preview -AllowRisky:$AllowRisky
}

Invoke-SuiteStep -Title 'Temp And Junk Files' -Action {
    & (Join-Path $SuiteRoot 'Cleanups\TempAndJunkFiles\Disable-TempAndJunkFiles.ps1') -WhatIf:$preview
}

Invoke-SuiteStep -Title 'Power Plan' -Action {
    & (Join-Path $SuiteRoot 'Cleanups\PowerPlan\Enable-UltimatePerformancePlan.ps1') -WhatIf:$preview
}

Invoke-SuiteStep -Title 'DNS Reset' -Action {
    & (Join-Path $SuiteRoot 'Cleanups\DNSReset\Disable-DNSReset.ps1') -WhatIf:$preview
}

Invoke-SuiteStep -Title 'Post-Run Audit' -Action {
    & (Join-Path $SuiteRoot 'Audit\Audit-State.ps1') -Profile $Profile -LoginSafe:$LoginSafe
}

Invoke-SuiteStep -Title 'Audit: Installed Software' -Action {
    & (Join-Path $SuiteRoot 'Audit\Audit-InstalledSoftware.ps1')
}

Invoke-SuiteStep -Title 'Audit: Running Services' -Action {
    & (Join-Path $SuiteRoot 'Audit\Audit-RunningServices.ps1')
}

Invoke-SuiteStep -Title 'Perf Snapshot (After)' -Action {
    & (Join-Path $SuiteRoot 'Audit\Perf-Snapshot.ps1') -Phase After
}

if ($Apply) {
    Write-Host "`nMode: APPLY (changes were made)."
    Write-Host "Log: $LogFile"
} else {
    Write-Host "`nMode: PREVIEW (dry-run; nothing was modified)."
    Write-Host "Preview log: $LogFile"
}
