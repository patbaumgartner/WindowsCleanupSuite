#requires -Version 5.1
<#
.SYNOPSIS
    Scheduled re-run support: register/unregister a Windows Task Scheduler task that
    periodically re-runs the debloat suite (Runners\Run-Menu.ps1 -NonInteractive -Apply as SYSTEM).

.DESCRIPTION
    The task honors Config\UserPreferences.json:
      - AutoReRunDays = repetition interval in days. Register-WCSReRunTask -Days -1
        resolves it (fallback 7); -Days 0 unregisters the task instead.
      - Level / Topics  = the scheduled command line (fallback: -Level 4, level defaults).
    Registering as SYSTEM requires Administrator; non-admin callers get a clear warning
    (use -WhatIf to preview the registration).
    Task name: WindowsCleanupSuite_ReRun
#>

$WCS_ReRunTaskName = 'WindowsCleanupSuite_ReRun'

function Get-WCSRoot { return Split-Path -Parent $PSScriptRoot }

function Get-WCSPowerShellExe {
    $name = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    return (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')
}

function Test-WCSIsAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WCSReRunPreferences {
    <# Reads Config\UserPreferences.json; returns $null when missing or unreadable. #>
    $file = Join-Path (Get-WCSRoot) 'Config\UserPreferences.json'
    if (-not (Test-Path $file)) { return $null }
    try {
        $content = Get-Content -Raw -Path $file -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($content)) { return $null }
        return (ConvertFrom-Json -InputObject $content -ErrorAction Stop)
    } catch { return $null }
}

function Get-WCSReRunDays {
    <# Effective interval in days: -1 -> AutoReRunDays from prefs (fallback 7). #>
    param([int]$Days = -1, [psobject]$Prefs = $null)
    if ($Days -ge 0) { return $Days }
    if ($null -eq $Prefs) { $Prefs = Get-WCSReRunPreferences }
    if ($Prefs -and $Prefs.AutoReRunDays) {
        $d = 0
        if ([int]::TryParse([string]$Prefs.AutoReRunDays, [ref]$d) -and $d -gt 0) { return $d }
    }
    return 7
}

function Get-WCSReRunActionArguments {
    <# Run-Menu.ps1 argument string for the scheduled task; honors stored Level/Topics. #>
    param([psobject]$Prefs = $null)
    if ($null -eq $Prefs) { $Prefs = Get-WCSReRunPreferences }
    $levelArg = if ($Prefs -and $Prefs.Level) { [string]$Prefs.Level } else { '4' }
    $arg = "-NonInteractive -Level $levelArg -Apply -AutoApprove"
    if ($Prefs -and $Prefs.Topics -and @($Prefs.Topics).Count) {
        $topics = (@($Prefs.Topics) | ForEach-Object { [string]$_ }) -join ','
        $arg += " -Topics '$topics'"
    }
    return $arg
}

function Register-WCSReRunTask {
    <#
        Registers WindowsCleanupSuite_ReRun: trigger at -Hour, repeating every -Days days,
        running the stored Level/Topics from Config\UserPreferences.json as SYSTEM.
        -Days -1 resolves AutoReRunDays from the prefs (fallback 7); -Days 0 unregisters.
        Returns $true on success.
    #>
    param(
        [ValidateRange(-1, 365)][int]$Days = -1,
        [ValidateRange(0, 23)][int]$Hour = 8,
        [switch]$WhatIf
    )

    if ($Days -eq 0) { return (Unregister-WCSReRunTask -WhatIf:$WhatIf) }

    $prefs = Get-WCSReRunPreferences
    $days = Get-WCSReRunDays -Days $Days -Prefs $prefs
    $root = Get-WCSRoot
    $runScript = Join-Path $root 'Runners\Run-Menu.ps1'
    if (-not (Test-Path $runScript)) { Write-Error "Run-Menu.ps1 not found at $runScript"; return $false }

    $exe = Get-WCSPowerShellExe
    $actionArgs = Get-WCSReRunActionArguments -Prefs $prefs
    $startDate = (Get-Date -Hour $Hour -Minute 0 -Second 0 -Millisecond 0)
    if ($startDate -le (Get-Date)) { $startDate = $startDate.AddDays(1) }

    $trigger = New-ScheduledTaskTrigger -Once -At $startDate -RepetitionInterval (New-TimeSpan -Days $days) -RepetitionDuration ([TimeSpan]::MaxValue)
    $action = New-ScheduledTaskAction -Execute $exe -Argument "-File `"$runScript`" $actionArgs"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -WakeToRun

    $summary = "task '$WCS_ReRunTaskName' (start $($startDate.ToShortTimeString()), every $days day(s), as SYSTEM, cmd: $exe -File $runScript $actionArgs)"
    if ($WhatIf) {
        Write-Host "Would register $summary" -ForegroundColor Cyan
        return $true
    }
    if (-not (Test-WCSIsAdmin)) {
        Write-Warning "Registering '$WCS_ReRunTaskName' as SYSTEM requires Administrator - run elevated. Preview with: Register-WCSReRunTask -Days $days -WhatIf"
        return $false
    }

    try {
        Register-ScheduledTask -TaskName $WCS_ReRunTaskName -TaskPath '\' -Trigger $trigger -Action $action -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force
        Write-Host "Registered $summary" -ForegroundColor Green
        Write-Host 'Unregister anytime: Unregister-WCSReRunTask (or Runners\Run-Menu.ps1 -ScheduleDays 0).' -ForegroundColor Gray
        return $true
    } catch {
        Write-Warning "Failed to register task: $($_.Exception.Message)"
        return $false
    }
}

function Unregister-WCSReRunTask {
    param([switch]$WhatIf)
    if ($WhatIf) { Write-Host "Would unregister '$WCS_ReRunTaskName'"; return $true }
    if (-not (Test-WCSIsAdmin)) {
        Write-Warning "Unregistering '$WCS_ReRunTaskName' requires Administrator - run elevated."
        return $false
    }
    try {
        Unregister-ScheduledTask -TaskName $WCS_ReRunTaskName -Confirm:$false -ErrorAction Stop
        Write-Host "Unregistered '$WCS_ReRunTaskName'." -ForegroundColor Green
        return $true
    } catch {
        if ($_.Exception.Message -match 'not found' -or $null -eq $_) {
            Write-Host "Task '$WCS_ReRunTaskName' is not registered." -ForegroundColor Gray
            return $true
        }
        Write-Warning "Failed to unregister: $($_.Exception.Message)"
        return $false
    }
}

function Get-WCSReRunTask {
    <# Returns the task or $null. #>
    try { return Get-ScheduledTask -TaskName $WCS_ReRunTaskName -ErrorAction SilentlyContinue } catch { return $null }
}
