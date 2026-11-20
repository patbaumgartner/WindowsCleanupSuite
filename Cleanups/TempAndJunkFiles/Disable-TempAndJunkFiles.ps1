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

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\TempAndJunkFiles\Disable-TempAndJunkFiles.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest = Get-SuiteManifest -CleanupName 'TempAndJunkFiles'

function Resolve-JunkPath {
    param([string]$Path)
    return $Path -replace '%TEMP%', $env:TEMP -replace '%SYSTEMROOT%', $env:SystemRoot -replace '%WINDIR%', $env:SystemRoot -replace '%LOCALAPPDATA%', $env:LOCALAPPDATA -replace '%USERPROFILE%', $env:USERPROFILE -replace '%APPDATA%', $env:APPDATA -replace '%SYSTEMDRIVE%', $env:SystemDrive -replace '%PROGRAMDATA%', $env:ProgramData -replace '%ALLUSERSPROFILE%', $env:ALLUSERSPROFILE
}

function Remove-JunkContents {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    if (-not $PSCmdlet.ShouldProcess($Path, 'Delete junk directory contents')) { Write-Host "  Would clean: $Path"; return }
    try {
        Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Cleaned: $Path"
    } catch { Write-Warning "  Failed: $Path - $($_.Exception.Message)" }
}

foreach ($dir in @($manifest.Directories)) { Remove-JunkContents -Path (Resolve-JunkPath $dir) }

if (@($manifest.FilePatterns).Count) {
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

if ($manifest.ClearEventLogs) {
    if (-not $PSCmdlet.ShouldProcess('Windows Event Logs', 'Clear event logs (wevtutil cl)')) {
        Write-Host '  Would clear event logs'
    } else {
        foreach ($log in @(wevtutil el 2>$null)) { wevtutil cl $log 2>$null | Out-Null }
        Write-Host '  Cleared event logs'
    }
}

Write-Host 'Done.'
