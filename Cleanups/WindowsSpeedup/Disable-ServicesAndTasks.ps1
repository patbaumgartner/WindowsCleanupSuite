#requires -Version 5.1
<#
.SYNOPSIS
    Disables nonessential Windows services and scheduled tasks to speed up boot
    and reduce background CPU/disk load.

.DESCRIPTION
    Data-driven from WindowsCleanupSuite\Cleanups\WindowsSpeedup\Manifest.psd1:

      - Services are set to Manual (never Disabled) so Windows can still start
        them on demand; every original start type is backed up before changing.
      - Scheduled tasks are disabled (backed up first).
      - OneDrive/Microsoft Lists Run autoruns and StartupApproved startup apps
        are removed/disabled (backed up first).
      - AppModel startup tasks (Phone Link, WhatsApp, Teams, CrossDevice) are
        disabled (backed up first).
      - Already-running heavy/background apps are stopped.
      - Visual effects are set to best-performance (font smoothing kept).

    Protected components (Intel Driver & Support Assistant, DSA tasks, etc.) are
    NEVER modified, in any profile or mode. Requires Administrator for service
    changes. The menu passes -WhatIf for previews; run without -WhatIf to apply.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.PARAMETER Profile
    Optimization strictness: Balanced (safe) or Maximum (aggressive).

.PARAMETER LoginSafe
    Keeps login/session-critical components enabled: OneDrive run entries,
    csc_vpnagent, CtxsDPS, CWAUpdaterService, WSearch.

.PARAMETER SkipProcessStops
    Skips stopping already-running user applications at the end of the run.

.PARAMETER AllowRisky
    Also apply entries flagged Risky = $true in the manifest
    (VPN/Citrix services, Windows Search indexing, cross-device platform).

.EXAMPLE
    & '.\Disable-ServicesAndTasks.ps1' -WhatIf
    & '.\Disable-ServicesAndTasks.ps1' -Profile Balanced
    & '.\Disable-ServicesAndTasks.ps1' -Profile Maximum -AllowRisky
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Balanced', 'Maximum')]
    [string]$Profile = 'Maximum',

    [switch]$LoginSafe,

    [switch]$SkipProcessStops,

    [switch]$AllowRisky
)

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest   = Get-SuiteManifest -CleanupName 'WindowsSpeedup'
$backupRoot = Get-SuiteBackupRoot -CleanupName 'WindowsSpeedup'
$isAdmin    = Test-SuiteIsAdmin

if (-not $isAdmin -and -not $WhatIfPreference) {
    Write-Error 'This script must be run as Administrator (service changes require elevation).'
    return
}

function Disable-SuiteService {
    param([psobject]$Entry)

    $matches = @()
    if ($Entry.NamePattern) {
        $matches = @(Get-SuiteCachedServices | Where-Object { $_.Name -like $Entry.NamePattern })
    } else {
        $matches = @(Get-SuiteCachedServices | Where-Object { $_.Name -eq $Entry.Name })
    }

    if (-not $matches.Count) {
        Write-Host "  [service] No matches: $(Get-SuiteEntryLabel -Entry $Entry) - $($Entry.Reason)"
        return
    }

    foreach ($svc in $matches) {
        if (Test-SuiteIsProtected -Name $svc.Name -Manifest $manifest) {
            Write-Host "  [service] Skipped (Protected): $($svc.Name) - $($Entry.Reason)"
            continue
        }

        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)"
        $start = $null
        try { $start = (Get-ItemProperty -Path $regPath -Name 'Start' -ErrorAction Stop).Start } catch { $start = $null }
        if ($null -eq $start) {
            Write-Host "  [service] Already absent: $($svc.Name) - $($Entry.Reason)"
            continue
        }

        if (-not $PSCmdlet.ShouldProcess($svc.Name, "Set start type to Manual ($($Entry.Reason))")) {
            Write-Host "  [service] Would disable: $($svc.Name) - $($Entry.Reason)"
            continue
        }

        New-SuiteBackupFile -BackupRoot $backupRoot -FileName "svc_$($svc.Name).txt" -Record @{
            Type = 'Service'; Name = $svc.Name; StartType = [int]$start; Reason = $Entry.Reason
        }

        try {
            Set-Service -Name $svc.Name -StartupType Manual -ErrorAction Stop
            if ($svc.Status -eq 'Running') { Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue }
            Write-Host "  [service] Disabled: $($svc.Name) - $($Entry.Reason)"
        } catch {
            try {
                Set-ItemProperty -Path $regPath -Name 'Start' -Value 3 -Type DWord -ErrorAction Stop
                if ($svc.Status -eq 'Running') { Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue }
                Write-Host "  [service] Disabled via registry: $($svc.Name) - $($Entry.Reason)"
            } catch {
                Write-Warning "  [service] Failed to change $($svc.Name): $($_.Exception.Message)"
            }
        }
    }
}

