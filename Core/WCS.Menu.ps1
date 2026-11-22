#requires -Version 5.1
<#
.SYNOPSIS
    Interactive menu for WindowsCleanupSuite: choose Level and Topics, preview or apply.

.DESCRIPTION
    UX entry point. Data comes from Core\WCS.Catalog.ps1. Non-interactive mode:
      Runners\Run-Menu.ps1 -NonInteractive -Level 2 -Topics 'ServicesTasks,PrivacySettings' -Apply
    Interactive mode walks you through level selection, topic toggles and actions.

.PARAMETER Level
    Skip the interactive level menu (non-interactive). Accepts 1-4 or Safe/Balanced/Aggressive/Extreme.

.PARAMETER Topics
    Topics to run (non-interactive). Accepts topic names from the catalog (ServicesTasks,
    PrivacySettings, AI, OneDrive, ExtremeExtras, Maintenance, DNS, WindowsUpdates, PowerPlan).

.PARAMETER Apply
    Actually change system state (requires Administrator). Creates a System Restore point first.

.PARAMETER WhatIf
    Preview without prompting/applying (scripts honor -WhatIf; useful for testing).

.PARAMETER NonInteractive
    Run without any prompts (uses -Level/-Topics or stored defaults); required with -Apply for automation.

.PARAMETER AutoApprove
    With -Apply, skip the confirmation prompt (used by NonInteractive).

.PARAMETER SavePreferences
    Write the selected level+topics to Config\UserPreferences.json (interactive defaults source).

.EXAMPLE
    Runners\Run-Menu.ps1                                     # interactive menu
    Runners\Run-Menu.ps1 -Level 2 -Topics 'ServicesTasks,PrivacySettings'  # non-interactive preview
    Runners\Run-Menu.ps1 -Level 2 -Topics 'ServicesTasks,PrivacySettings' -Apply  # non-interactive apply
#>
[CmdletBinding()]
param(
    [string[]]$Topics,

    [switch]$Apply,

    [switch]$AutoApprove,

    [switch]$NonInteractive,

    [string]$Level,

    [switch]$SavePreferences,

    [switch]$AllowRisky
)

$SuiteRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $SuiteRoot 'Core\CleanupEngine.ps1')
. (Join-Path $SuiteRoot 'Core\WCS.Catalog.ps1')
. (Join-Path $SuiteRoot 'Core\WCS.Updates.ps1')
. (Join-Path $SuiteRoot 'Core\WCS.Scheduler.ps1')

$global:WCS_MenuFailed = $false

# --------------------------------------------------------------------------- helpers

function Write-WCSMenuHeader {
    param([string]$Title, [string]$Subtitle = '')
    Write-Host ''
    Write-Host '==============================================================' -ForegroundColor Blue
    Write-Host "              $Title".PadRight(62) -ForegroundColor Blue
    Write-Host '==============================================================' -ForegroundColor Blue
    if ($Subtitle) { Write-Host "  $Subtitle" -ForegroundColor Gray }
}

function Get-WCSMenuInput {
    <# Read-Host loop that retries up to $MaxTries times and returns $null on empty/timeout. #>
    param([int]$MaxTries = 5, [string]$Prompt)

    for ($i = 0; $i -lt $MaxTries; $i++) {
        $value = Read-Host $Prompt
        if (-not [string]::IsNullOrWhiteSpace([string]$value)) { return ([string]$value).Trim() }
    }
    return $null
}

function Read-WCSPreferences {
    $file = Join-Path (Get-SuiteRoot) 'Config\UserPreferences.json'
    if (-not (Test-Path $file)) { return $null }
    try {
        $content = Get-Content -Raw -Path $file
        if ([string]::IsNullOrWhiteSpace($content)) { return $null }
        return (ConvertFrom-Json $content)
    } catch {
        Write-Warning "  Could not read preferences file ($file): $($_.Exception.Message)"
        return $null
    }
}

