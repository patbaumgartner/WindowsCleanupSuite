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
        are removed/disabled (backed up first), including the per-user Run32
        overlay that toggles 32-bit HKLM Run entries such as Dropbox.
      - AppModel startup tasks are discovered from the installed package manifests
        (Task IDs change with updates, e.g. WhatsApp uses a GUID) and disabled.
      - Startup/versioned app updater tasks are matched by their executable path.
      - Already-running heavy/background apps and already-Manual but still-running
        services are stopped.
      - Visual effects are set to best-performance (font smoothing kept).

    Protected components (Intel Driver & Support Assistant, DSA tasks, etc.) are
    NEVER modified, in any profile or mode. Requires Administrator for service
    changes. The menu passes -WhatIf for previews; run without -WhatIf to apply.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.PARAMETER Profile
    Optimization strictness: Balanced (safe) or Maximum (aggressive).

.PARAMETER LoginSafe
    Keeps login/session-critical *services* enabled: csc_vpnagent, CtxsDPS,
    CWAUpdaterService, WSearch. OneDrive auto-start is always disabled (manual
    launch and local files still work).

.PARAMETER SkipProcessStops
    Skips stopping already-running user applications at the end of the run.

.PARAMETER AllowRisky
    Also apply entries flagged Risky = $true in the manifest
    (VPN/Citrix services, Windows Search indexing, cross-device platform).

.PARAMETER Quick
    Fast preview: exact-name service/task entries are probed directly
    (Get-Service -Name / Get-ScheduledTask -TaskPath+TaskName) instead of enumerating
    every service/task on the machine; pattern entries still need the full enumeration.

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

    [switch]$AllowRisky,

    [switch]$Quick
)

if ($Quick -and -not $WhatIfPreference) {
    Write-Error '-Quick is a preview-only fast mode and cannot be combined with apply mode. Use -WhatIf or drop -Quick.'
    exit 1
}

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
    if ($Quick -and -not $Entry.NamePattern) {
        # -Quick: probe the exact service name directly instead of enumerating all services.
        try { $matches = @(Get-Service -Name $Entry.Name -ErrorAction Stop) } catch { $matches = @() }
    } elseif ($Entry.NamePattern) {
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

        $alreadyManual = ([int]$start -eq 3)
        $isRunning = ($svc.Status -eq 'Running')
        if ($alreadyManual -and -not $isRunning) {
            Write-Host "  [service] Already Manual: $($svc.Name) - $($Entry.Reason)"
            continue
        }

        if (-not $PSCmdlet.ShouldProcess($svc.Name, "Set start type to Manual and stop ($($Entry.Reason))")) {
            Write-Host "  [service] Would disable: $($svc.Name) - $($Entry.Reason)"
            continue
        }

        if (-not $alreadyManual) {
            New-SuiteBackupFile -BackupRoot $backupRoot -FileName "svc_$($svc.Name).txt" -Record @{
                Type = 'Service'; Name = $svc.Name; StartType = [int]$start; Reason = $Entry.Reason
            }
            try {
                Set-Service -Name $svc.Name -StartupType Manual -ErrorAction Stop
                Write-Host "  [service] Disabled: $($svc.Name) - $($Entry.Reason)"
            } catch {
                try {
                    Set-ItemProperty -Path $regPath -Name 'Start' -Value 3 -Type DWord -ErrorAction Stop
                    Write-Host "  [service] Disabled via registry: $($svc.Name) - $($Entry.Reason)"
                } catch {
                    Write-Warning "  [service] Failed to change $($svc.Name): $($_.Exception.Message)"
                }
            }
        }

        # Manual alone does not stop a service that is already running this session.
        if ($isRunning) {
            try {
                Stop-Service -Name $svc.Name -Force -ErrorAction Stop
                Write-Host "  [service] Stopped running service: $($svc.Name)"
            } catch {
                Write-Warning "  [service] Failed to stop $($svc.Name): $($_.Exception.Message)"
            }
        }
    }
}