foreach ($entry in @($manifest.Services)) {
    if (-not (Test-SuiteEntryApplies -Entry $entry -Profile $Profile)) { continue }
    if (Test-SuiteLoginSafeExcluded -Entry $entry -LoginSafeExclusions $manifest.LoginSafeExclusions) {
        Write-Host "  [service] Skipped (LoginSafe): $($entry.Name)"
        continue
    }
    if (-not (Test-SuiteEntryRiskyAllowed -Entry $entry -AllowRisky:$AllowRisky)) {
        Write-Host "  [service] Skipped (Risky - pass -AllowRisky): $($entry.Name) - $($entry.Reason)"
        continue
    }
    Disable-SuiteService -Entry $entry
}

function Disable-SuiteScheduledTask {
    param([psobject]$Entry)

    $matches = @()
    $path = $null
    if ($Entry.NamePattern) {
        if ($Entry.PathPattern) {
            $path = $Entry.PathPattern
        } elseif ($Entry.Path) {
            $path = $Entry.Path
        }
        $allTasks = @(Get-SuiteCachedTasks)
        $matches = @($allTasks | Where-Object { $_.TaskName -like $Entry.NamePattern -and (-not $path -or $_.TaskPath -eq $path) })
    } else {
        $matches = @(Get-SuiteCachedTasks | Where-Object { $_.TaskName -eq $Entry.Name -and $_.TaskPath -eq $Entry.Path })
    }

    if (-not $matches.Count) {
        Write-Host "  [task]    No matches: $(Get-SuiteEntryLabel -Entry $Entry) - $($Entry.Reason)"
        return
    }

    foreach ($task in $matches) {
        if (Test-SuiteIsProtected -Name $task.TaskName -Manifest $manifest) {
            Write-Host "  [task]    Skipped (Protected): $($task.TaskName) - $($Entry.Reason)"
            continue
        }

        if (-not $PSCmdlet.ShouldProcess($task.TaskName, "Disable scheduled task ($($Entry.Reason))")) {
            Write-Host "  [task]    Would disable: $($task.TaskName) - $($Entry.Reason)"
            continue
        }

        New-SuiteBackupFile -BackupRoot $backupRoot -FileName "task_$(Get-SuiteSafeFileName $task.TaskName).txt" -Record @{
            Type = 'Task'; TaskPath = $task.TaskPath; TaskName = $task.TaskName
            State = $task.State; Enabled = [bool]$task.Settings.Enabled; Reason = $Entry.Reason
        }

        try {
            Disable-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName -ErrorAction Stop | Out-Null
            Write-Host "  [task]    Disabled: $($task.TaskName) - $($Entry.Reason)"
        } catch {
            Write-Warning "  [task]    Failed to disable $($task.TaskName): $($_.Exception.Message)"
        }
    }
}

foreach ($entry in @($manifest.Tasks)) {
    if (-not (Test-SuiteEntryApplies -Entry $entry -Profile $Profile)) { continue }
    if (-not (Test-SuiteEntryRiskyAllowed -Entry $entry -AllowRisky:$AllowRisky)) {
        Write-Host "  [task]    Skipped (Risky - pass -AllowRisky): $($entry.Name) - $($entry.Reason)"
        continue
    }
    Disable-SuiteScheduledTask -Entry $entry
}

# OneDrive background/update/startup tasks (names vary by SID).
if (-not $LoginSafe) {
    $oneDriveTasks = @(Get-SuiteCachedTasks |
        Where-Object {
            $_.TaskName -eq 'OneDrive Per-Machine Standalone Update Task' -or
            $_.TaskName -like 'OneDrive Reporting Task-*' -or
            $_.TaskName -like 'OneDrive Startup Task-*'
        })
    foreach ($task in $oneDriveTasks) {
        Disable-SuiteScheduledTask -Entry ([pscustomobject]@{ Path = $task.TaskPath; Name = $task.TaskName; Reason = 'OneDrive background/update task' })
    }
} else {
    Write-Host '  [task]    Skipped OneDrive scheduled task changes (LoginSafe)'
}

