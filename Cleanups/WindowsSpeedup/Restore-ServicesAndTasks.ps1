#requires -Version 5.1
<#
.SYNOPSIS
    Restores Windows services and scheduled tasks previously disabled by Disable-ServicesAndTasks.ps1.

.DESCRIPTION
    Reads backup records from <SuiteRoot>\Backups\WindowsSpeedup and restores:
      - Each service's original startup type (Automatic / Manual / Disabled)
      - Each scheduled task's original enabled/disabled state
      - Run autoruns removed by the disable script
      - StartupApproved startup apps
      - AppModel startup task state
      - Visual effect settings

    Because service changes require admin rights this script must be run elevated.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\WindowsSpeedup\Restore-ServicesAndTasks.ps1' -WhatIf
    & 'WindowsCleanupSuite\Cleanups\WindowsSpeedup\Restore-ServicesAndTasks.ps1'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest   = Get-SuiteManifest -CleanupName 'WindowsSpeedup'
$backupRoot = Get-SuiteBackupRoot -CleanupName 'WindowsSpeedup'
$isAdmin    = Test-SuiteIsAdmin

if (-not $isAdmin -and -not $WhatIfPreference) {
    Write-Error 'This script must be run as Administrator (service changes require elevation).'
    return
}

if (-not (Test-Path $backupRoot)) {
    Write-Error "Backup folder not found: $backupRoot - run the disable scripts first."
    return
}

$startTypeMap = @{ 2 = 'Automatic'; 3 = 'Manual'; 4 = 'Disabled' }

# --- Services -----------------------------------------------------------------
foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'Service' })) {
    $svc = Get-Service -Name $record.Name -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Warning "  Service '$($record.Name)' not found - skipping"; continue }

    $startType = $startTypeMap[$record.StartType]
    if (-not $startType) { Write-Warning "  Unknown start type value '$($record.StartType)' for $($record.Name) - skipping"; continue }

    if (-not $PSCmdlet.ShouldProcess($record.Name, "Restore start type to $startType")) {
        Write-Host "  [service] Would restore: $($record.Name) -> $startType"
        continue
    }

    try {
        Set-Service -Name $record.Name -StartupType $startType -ErrorAction Stop
        Write-Host "  [service] Restored: $($record.Name) -> $startType"
    } catch {
        Write-Warning "  [service] Failed to restore $($record.Name): $($_.Exception.Message)"
    }
}

# --- Scheduled tasks ------------------------------------------------------------
foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'Task' })) {
    $task = Get-ScheduledTask -TaskPath $record.TaskPath -TaskName $record.TaskName -ErrorAction SilentlyContinue
    if (-not $task) { Write-Warning "  Scheduled task '$($record.TaskName)' not found - skipping"; continue }

    $state = $record.State
    if (-not $PSCmdlet.ShouldProcess($record.TaskName, "Restore scheduled task state to $state")) {
        Write-Host "  [task] Would restore: $($record.TaskName) -> $state"
        continue
    }

    try {
        if ($state -eq 'Disabled') {
            Disable-ScheduledTask -TaskPath $record.TaskPath -TaskName $record.TaskName -ErrorAction Stop | Out-Null
        } else {
            Enable-ScheduledTask -TaskPath $record.TaskPath -TaskName $record.TaskName -ErrorAction Stop | Out-Null
        }
        Write-Host "  [task] Restored: $($record.TaskName) -> $state"
    } catch {
        Write-Warning "  [task] Failed to restore $($record.TaskName): $($_.Exception.Message)"
    }
}

# --- Run autoruns removed by the disable script -----------------------------------
foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'RunAutorun' })) {
    if (-not (Test-Path $record.Path)) { Write-Warning "  Run autorun path not found: $($record.Path) - skipping"; continue }
    if (-not $PSCmdlet.ShouldProcess($record.Name, 'Restore Run entry')) {
        Write-Host "  [startup] Would restore Run entry: $($record.Name)"
        continue
    }
    try {
        Set-ItemProperty -Path $record.Path -Name $record.Name -Value $record.Value -ErrorAction Stop
        Write-Host "  [startup] Restored Run entry: $($record.Name)"
    } catch {
        Write-Warning "  [startup] Failed to restore Run entry $($record.Name): $($_.Exception.Message)"
    }
}

