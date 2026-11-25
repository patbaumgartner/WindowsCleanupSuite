#requires -Version 5.1
<#
.SYNOPSIS
    Restores startup registry entries previously disabled by Disable-StartupBloat.ps1.

.DESCRIPTION
    Reads the backup records (JSON) from <SuiteRoot>\Backups\StartupBloat and restores
    Run values, per-user StartupApproved flags, app-internal autorun settings and
    Startup-folder shortcuts. HKLM restorations are skipped with a warning when
    not elevated.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\StartupBloat\Restore-StartupBloat.ps1' -WhatIf
    & 'WindowsCleanupSuite\Cleanups\StartupBloat\Restore-StartupBloat.ps1'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$backupRoot = Get-SuiteBackupRoot -CleanupName 'StartupBloat'
$isAdmin    = Test-SuiteIsAdmin

foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot)) {
    # Shortcuts moved out of a Startup folder are restored by moving the file back.
    if ($record.Type -eq 'StartupShortcut') {
        if (-not $record.BackupPath -or -not $record.SourcePath) {
            Write-Warning 'Skipping malformed StartupShortcut backup record.'
            continue
        }
        if ($record.Scope -eq 'AllUsers' -and -not $isAdmin) {
            Write-Host "  Skipped StartupFolder $($record.Name) (requires elevation)"
            continue
        }
        if (-not (Test-Path $record.BackupPath)) {
            Write-Host "  Already absent: $($record.Name) (shortcut no longer in backup)"
            continue
        }
        if (-not $PSCmdlet.ShouldProcess($record.Name, 'Restore StartupFolder shortcut')) {
            Write-Host "  Would restore StartupFolder shortcut: $($record.Name)"
            continue
        }
        try {
            $parent = Split-Path -Parent $record.SourcePath
            if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
            Move-Item -LiteralPath $record.BackupPath -Destination $record.SourcePath -Force -ErrorAction Stop
            Write-Host "  Restored StartupFolder shortcut: $($record.Name)"
        } catch {
            Write-Error "  Failed to restore shortcut '$($record.Name)': $($_.Exception.Message)"
        }
        continue
    }

    # App-internal autorun settings (kDrive SQLite / OneDrive registry).
    if ($record.Type -eq 'AppAutoStartSqlite' -or $record.Type -eq 'AppAutoStartRegistry') {
        if (-not $record.Path -or -not (Test-Path -LiteralPath $record.Path)) {
            Write-Warning "  Skipping app autostart restore: path not found for $($record.Name)."
            continue
        }
        if (-not $PSCmdlet.ShouldProcess($record.Name, 'Restore app autostart setting')) {
            Write-Host "  Would restore app autostart setting: $($record.Name)"
            continue
        }
        Stop-WCSAppProcesses -Names @($record.ProcessNames)
        if ($record.Type -eq 'AppAutoStartSqlite') {
            if (Set-WCSSqliteSingleValue -Database $record.Path -Table $record.Table -Column $record.Column -Value ([int]$record.Value)) {
                Write-Host "  Restored app autostart setting: $($record.Name)"
            } else {
                Write-Warning "  Failed to restore app autostart setting '$($record.Name)'."
            }
            continue
        }
        try {
            if ($record.PSObject.Properties.Name -contains 'Existed' -and -not [bool]$record.Existed) {
                Remove-ItemProperty -LiteralPath $record.Path -Name $record.ValueName -ErrorAction SilentlyContinue
            } else {
                Set-ItemProperty -LiteralPath $record.Path -Name $record.ValueName -Value ([int]$record.Value) -Type DWord -ErrorAction Stop
            }
            Write-Host "  Restored app autostart setting: $($record.Name)"
        } catch {
            Write-Error "  Failed to restore app autostart setting '$($record.Name)': $($_.Exception.Message)"
        }
        continue
    }

    if (-not $record.Path -or -not $record.Name) {
        Write-Warning "Skipping malformed backup record in $backupRoot."
        continue
    }

    # Per-user StartupApproved overlay: restore the original flag, or remove the
    # value again when it did not exist before the cleanup.
    if ($record.Type -eq 'StartupApprovedFlag') {
        if ($record.Path -like 'HKLM:*' -and -not $isAdmin) {
            Write-Host "  Skipped StartupApproved flag $($record.Name) (requires elevation)"
            continue
        }
        if (-not $PSCmdlet.ShouldProcess($record.Name, 'Restore StartupApproved flag')) {
            Write-Host "  Would restore StartupApproved flag: $($record.Name)"
            continue
        }
        try {
            if (-not (Test-Path $record.Path)) { New-Item -Path $record.Path -Force | Out-Null }
            if ($record.PSObject.Properties.Name -contains 'Existed' -and -not [bool]$record.Existed) {
                Remove-ItemProperty -Path $record.Path -Name $record.Name -ErrorAction SilentlyContinue
            } elseif ($record.ValueBase64) {
                Set-ItemProperty -Path $record.Path -Name $record.Name -Value ([Convert]::FromBase64String($record.ValueBase64)) -Type Binary -ErrorAction Stop
            } else {
                Remove-ItemProperty -Path $record.Path -Name $record.Name -ErrorAction SilentlyContinue
            }
            Write-Host "  Restored StartupApproved flag: $($record.Name)"
        } catch {
            Write-Error "  Failed to restore StartupApproved flag '$($record.Name)': $($_.Exception.Message)"
        }
        continue
    }

    # Older records (no Type) and RunAutorun records are original Run values.
    if ($record.Type -and $record.Type -ne 'RunAutorun') { continue }

    if ($record.Hive -eq 'HKLM' -and -not $isAdmin) {
        Write-Host "  Skipped [HKLM] $($record.Name) (requires elevation)"
        continue
    }

    if (-not (Test-Path $record.Path)) {
        Write-Warning "  Skipping: registry path not found: $($record.Path)"
        continue
    }

    if (-not $PSCmdlet.ShouldProcess($record.Name, "Restore Run entry [$($record.Hive)]")) {
        Write-Host "  Would restore [$($record.Hive)] $($record.Name)"
        continue
    }

    try {
        if (-not (Test-Path $record.Path)) { New-Item -Path $record.Path -Force | Out-Null }
        Set-ItemProperty -Path $record.Path -Name $record.Name -Value $record.Value -ErrorAction Stop
        Write-Host "  Restored [$($record.Hive)] $($record.Name)"
    } catch {
        Write-Error "  Failed to restore '$($record.Name)': $($_.Exception.Message)"
    }
}

Write-Host "Done."