function Disable-SuiteRunAutorun {
    param([psobject]$Entry)

    $names = @()
    if ($Entry.NamePattern) {
        if (Test-Path $Entry.Path) {
            $names = @((Get-Item -Path $Entry.Path).Property | Where-Object { $_ -like $Entry.NamePattern })
        }
    } else {
        $names = @($Entry.Name)
    }

    foreach ($name in $names) {
        if (Test-SuiteIsProtected -Name $name -Manifest $manifest) {
            Write-Host "  [startup] Skipped (Protected) Run entry: $name"
            continue
        }
        if (-not (Test-Path $Entry.Path)) { continue }

        try {
            $value = Get-ItemProperty -Path $Entry.Path -Name $name -ErrorAction Stop |
                Select-Object -ExpandProperty $name -ErrorAction SilentlyContinue
        } catch { $value = $null }
        if ($null -eq $value) {
            Write-Host "  [startup] Already absent: $name"
            continue
        }

        if (-not $PSCmdlet.ShouldProcess($name, "Remove Run autorun")) {
            Write-Host "  [startup] Would remove Run entry: $name"
            continue
        }

        New-SuiteBackupFile -BackupRoot $backupRoot -FileName "run_$(Get-SuiteSafeFileName $name).txt" -Record @{
            Type = 'RunAutorun'; Path = $Entry.Path; Name = $name; Value = $value; Reason = $Entry.Reason
        }

        try {
            Remove-ItemProperty -Path $Entry.Path -Name $name -ErrorAction Stop
            Write-Host "  [startup] Removed Run entry: $name"
        } catch {
            Write-Warning "  [startup] Failed to remove Run entry: $name - $($_.Exception.Message)"
        }
    }
}

foreach ($entry in @($manifest.RunAutoruns)) {
    if ($LoginSafe -and $entry.ExcludeWhenLoginSafe) {
        Write-Host "  [startup] Skipped OneDrive Run autorun (LoginSafe): $($entry.Name)"
        continue
    }
    Disable-SuiteRunAutorun -Entry $entry
}

function Disable-SuiteStartupApproved {
    param([psobject]$Entry)

    $names = @()
    if ($Entry.NamePattern) {
        if (Test-Path $Entry.Path) {
            $names = @((Get-Item -Path $Entry.Path).Property | Where-Object { $_ -like $Entry.NamePattern })
        }
    } else {
        $names = @($Entry.Name)
    }

    foreach ($name in $names) {
        if (Test-SuiteIsProtected -Name $name -Manifest $manifest) {
            Write-Host "  [startup] Skipped (Protected): $name"
            continue
        }
        if (-not (Test-Path $Entry.Path)) {
            Write-Host "  [startup] Already absent: $name (path not found)"
            continue
        }

        try {
            $currentValue = Get-ItemProperty -Path $Entry.Path -Name $name -ErrorAction Stop |
                Select-Object -ExpandProperty $name -ErrorAction SilentlyContinue
        } catch { $currentValue = $null }
        if ($null -eq $currentValue -or -not ($currentValue -is [byte[]])) {
            Write-Host "  [startup] Skipped: $name (value is not a binary StartupApproved flag)"
            continue
        }

        if (-not $PSCmdlet.ShouldProcess($name, "Disable startup app")) {
            Write-Host "  [startup] Would disable: $name"
            continue
        }

        New-SuiteBackupFile -BackupRoot $backupRoot -FileName "startupapproved_$(Get-SuiteSafeFileName $name).txt" -Record @{
            Type = 'StartupApproved'; Path = $Entry.Path; Name = $name
            ValueBase64 = [Convert]::ToBase64String($currentValue); Reason = $Entry.Reason
        }

        try {
            $disabledValue = New-Object byte[]($currentValue.Length)
            if ($disabledValue.Length -gt 0) { $disabledValue[0] = 3 }
            Set-ItemProperty -Path $Entry.Path -Name $name -Value $disabledValue -Type Binary -ErrorAction Stop
            Write-Host "  [startup] Disabled: $name - $($Entry.Reason)"
        } catch {
            Write-Warning "  [startup] Failed to disable startup app $name - $($_.Exception.Message)"
        }
    }
}

foreach ($entry in @($manifest.StartupApproved)) {
    Disable-SuiteStartupApproved -Entry $entry
}