# --- StartupApproved startup apps ---------------------------------------------------
foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'StartupApproved' })) {
    if (-not (Test-Path $record.Path)) { Write-Warning "  StartupApproved path not found: $($record.Path) - skipping"; continue }
    try { $value = [Convert]::FromBase64String($record.ValueBase64) }
    catch { Write-Warning "  Invalid StartupApproved backup data for $($record.Name) - skipping"; continue }
    if (-not $PSCmdlet.ShouldProcess($record.Name, 'Restore startup app state')) {
        Write-Host "  [startup] Would restore: $($record.Name)"
        continue
    }
    try {
        Set-ItemProperty -Path $record.Path -Name $record.Name -Value $value -Type Binary -ErrorAction Stop
        Write-Host "  [startup] Restored: $($record.Name)"
    } catch {
        Write-Warning "  [startup] Failed to restore $($record.Name): $($_.Exception.Message)"
    }
}

# --- AppModel startup tasks -------------------------------------------------------------
foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'AppModelStartup' })) {
    if (-not (Test-Path $record.Path)) { Write-Warning "  AppModel startup path not found: $($record.Path) - skipping"; continue }
    try { $state = [int]$record.State }
    catch { Write-Warning "  Invalid state value in backup for $($record.Path) - skipping"; continue }
    if (-not $PSCmdlet.ShouldProcess($record.Path, 'Restore app-model startup task state')) {
        Write-Host "  [startup] Would restore app-model startup task: $($record.Path)"
        continue
    }
    try {
        Set-ItemProperty -Path $record.Path -Name $record.Name -Value $state -Type DWord -ErrorAction Stop
        if ($record.UserEnabledStartupOnce) { Set-ItemProperty -Path $record.Path -Name 'UserEnabledStartupOnce' -Value ([int]$record.UserEnabledStartupOnce) -Type DWord -ErrorAction SilentlyContinue }
        if ($record.LastDisabledTime) { Set-ItemProperty -Path $record.Path -Name 'LastDisabledTime' -Value ([int]$record.LastDisabledTime) -Type DWord -ErrorAction SilentlyContinue }
        Write-Host "  [startup] Restored app-model task: $($record.Path)"
    } catch {
        Write-Warning "  [startup] Failed to restore app-model startup task $($record.Path): $($_.Exception.Message)"
    }
}

# --- Visual effects ---------------------------------------------------------------------------
$visualBackupFile = Join-Path $backupRoot 'visual_effects_desktop.json'
if (Test-Path $visualBackupFile) {
    try { $visualBackup = Get-Content -Raw -Path $visualBackupFile | ConvertFrom-Json }
    catch { Write-Warning "Visual effects backup is invalid: $visualBackupFile - skipping"; $visualBackup = $null }

    if ($visualBackup) {
        $desktopKey = 'HKCU:\Control Panel\Desktop'
        if ($PSCmdlet.ShouldProcess('Visual Effects', 'Restore visual effect settings from backup')) {
            try {
                if ($visualBackup.VisualFXSetting) { Set-ItemProperty -Path $desktopKey -Name 'VisualFXSetting' -Value ([int]$visualBackup.VisualFXSetting) -Type DWord -ErrorAction Stop }
                if ($visualBackup.DragFullWindows) { Set-ItemProperty -Path $desktopKey -Name 'DragFullWindows' -Value ([string]$visualBackup.DragFullWindows) -Type String -ErrorAction Stop }
                if ($visualBackup.FontSmoothing) { Set-ItemProperty -Path $desktopKey -Name 'FontSmoothing' -Value ([string]$visualBackup.FontSmoothing) -Type String -ErrorAction Stop }
                Write-Host '  [visual] Restored visual effect settings'
            } catch {
                Write-Warning "  [visual] Failed to restore visual effect settings: $($_.Exception.Message)"
            }
        }
    }
}

Write-Host ''
Write-Host 'Done.'
