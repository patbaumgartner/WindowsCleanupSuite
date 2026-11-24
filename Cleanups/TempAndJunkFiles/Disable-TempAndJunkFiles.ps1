#requires -Version 5.1
<#
.SYNOPSIS
    Deletes temporary files, log files, event logs, prefetch, crash dumps,
    PowerShellReadLine cache, caches and other junk.

.DESCRIPTION
    Based on Chainski WindowsCleanerUtility (temp files, logs, event logs, trace
    files, old files, traces, history, cookies, remnant driver files, DNS reset)
    and Marvin700 Windows Cleanup (temp, prefetch, caches, crash dumps).

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.PARAMETER Quick
    Fast preview: skips the recursive per-file scan of every junk directory (the
    expensive full-machine scan) and only reports the patterns that would be cleaned.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\TempAndJunkFiles\Disable-TempAndJunkFiles.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Quick
)

if ($Quick -and -not $WhatIfPreference) {
    Write-Error '-Quick is a preview-only fast mode and cannot be combined with apply mode. Use -WhatIf or drop -Quick.'
    exit 1
}

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest = Get-SuiteManifest -CleanupName 'TempAndJunkFiles'
$isAdmin  = Test-SuiteIsAdmin

function Resolve-JunkPath {
    param([string]$Path)
    return $Path -replace '%TEMP%', $env:TEMP -replace '%SYSTEMROOT%', $env:SystemRoot -replace '%WINDIR%', $env:SystemRoot -replace '%LOCALAPPDATA%', $env:LOCALAPPDATA -replace '%USERPROFILE%', $env:USERPROFILE -replace '%APPDATA%', $env:APPDATA -replace '%SYSTEMDRIVE%', $env:SystemDrive -replace '%PROGRAMDATA%', $env:ProgramData -replace '%ALLUSERSPROFILE%', $env:ALLUSERSPROFILE
}

function Remove-JunkContents {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    if (-not $PSCmdlet.ShouldProcess($Path, 'Delete junk directory contents')) { Write-Host "  Would clean: $Path"; return }
    try {
        $rmErrors = @()
        Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable +rmErrors
        if ($rmErrors.Count) { Write-Warning "  Partially cleaned: $Path ($($rmErrors.Count) item(s) failed - locked or access denied)" }
        else { Write-Host "  Cleaned: $Path" }
    } catch { Write-Warning "  Failed: $Path - $($_.Exception.Message)" }
}

foreach ($dir in @($manifest.Directories)) {
    $resolved = Resolve-JunkPath $dir
    if (-not $isAdmin -and $resolved -like "$($env:SystemRoot)\*") { Write-Host "  Skipped (Admin): $resolved"; continue }
    Remove-JunkContents -Path $resolved
}

if (@($manifest.FilePatterns).Count) {
    if ($Quick) {
        # -Quick: the recursive Get-ChildItem over every junk directory is the expensive
        # full-machine scan - skip it and just report the patterns that would be cleaned.
        $quickDirs = @(@($manifest.Directories) | ForEach-Object { Resolve-JunkPath $_ } | Where-Object { Test-Path $_ })
        foreach ($pattern in @($manifest.FilePatterns)) {
            if (-not $PSCmdlet.ShouldProcess(($quickDirs -join '; '), "Delete files matching '$pattern' in junk directories")) {
                Write-Host "  Would delete: $pattern in $($quickDirs.Count) junk dir(s) (-Quick: file count skipped)"
            } else {
                Write-Host "  (-Quick) Pattern scan skipped (quick mode is preview-only): $pattern"
            }
        }
    } else {
        foreach ($dir in @($manifest.Directories)) {
            $resolved = Resolve-JunkPath $dir
            if (-not (Test-Path $resolved)) { continue }
            foreach ($pattern in @($manifest.FilePatterns)) {
                $files = @(Get-ChildItem -Path $resolved -Include $pattern -Recurse -File -ErrorAction SilentlyContinue)
                if (-not $files.Count) { continue }
                if (-not $PSCmdlet.ShouldProcess($resolved, "Delete files matching '$pattern' in junk directories")) { Write-Host "  Would delete: $pattern in $resolved"; continue }
                try { $files | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "  Deleted $($files.Count) files matching '$pattern' in $resolved" } catch { Write-Warning "  Failed: $($_.Exception.Message)" }
            }
        }
    }
}

if ($manifest.ClearEventLogs) {
    if (-not $isAdmin) {
        Write-Host '  Skipped (Admin): clear event logs'
    } elseif (-not $PSCmdlet.ShouldProcess('Windows Event Logs', 'Clear event logs (wevtutil cl)')) {
        Write-Host '  Would clear event logs'
    } else {
        foreach ($log in @(wevtutil el 2>$null)) { wevtutil cl $log 2>$null | Out-Null }
        Write-Host '  Cleared event logs'
    }
}

# Disk Cleanup (classic presets; low-value files only)
if ($manifest.DiskCleanupSagerun) {
    $sagerun = $manifest.DiskCleanupSagerun
    if (-not $PSCmdlet.ShouldProcess('Disk Cleanup', "Run Disk Cleanup (cleanmgr /verylowdisk /sagerun:$sagerun)")) {
        Write-Host "  Would run: cleanmgr /verylowdisk /sagerun:$sagerun"
    } else {
        try {
            $out = & cmd /c "cleanmgr /verylowdisk /sagerun:$sagerun" 2>&1
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -notin @(1)) { Write-Host "  Ran: cleanmgr /verylowdisk /sagerun:$sagerun" } else { Write-Warning "  cleanmgr exit code: $LASTEXITCODE" }
        } catch { Write-Warning "  cleanmgr failed: $($_.Exception.Message)" }
    }
}

# Defragment system drive (enables fast startup-friendly fragmentation levels)
$defragDrive = $env:SystemDrive
if (-not $isAdmin) {
    Write-Host "  Skipped (Admin): defragment $defragDrive"
} elseif ($PSCmdlet.ShouldProcess($defragDrive, 'Defragment drive /O /U (user files only)')) {
    try {
        & cmd /c "defrag $defragDrive /O /U" 2>&1 | Out-Null
        Write-Host "  Defragmented (optimize): $defragDrive"
    } catch { Write-Warning "  defrag failed: $($_.Exception.Message)" }
}

Write-Host 'Done.'