function Disable-SuiteAppModelStartup {
    param([psobject]$Entry)

    if (-not (Test-Path $Entry.Path)) {
        Write-Host "  [startup] Already absent: $($Entry.Reason)"
        return
    }

    $current = $null
    try {
        $current = Get-ItemProperty -Path $Entry.Path -ErrorAction Stop
    } catch {
        Write-Warning "  [startup] Skipping app-model startup task '$($Entry.Reason)': unable to read state"
        return
    }

    $currentState = $current | Select-Object -ExpandProperty $Entry.Name -ErrorAction SilentlyContinue
    if ($null -eq $currentState) {
        Write-Warning "  [startup] Skipping app-model startup task '$($Entry.Reason)': '$($Entry.Name)' state not found"
        return
    }
    $currentState = [int]$currentState

    if (-not $PSCmdlet.ShouldProcess($Entry.Reason, 'Disable app-model startup task')) {
        Write-Host "  [startup] Would disable app-model startup task: $($Entry.Reason)"
        return
    }

    $safeKey = ($Entry.Path -replace '^HKCU:\\', '') -replace '[\\/:*?"<>| ]', '_'
    New-SuiteBackupFile -BackupRoot $backupRoot -FileName "appmodelstartup_$safeKey.txt" -Record @{
        Type = 'AppModelStartup'; Path = $Entry.Path; Name = $Entry.Name; State = $currentState; Reason = $Entry.Reason
        UserEnabledStartupOnce = if ($current.UserEnabledStartupOnce) { [string]$current.UserEnabledStartupOnce } else { '' }
        LastDisabledTime = if ($current.LastDisabledTime) { [string]$current.LastDisabledTime } else { '' }
    }

    try {
        Set-ItemProperty -Path $Entry.Path -Name $Entry.Name -Value $Entry.DisableValue -Type DWord -ErrorAction Stop
        Write-Host "  [startup] Disabled: $($Entry.Reason)"
    } catch {
        Write-Warning "  [startup] Failed to disable app-model startup task '$($Entry.Reason)': $($_.Exception.Message)"
    }
}

foreach ($entry in @($manifest.AppModelStartup)) {
    Disable-SuiteAppModelStartup -Entry $entry
}

if (-not $SkipProcessStops) {
    foreach ($entry in @($manifest.ProcessStops)) {
        if (-not (Test-SuiteEntryApplies -Entry $entry -Profile $Profile)) { continue }
        if (-not (Test-SuiteEntryRiskyAllowed -Entry $entry -AllowRisky:$AllowRisky)) {
            Write-Host "  [proc]    Skipped (Risky - pass -AllowRisky): $($entry.Name)"
            continue
        }
        $running = Get-Process -Name $entry.Name -ErrorAction SilentlyContinue
        if (-not $running) { continue }
        if (Test-SuiteIsProtected -Name $entry.Name -Manifest $manifest) {
            Write-Host "  [proc]    Skipped (Protected): $($entry.Name)"
            continue
        }
        if (-not $PSCmdlet.ShouldProcess($entry.Name, "Stop running process")) {
            Write-Host "  [proc]    Would stop process: $($entry.Name) - $($entry.Reason)"
            continue
        }
        try {
            $running | Stop-Process -Force -ErrorAction Stop
            Write-Host "  [proc]    Stopped: $($entry.Name) - $($entry.Reason)"
        } catch {
            Write-Warning "  [proc]    Failed to stop process $($entry.Name): $($_.Exception.Message)"
        }
    }
}

if ($manifest.VisualEffects) {
    $desktopKey = 'HKCU:\Control Panel\Desktop'
    $visualBackupFile = Join-Path $backupRoot 'visual_effects_desktop.json'
    if (-not $PSCmdlet.ShouldProcess('Visual Effects', 'Set to best-performance mode')) {
        Write-Host "  [visual]  Would set visual effects to best performance (font smoothing kept)"
    } else {
        $desktopProps = Get-ItemProperty -Path $desktopKey -ErrorAction SilentlyContinue
        $visualBackup = [ordered]@{
            Path = $desktopKey
            VisualFXSetting = if ($desktopProps -and $desktopProps.VisualFXSetting -ne $null) { [string]$desktopProps.VisualFXSetting } else { '' }
            DragFullWindows = if ($desktopProps -and $desktopProps.DragFullWindows -ne $null) { [string]$desktopProps.DragFullWindows } else { '' }
            FontSmoothing = if ($desktopProps -and $desktopProps.FontSmoothing -ne $null) { [string]$desktopProps.FontSmoothing } else { '' }
        }
        Set-Content -Path $visualBackupFile -Value (ConvertTo-Json -InputObject $visualBackup -Depth 2) -Encoding UTF8
        Set-ItemProperty -Path $desktopKey -Name 'VisualFXSetting' -Value 3 -Type DWord
        Set-ItemProperty -Path $desktopKey -Name 'DragFullWindows' -Value 0 -Type String
        Set-ItemProperty -Path $desktopKey -Name 'FontSmoothing' -Value 2 -Type String
        Write-Host '  [visual]  Set visual effects to best performance (font smoothing kept)'
    }
}

Write-Host ''
Write-Host "Done. Backups are in $backupRoot"
Write-Host 'A reboot or logoff/logon is needed for visual effect changes to fully apply.'