foreach ($entry in @($manifest.Services)) {
    if (-not (Test-SuiteEntryApplies -Entry $entry -Profile $Profile)) { continue }
    if ($LoginSafe -and (Test-SuiteLoginSafeExcluded -Entry $entry -LoginSafeExclusions $manifest.LoginSafeExclusions)) {
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
    if ($Quick -and -not $Entry.NamePattern) {
        # -Quick: probe the exact task path\name directly instead of enumerating all tasks.
        try { $matches = @(Get-ScheduledTask -TaskName $Entry.Name -TaskPath $Entry.Path -ErrorAction Stop) } catch { $matches = @() }
    } elseif ($Entry.NamePattern) {
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

# OneDrive background/update/startup tasks (names vary by SID). These launch
# OneDrive even when its Run value is disabled, so LoginSafe never protects them.
if ($Quick) {
    Write-Host '  [task]    Skipped OneDrive pattern scan (-Quick)'
} else {
    $oneDriveTasks = @(Get-SuiteCachedTasks |
        Where-Object {
            $_.TaskName -eq 'OneDrive Per-Machine Standalone Update Task' -or
            $_.TaskName -like 'OneDrive Reporting Task-*' -or
            $_.TaskName -like 'OneDrive Startup Task-*'
        })
    foreach ($task in $oneDriveTasks) {
        Disable-SuiteScheduledTask -Entry ([pscustomobject]@{ Path = $task.TaskPath; Name = $task.TaskName; Reason = 'OneDrive background/update task' })
    }
}

# Versioned updater tasks: match by the executable they run, not by task name.
if ($Quick) {
    Write-Host '  [task]    Skipped app executable task scan (-Quick)'
} elseif (@($manifest.TaskActionPatterns).Count -gt 0) {
    $seenTasks = @{}
    foreach ($task in @(Get-SuiteCachedTasks)) {
        $exe = @($task.Actions | ForEach-Object { [string]$_.Execute }) -join ' '
        foreach ($pattern in @($manifest.TaskActionPatterns)) {
            if ($exe -like "*$($pattern.Pattern)*") {
                $key = "$($task.TaskPath)$($task.TaskName)"
                if ($seenTasks.ContainsKey($key)) { break }
                $seenTasks[$key] = $true
                Disable-SuiteScheduledTask -Entry ([pscustomobject]@{
                    Path = $task.TaskPath; Name = $task.TaskName; Reason = $pattern.Reason
                })
                break
            }
        }
    }
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
    # LoginSafe protects login-critical *services* only. OneDrive/Microsoft.Lists
    # auto-start is always removed: the files stay local and OneDrive can still
    # be launched manually from the Start menu.
    Disable-SuiteRunAutorun -Entry $entry
}

function Disable-SuiteStartupApproved {
    param([psobject]$Entry)

    if ($Entry.Path -like 'HKLM:*' -and -not $isAdmin) {
        Write-Host "  [startup] Skipped StartupApproved key $($Entry.Path) (requires elevation)"
        return
    }

    $names = @()
    if ($Entry.NamePattern) {
        if (Test-Path $Entry.Path) {
            $names = @((Get-Item -Path $Entry.Path).Property | Where-Object { $_ -like $Entry.NamePattern })
        }
    } else {
        $names = @($Entry.Name)
    }

    foreach ($name in $names) {
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if (Test-SuiteIsProtected -Name $name -Manifest $manifest) {
            Write-Host "  [startup] Skipped (Protected): $name"
            continue
        }

        # Get-ItemProperty | Select-Object would turn REG_BINARY into Object[] on
        # PS 5.1, making the byte[] check fail for every entry. Use the provider.
        $currentValue = Get-WCSRegistryBinaryValue -Path $Entry.Path -Name $name
        if ($null -ne $currentValue -and -not (Test-WCSStartupDisabledFlag -Value $currentValue)) {
            Write-Host "  [startup] Already disabled: $name"
            continue
        }

        if (-not $PSCmdlet.ShouldProcess($name, 'Disable startup app')) {
            Write-Host "  [startup] Would disable: $name"
            continue
        }

        New-SuiteBackupFile -BackupRoot $backupRoot -FileName "startupapproved_$(Get-SuiteSafeFileName $Entry.Path)_$(Get-SuiteSafeFileName $name).txt" -Record @{
            Type = 'StartupApproved'; Path = $Entry.Path; Name = $name
            ValueBase64 = if ($null -eq $currentValue) { '' } else { [Convert]::ToBase64String($currentValue) }
            Existed = ($null -ne $currentValue); Reason = $Entry.Reason
        }

        try {
            if (-not (Test-Path $Entry.Path)) { New-Item -Path $Entry.Path -Force | Out-Null }
            Set-ItemProperty -Path $Entry.Path -Name $name -Value (New-WCSStartupDisabledFlag -Existing $currentValue) -Type Binary -ErrorAction Stop
            Write-Host "  [startup] Disabled: $name - $($Entry.Reason)"
        } catch {
            Write-Warning "  [startup] Failed to disable startup app $name - $($_.Exception.Message)"
        }
    }
}

foreach ($entry in @($manifest.StartupApproved)) {
    Disable-SuiteStartupApproved -Entry $entry
}

function Get-WCSPackagedStartupTasks {
    # Read the CURRENT TaskId from each installed package manifest. Task IDs are
    # frequently GUIDs and change on update (WhatsApp, for example), so static
    # registry paths silently stop working after an app update.
    $found = @()
    foreach ($pkg in @(Get-AppxPackage -ErrorAction SilentlyContinue)) {
        $pkgManifest = $null
        try { $pkgManifest = $pkg | Get-AppxPackageManifest -ErrorAction Stop } catch { continue }
        if ($null -eq $pkgManifest) { continue }
        $extensions = @()
        try { $extensions = @($pkgManifest.Package.Applications.Application.Extensions.Extension) } catch { $extensions = @() }
        foreach ($ext in $extensions) {
            if ($null -eq $ext -or $ext.Category -ne 'windows.startupTask') { continue }
            $startupTask = $ext.StartupTask
            if ($null -eq $startupTask -or -not $startupTask.TaskId) { continue }
            $taskId = [string]$startupTask.TaskId
            $found += [pscustomobject]@{
                PackageFamilyName = [string]$pkg.PackageFamilyName
                TaskId            = $taskId
                Path              = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\$($pkg.PackageFamilyName)\$taskId"
            }
        }
    }
    return $found
}

function Disable-SuiteAppModelStartup {
    param([psobject]$Entry)

    $taskPath = [string]$Entry.Path
    $taskName = if ($Entry.Name) { [string]$Entry.Name } else { 'State' }
    $disableValue = if ($null -ne $Entry.DisableValue) { [int]$Entry.DisableValue } else { 1 }

    if (-not (Test-Path $taskPath)) {
        Write-Host "  [startup] Already absent: $($Entry.Reason)"
        return
    }

    $current = $null
    try {
        $current = Get-ItemProperty -Path $taskPath -ErrorAction Stop
    } catch {
        Write-Warning "  [startup] Skipping app-model startup task '$($Entry.Reason)': unable to read state"
        return
    }

    $currentState = $current.($taskName)
    if ($null -eq $currentState) {
        Write-Host "  [startup] Already absent: $($Entry.Reason) (no $taskName value)"
        return
    }
    $currentState = [int]$currentState
    # State 1 = DisabledByUser; 0 = Disabled; 2 = Enabled (WinRT StartupTaskState).
    if ($currentState -eq 0 -or $currentState -eq 1 -or $currentState -eq 3) {
        Write-Host "  [startup] Already disabled: $($Entry.Reason)"
        return
    }

    if (-not $PSCmdlet.ShouldProcess($taskPath, 'Disable app-model startup task')) {
        Write-Host "  [startup] Would disable app-model startup task: $($Entry.Reason)"
        return
    }

    $safeKey = ($taskPath -replace '^HKCU:\\', '') -replace '[\\/:*?"<>| ]', '_'
    # Record value EXISTENCE as well as content: an existing 0 must not be confused
    # with an absent value, and restore must delete values that were absent before.
    $hasUserEnabled = $current.PSObject.Properties.Name -contains 'UserEnabledStartupOnce'
    $hasLastDisabled = $current.PSObject.Properties.Name -contains 'LastDisabledTime'
    New-SuiteBackupFile -BackupRoot $backupRoot -FileName "appmodelstartup_$safeKey.txt" -Record @{
        Type = 'AppModelStartup'; Path = $taskPath; Name = $taskName; State = $currentState; Reason = $Entry.Reason
        UserEnabledStartupOnce = if ($hasUserEnabled) { [string]$current.UserEnabledStartupOnce } else { '' }
        UserEnabledStartupOnceExists = [bool]$hasUserEnabled
        LastDisabledTime = if ($hasLastDisabled) { [string]$current.LastDisabledTime } else { '' }
        LastDisabledTimeExists = [bool]$hasLastDisabled
    }

    try {
        Set-ItemProperty -Path $taskPath -Name $taskName -Value $disableValue -Type DWord -ErrorAction Stop
        Write-Host "  [startup] Disabled: $($Entry.Reason)"
    } catch {
        Write-Warning "  [startup] Failed to disable app-model startup task '$($Entry.Reason)': $($_.Exception.Message)"
    }
}

$discoveredStartupTasks = @(Get-WCSPackagedStartupTasks)
$processedStartupTasks = @{}
foreach ($entry in @($manifest.AppModelStartup)) {
    if ($entry.PackageFamilyPattern) {
        foreach ($task in @($discoveredStartupTasks | Where-Object { $_.PackageFamilyName -like $entry.PackageFamilyPattern })) {
            $key = $task.Path.ToLowerInvariant()
            if ($processedStartupTasks.ContainsKey($key)) { continue }
            $processedStartupTasks[$key] = $true
            Disable-SuiteAppModelStartup -Entry ([pscustomobject]@{
                Path = $task.Path; Name = 'State'; DisableValue = 1; Reason = $entry.Reason
            })
        }
    } elseif ($entry.Path) {
        $key = ([string]$entry.Path).ToLowerInvariant()
        if ($processedStartupTasks.ContainsKey($key)) { continue }
        $processedStartupTasks[$key] = $true
        Disable-SuiteAppModelStartup -Entry $entry
    }
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
            VisualFXSettingExists = [bool]($desktopProps -and $desktopProps.PSObject.Properties.Name -contains 'VisualFXSetting')
            DragFullWindows = if ($desktopProps -and $desktopProps.DragFullWindows -ne $null) { [string]$desktopProps.DragFullWindows } else { '' }
            DragFullWindowsExists = [bool]($desktopProps -and $desktopProps.PSObject.Properties.Name -contains 'DragFullWindows')
            FontSmoothing = if ($desktopProps -and $desktopProps.FontSmoothing -ne $null) { [string]$desktopProps.FontSmoothing } else { '' }
            FontSmoothingExists = [bool]($desktopProps -and $desktopProps.PSObject.Properties.Name -contains 'FontSmoothing')
        }
        # Preserve the ORIGINAL visual-effects backup across repeated runs.
        if (-not (Test-Path $visualBackupFile)) {
            Set-Content -Path $visualBackupFile -Value (ConvertTo-Json -InputObject $visualBackup -Depth 2) -Encoding UTF8
        }
        Set-ItemProperty -Path $desktopKey -Name 'VisualFXSetting' -Value 3 -Type DWord
        Set-ItemProperty -Path $desktopKey -Name 'DragFullWindows' -Value 0 -Type String
        Set-ItemProperty -Path $desktopKey -Name 'FontSmoothing' -Value 2 -Type String
        Write-Host '  [visual]  Set visual effects to best performance (font smoothing kept)'
    }
}

Write-Host ''
Write-Host "Done. Backups are in $backupRoot"
Write-Host 'A reboot or logoff/logon is needed for visual effect changes to fully apply.'
