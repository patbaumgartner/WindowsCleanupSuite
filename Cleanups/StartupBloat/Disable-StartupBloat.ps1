#requires -Version 5.1
<#
.SYNOPSIS
    Disables the nonessential auto-start registry entries that slow down Windows login.

.DESCRIPTION
    Removes entries from the HKCU and HKLM Run registry keys, saving each original
    value to <SuiteRoot>\Backups\StartupBloat so Restore-StartupBloat.ps1 can put
    everything back.

    HKLM entries require an elevated (Run as Administrator) session; they are
    skipped with a warning when not elevated. Protected entries (Intel Driver &
    Support Assistant) are never modified.

    The target list is data-driven: WindowsCleanupSuite\Cleanups\StartupBloat\Manifest.psd1

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\StartupBloat\Disable-StartupBloat.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest   = Get-SuiteManifest -CleanupName 'StartupBloat'
$backupRoot = Get-SuiteBackupRoot -CleanupName 'StartupBloat'
$isAdmin    = Test-SuiteIsAdmin

foreach ($target in @($manifest.Targets)) {
    $label = Get-SuiteEntryLabel -Entry $target
    if ($target.Hive -eq 'HKLM' -and -not $isAdmin) {
        Write-Host "  Skipped [HKLM] $label (requires elevation)"
        continue
    }

    $matches = @(Get-RegistryEntryValues -Path $target.Path -Entry $target)
    if (-not $matches.Count) {
        Write-Host "  Already absent [$($target.Hive)] $label"
        continue
    }

    foreach ($match in $matches) {
        if (Test-SuiteIsProtected -Name $match.Name -Manifest $manifest) {
            Write-Host "  Skipped (Protected) [$($target.Hive)] $($match.Name)"
            continue
        }

        if (-not $PSCmdlet.ShouldProcess($match.Name, "Remove Run entry [$($target.Hive)]")) {
            Write-Host "  Would disable [$($target.Hive)] $($match.Name)"
            continue
        }

        New-SuiteBackupFile -BackupRoot $backupRoot -FileName "$($target.Hive)_$($match.Name).txt" -Record @{
            Hive = $target.Hive; Path = $target.Path; Name = $match.Name; Value = $match.Value
        }

        try {
            Remove-ItemProperty -Path $target.Path -Name $match.Name -ErrorAction Stop
            Write-Host "  Disabled [$($target.Hive)] $($match.Name)"
        } catch {
            Write-Warning "  Failed to disable '$($match.Name)': $($_.Exception.Message)"
        }
    }
}

Write-Host "Done. Backups are in $backupRoot"