function Save-WCSPreferences {
    param([string]$LevelKey, [string[]]$TopicNames)

    try {
        $configDir = Join-Path (Get-SuiteRoot) 'Config'
        if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
        $file = Join-Path $configDir 'UserPreferences.json'
        $prefs = [ordered]@{ Level = $LevelKey; Topics = [string[]]$TopicNames; AutoReRunDays = 7; Created = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') }
        $prefs | ConvertTo-Json | Set-Content -Path $file -Encoding UTF8
        Write-Host "  Saved preferences: $file" -ForegroundColor Gray
    } catch {
        Write-Warning "  Could not save preferences: $($_.Exception.Message)"
    }
}

function Show-WCSLevelMenu {
    Write-WCSMenuHeader 'Choose Level' 'Safe runs everything by default; Aggressive/Extreme add more depth.'
    $prefs = Read-WCSPreferences
    $defaultKey = if ($prefs) { $prefs.Level } else { 'Safe' }

    foreach ($i in 0..3) {
        $level = (Get-WCSLevelDefinitions)[$i]
        if ($level.Key -eq $defaultKey) { $marker = '*' } else { $marker = ' ' }
        Write-Host "  [$($level.Level)]$marker $($level.Label)" -ForegroundColor Cyan
        Write-Host "       $($level.Description)"
    }
    Write-Host '  Type 1, 2, 3 or 4 (or Safe/Balanced/Aggressive/Extreme). [q] to quit.'

    while ($true) {
        $choice = Get-WCSMenuInput -MaxTries 4 -Prompt 'Level'
        if ($null -eq $choice -or $choice -in @('q', 'quit')) { return $null }
        try {
            $key = ConvertFrom-WCSLevelInput -LevelString $choice
            if ($key -in @((Get-WCSLevelDefinitions).Key)) { return $key }
        } catch { }
        Write-Host "  Invalid level: '$choice'. Try 1, 2, 3 or 4." -ForegroundColor Yellow
    }
}

function Show-WCSTopicMenu {
    param([string[]]$Selection)

    Write-WCSMenuHeader 'Choose Topics' 'Topics are the areas you want to cover. Numbers toggle items.'
    $topics = (Get-WCSTopicDefinitions)
    $selection = @($Selection)

    while ($true) {
        $idx = 1
        foreach ($topic in $topics) {
            $marker = if ($selection -contains $topic.Topic) { '[x]' } else { '[ ]' }
            Write-Host "  [$idx] $marker $($topic.Topic) - $($topic.Description)"
            $idx++
        }
        Write-Host '  Type numbers to toggle (e.g. "1 3"), [a]ll, [n]one, or press Enter to accept.'

        $input = Get-WCSMenuInput -MaxTries 6 -Prompt 'Topics'
        if ($null -eq $input -or $input -eq '') { return $selection }
        if ($input -in @('a', 'all')) { $selection = @($topics.Topic); continue }
        if ($input -in @('n', 'none')) { $selection = @(); continue }

        foreach ($token in ($input -split ',')) {
            $token = $token.Trim()
            if (-not ($token -match '^\d+$')) { Write-Host "  Ignoring '$token'." -ForegroundColor Yellow; continue }
            $n = [int]$token
            if ($n -lt 1 -or $n -gt $topics.Count) { Write-Host "  Ignoring out-of-range topic: $n." -ForegroundColor Yellow; continue }
            $name = $topics[$n - 1].Topic
            if ($selection -contains $name) {
                $selection = @($selection | Where-Object { $_ -ne $name })
            } else {
                $selection += $name
            }
        }
        if ($selection.Count) { Write-Host "  Current selection: $($selection -join ', ')" -ForegroundColor Cyan }
    }
}

function Invoke-WCSTopicCleanups {
    <# Runs the cleanup scripts for each selected topic (preview when no -Apply). #>
    param(
        [ValidateSet('Safe', 'Balanced', 'Aggressive', 'Extreme')][string]$LevelKey,
        [string[]]$Topics,
        [switch]$Apply,
        [switch]$AllowRisky
    )

    $level = (Get-WCSLevelByKey $LevelKey)
    $root = Get-SuiteRoot

    foreach ($topicName in $Topics) {
        $topic = @(Get-WCSValidTopicByName -Topic $topicName)[0]
        if (-not $topic) {
            Write-Error "  Unknown topic: $topicName"
            $global:WCS_MenuFailed = $true
            return
        }

        Write-Host "=== $($topic.Topic) ===" -ForegroundColor Magenta
        Write-Host "    $($topic.Description)"

        foreach ($script in $topic.Cleanups) {
            $path = Join-Path $root $script
            if (-not (Test-Path $path)) { Write-Warning "  Missing script: $script"; continue }

            $LASTEXITCODE = $null
            $failed = $false
            try {
                if ($script -eq 'Cleanups\WindowsSpeedup\Disable-ServicesAndTasks.ps1') {
                    # Profile comes from the level; LoginSafe stays on (as before).
                    # Preview = -WhatIf, apply = run without -WhatIf.
                    if ($Apply) { & $path -Profile $level.Profile -LoginSafe -AllowRisky:$AllowRisky } else { & $path -WhatIf -Profile $level.Profile -LoginSafe -AllowRisky:$AllowRisky }
                } elseif ($script -eq 'Cleanups\PrivacySettings\Disable-PrivacySettings.ps1' -or $script -eq 'Cleanups\ExtremeExtras\Disable-ExtremeExtras.ps1') {
                    if ($Apply) { & $path -Level $level.Level } else { & $path -WhatIf -Level $level.Level }
                } elseif ($script -eq 'Cleanups\WindowsUpdates\Disable-WindowsUpdates.ps1') {
                    if ($Apply) { & $path -Level $level.Level } else { & $path -WhatIf -Level $level.Level }
                } elseif ($script -in @('Cleanups\Privacy\Disable-Privacy.ps1', 'Cleanups\Browsers\Disable-Browsers.ps1', 'Cleanups\Network\Disable-Network.ps1')) {
                    # Privacy/Browsers/Network: apply inherently; menu -AllowRisky opts in to Risky items.
                    if ($Apply) { & $path -AllowRisky:$AllowRisky } else { & $path -WhatIf -AllowRisky:$AllowRisky }
                } else {
                    # Other cleanups have SupportsShouldProcess only (no -Apply param):
                    # apply = run without -WhatIf; preview = pass -WhatIf.
                    if ($Apply) { & $path } else { & $path -WhatIf }
                }
            } catch {
                $failed = $true
                Write-Warning "  Script failed: $script - $($_.Exception.Message)"
            }

            if ($failed -or ($LASTEXITCODE -and $LASTEXITCODE -ne 0)) { $global:WCS_MenuFailed = $true }
        }
    }
}

function Show-WCSPlan {
    param([string]$LevelKey, [string[]]$Topics)
    Write-WCSMenuHeader 'Plan' "Level: $((Get-WCSLevelByKey $LevelKey).Label), Topics: $($Topics -join ', ')"
    foreach ($topicName in $Topics) {
        $topic = @(Get-WCSValidTopicByName -Topic $topicName)[0]
        if (-not $topic) { continue }
        Write-Host "  - $($topic.Topic): $($topic.Description)" -ForegroundColor Cyan
    }
    Write-Host ''
    Write-Host '  Run preview (WhatIf, no changes): Runners\Run-Menu.ps1 -Level ... -Topics ...' -ForegroundColor Gray
}

function New-WCSRestorePoint {
    <# Creates a System Restore point when admin; returns bool. #>
    if (-not (Test-SuiteIsAdmin)) {
        Write-Warning '  Could not create System Restore point: Administrator required.'
        return $false
    }
    try {
        Enable-ComputerRestore -Drive $env:SystemDrive -ErrorAction Stop
        $desc = "WindowsCleanupSuite $($(Get-SuiteRoot | Split-Path -Leaf)) - pre-debloat"
        Checkpoint-Computer -Description $desc -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Host '  System Restore point created: WindowsCleanupSuite - pre-debloat' -ForegroundColor Green
        return $true
    } catch {
        Write-Warning "  Could not create System Restore point: $($_.Exception.Message)"
        return $false
    }
}

function Show-WCSHelp {
    Write-WCSMenuHeader 'WindowsCleanupSuite - Help'
    Write-Host @'
  WindowsCleanupSuite debloats & speeds up your Windows installation and
  keeps everything reversible (backups + System Restore points).

  Levels:
    Safe (Recommended)  - Balanced engine profile, privacy, DNS, updates, power plan.
    Balanced            - adds AI and OneDrive topics (visual effects are in ServicesTasks).
    Aggressive          - Maximum profile: more services set Manual/Disabled.
    Extreme             - Maximum + ExtremeExtras (push, Store broker, SMS routing off).

  Topics (choose which areas run):
    ServicesTasks, PrivacySettings, Privacy, Browsers, Network, AI, OneDrive,
    ExtremeExtras, Maintenance, DNS, WindowsUpdates, PowerPlan
    Each topic has a short description; enter 0/Enter in the topic menu to accept
    the default selection for your level. 'Privacy', 'Browsers' and 'Network'
    topics have Risky items; use -AllowRisky in NonInteractive mode to allow them.

  Actions:
    1 Run debloat (preview)          3 Updates + re-debloat afterwards
    2 Apply debloat (needs Admin)    4 Schedule auto re-run (weekly)
    5 Revert/Restore backups         6 Run audits (state/installed/services)
    0 Exit

  CLI (non-interactive):
    Runners\Run-Menu.ps1 -Level 2 -Topics 'ServicesTasks,PrivacySettings'
    Runners\Run-Menu.ps1 -Level 3 -Apply   # level 3, all default topics, apply

  Safety:
    - All changes are backed up (Backups\) and restore scripts (Restore-*.ps1) exist.
    - Use System Restore: powershell -c "(Get-ComputerRestorePoint).SequenceNumber" etc.
    - See README.md for undo and restore-point instructions.
'@
}

function Show-WCSActionMenu {
    Write-WCSMenuHeader 'Actions'
    Write-Host '  [1] Run debloat preview (no changes)' -ForegroundColor Cyan
    Write-Host '  [2] Apply debloat (requires Administrator)' -ForegroundColor Cyan
    Write-Host '  [3] Run updates (winget/choco) + re-debloat afterwards' -ForegroundColor Cyan
    Write-Host '  [4] Schedule auto re-run (weekly)' -ForegroundColor Cyan
    Write-Host '  [5] Revert / restore backups (Tools\Restore-WCSBackup.ps1)' -ForegroundColor Cyan
    Write-Host '  [6] Run audits (state / installed software)' -ForegroundColor Cyan
    Write-Host '  [h] Help' -ForegroundColor Cyan
    Write-Host '  [0] Exit' -ForegroundColor Cyan
    return Get-WCSMenuInput -MaxTries 4 -Prompt 'Action'
}

function Invoke-WCSActionMenu {
    param([string]$LevelKey, [string[]]$Topics, [switch]$AllowRisky)

    while ($true) {
        $choice = Show-WCSActionMenu
        switch ($choice) {
            '1' {
                Show-WCSPlan -LevelKey $LevelKey -Topics $Topics
                Invoke-WCSTopicCleanups -LevelKey $LevelKey -Topics $Topics -AllowRisky:$AllowRisky
            }
            '2' {
                Show-WCSPlan -LevelKey $LevelKey -Topics $Topics
                New-WCSRestorePoint
                Invoke-WCSTopicCleanups -LevelKey $LevelKey -Topics $Topics -Apply -AllowRisky:$AllowRisky
                Write-Host '  Done. Backups are in Backups\ and restore scripts exist for rollback.' -ForegroundColor Green
            }
            '3' {
                $updates = Invoke-WCSUpdateManager
                if (-not $updates.Success) {
                    Write-Warning "  Updates did not fully succeed ($($updates.Manager)). Skipping re-debloat."
                } else {
                    Invoke-WCSDebloatAfterUpdates -Apply -Level $LevelKey
                }
            }
            '4' {
                Register-WCSReRunTask -Days 7
            }
            '5' {
                $toolPath = Join-Path (Get-SuiteRoot) 'Tools\Restore-WCSBackup.ps1'
                if (Test-Path $toolPath) { & $toolPath -Backups } else { Write-Warning "  Missing: Tools\Restore-WCSBackup.ps1" }
            }
            '6' {
                foreach ($script in @('Audit\Audit-State.ps1', 'Audit\Audit-InstalledSoftware.ps1')) {
                    $path = Join-Path (Get-SuiteRoot) $script
                    if (Test-Path $path) { & $path }
                }
            }
            'h' { Show-WCSHelp }
            default {
                Write-Host '  Invalid or empty input - type a number between 0 and 6.' -ForegroundColor Yellow
            }
        }
        if ($choice -in @('0', '') -or $null -eq $choice) {
            return
        }
    }
}

# --------------------------------------------------------------------------- main

Write-WCSMenuHeader 'WindowsCleanupSuite' 'Debloat & accelerate your Windows - Levels + Topics, everything reversible.'
if (-not (Test-SuiteIsAdmin)) {
    Write-Host '  Note: changes need Administrator; preview mode works without it.' -ForegroundColor DarkGray
}

# Determine LevelKey
$levelKey = $null
if ($Level) {
    try { $levelKey = ConvertFrom-WCSLevelInput -LevelString $Level } catch { Write-Error "  Invalid -Level: $Level ($($_.Exception.Message))"; exit 1 }
}

# Determine topics (validate CLI values; default to defaults when not given)
# Accepts comma-separated strings, so both "-Topics 'A,B'" and "-Topics 'A','B'" work.
$topicNames = $null
if ($Topics) {
    $expanded = @()
    foreach ($t in $Topics) {
        foreach ($part in ($t -split ',')) {
            $clean = $part.Trim().Trim(@("'", '"'))
            if ($clean) { $expanded += $clean }
        }
    }
    $valid = @((Get-WCSValidTopicNames))
    foreach ($t in $expanded) {
        if ($t -notin $valid) {
            Write-Error "  Invalid topic: '$t'. Valid topics: $($valid -join ', ')"
            exit 1
        }
    }
    $topicNames = @($expanded)
}

if ($NonInteractive) {
    $levelKey = if ($levelKey) { $levelKey } else {
        $prefs = Read-WCSPreferences
        if ($prefs -and $prefs.Level) { ConvertFrom-WCSLevelInput -LevelString $prefs.Level } else { 'Safe' }
    }
    $topicNames = if ($topicNames) { $topicNames } else {
        $prefs = Read-WCSPreferences
        $default = @(Get-WCSDefaultTopicSelection -LevelKey $levelKey)
        if ($prefs -and $prefs.Topics) { @($prefs.Topics) } else { $default }
    }

    Write-WCSMenuHeader 'Non-interactive run' "Level: $((Get-WCSLevelByKey $levelKey).Label), Topics: $($topicNames -join ', '), Mode: $(if ($Apply) { 'APPLY' } else { 'PREVIEW' })"

    if ($Apply) {
        if (-not (Test-SuiteIsAdmin)) {
            Write-Error '  -Apply requires Administrator privileges. Elevate with "Run as Administrator".'
            exit 1
        }
        New-WCSRestorePoint
        Invoke-WCSTopicCleanups -LevelKey $levelKey -Topics $topicNames -Apply -AllowRisky:$AllowRisky
        Write-Host '  Done.' -ForegroundColor Green
    } else {
        Invoke-WCSTopicCleanups -LevelKey $levelKey -Topics $topicNames -AllowRisky:$AllowRisky
        Write-Host '  Preview done - nothing was modified (use -Apply to change state).' -ForegroundColor Gray
    }

    if ($SavePreferences) { Save-WCSPreferences -LevelKey $levelKey -TopicNames $topicNames }
}
else {
    if (-not $levelKey) { $levelKey = Show-WCSLevelMenu; if (-not $levelKey) { exit 0 } }
    $prefs = Read-WCSPreferences
    $topicNames = @(Show-WCSTopicMenu -Selection (@(if ($topicNames) { @($topicNames) } else { @(Get-WCSDefaultTopicSelection -LevelKey $levelKey) })))
    if (-not $topicNames.Count) { Write-Host 'No topics selected - nothing to run. Exiting.' -ForegroundColor Yellow; exit 0 }

    Write-Host ''
    Show-WCSPlan -LevelKey $levelKey -Topics $topicNames

    Write-Host ''
    if ($Apply) {
        if (-not (Test-SuiteIsAdmin)) {
            Write-Error '  -Apply requires Administrator privileges. Elevate with "Run as Administrator".'
            exit 1
        }
        Show-WCSPlan -LevelKey $levelKey -Topics $topicNames
        New-WCSRestorePoint
        Invoke-WCSTopicCleanups -LevelKey $levelKey -Topics $topicNames -Apply -AllowRisky:$AllowRisky
        Write-Host '  Done. Backups are in Backups\ and restore scripts exist for rollback.' -ForegroundColor Green
    } else {
        Invoke-WCSActionMenu -LevelKey $levelKey -Topics $topicNames -AllowRisky:$AllowRisky
    }

    if ($SavePreferences) { Save-WCSPreferences -LevelKey $levelKey -TopicNames $topicNames }
}

if ($global:WCS_MenuFailed) { exit 1 }
