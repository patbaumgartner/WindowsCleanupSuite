#requires -Version 5.1
<#
.SYNOPSIS
    Restores every cleanup in reverse run order using the per-cleanup
    Restore-*.ps1 scripts and the backups under Backups\.

.DESCRIPTION
    Default is a preview (-WhatIf): prints what would be restored. Pass -Apply
    to actually restore. Requires Administrator for HKLM/service restores.
    The cleanup order is the reverse of Runners\Run-Cleanup.ps1 (see
    Get-SuiteCleanupNames in Core\CleanupEngine.ps1).

.PARAMETER Apply
    Actually restore (requires Administrator for system-wide changes).

.EXAMPLE
    & 'WindowsCleanupSuite\Runners\Restore-All.ps1'          # preview
    & 'WindowsCleanupSuite\Runners\Restore-All.ps1' -Apply  # restore everything
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Apply
)

$SuiteRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $SuiteRoot 'Core\CleanupEngine.ps1')

$LogsRoot = Join-Path $SuiteRoot 'Logs'
if (-not (Test-Path $LogsRoot)) { New-Item -ItemType Directory -Path $LogsRoot -Force | Out-Null }
$LogFile = Join-Path $LogsRoot "$(Get-Date -Format 'yyyyMMdd-HHmmss')-restore-all.log"

$preview = -not $Apply

# Reverse of the run order in Core\CleanupEngine.ps1 Get-SuiteCleanupNames.
$order = @(Get-SuiteCleanupNames)
[array]::Reverse($order)

foreach ($name in $order) {
    $cleanupDir = Join-Path $SuiteRoot "Cleanups\$name"
    $restoreScript = Get-ChildItem -Path $cleanupDir -Filter 'Restore-*.ps1' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $restoreScript) { continue }

    "`n=== Restore: $name ($($restoreScript.Name)) ===" | Tee-Object -FilePath $LogFile -Append | Out-Host
    & $restoreScript.FullName -WhatIf:$preview 2>&1 | Tee-Object -FilePath $LogFile -Append | Out-Host
}

if ($preview) {
    Write-Host "`nMode: PREVIEW (dry-run; nothing was restored). Pass -Apply to restore."
} else {
    Write-Host "`nMode: APPLY (state was restored from backups)."
}
Write-Host "Log: $LogFile"
