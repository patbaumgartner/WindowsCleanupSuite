<#
.SYNOPSIS
    Scheduled re-run support: register/unregister a Windows Task Scheduler task that
    periodically re-runs the full debloat suite (Runners\Run-Menu.ps1 -NonInteractive -Level 4 -Apply as SYSTEM).

.DESCRIPTION
    Use cases:
      - Updates (chocolatey/winget) reinstall apps (e.g. wifi kill apps via drivers)
        -> schedule a weekly re-debloat and do it automatically.
      - "Make the machine fast again from time to time" -> automatic maintenance.
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

function Register-WCSReRunTask {
    <#
        Registers WindowsCleanupSuite_ReRun: daily trigger at -Hour (default 8),
        repeating every -Days (default 7), running the full debloat suite as SYSTEM.
        Returns $true on success.
    #>
    param(
        [ValidateRange(1, 365)][int]$Days = 7,
        [ValidateRange(0, 23)][int]$Hour = 8,
        [switch]$WhatIf
    )

    $root = Get-WCSRoot
    $runScript = Join-Path $root 'Runners\Run-Menu.ps1'
    if (-not (Test-Path $runScript)) { Write-Error "Run-Menu.ps1 not found at $runScript"; return $false }

    $exe = Get-WCSPowerShellExe
    $startDate = (Get-Date -Hour $Hour -Minute 0 -Second 0 -Millisecond 0)
    if ($startDate -le (Get-Date)) { $startDate = $startDate.AddDays(1) }

    $trigger = New-ScheduledTaskTrigger -Once -At $startDate -RepetitionInterval (New-TimeSpan -Days $Days) -RepetitionDuration ([TimeSpan]::MaxValue)
    $action = New-ScheduledTaskAction -Execute $exe -Argument "-File ""$runScript"" -NonInteractive -Level 4 -Apply -AutoApprove"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -WakeToRun

    if ($WhatIf) {
        Write-Host "Would register task '$WCS_ReRunTaskName' (start: $($startDate.ToShortTimeString()), every $Days days, as SYSTEM, cmd: $exe -File $runScript -NonInteractive -Level 4 -Apply -AutoApprove)" -ForegroundColor Cyan
        return $true
    }

    try {
        Register-ScheduledTask -TaskName $WCS_ReRunTaskName -TaskPath '\' -Trigger $trigger -Action $action -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force
        Write-Host "Registered '$WCS_ReRunTaskName': daily at $($startDate.ToShortTimeString()), every $Days days, runs as SYSTEM." -ForegroundColor Green
        Write-Host 'Unregister anytime: Unregister-WCSReRunTask' -ForegroundColor Gray
        return $true
    } catch {
        Write-Warning "Failed to register task: $($_.Exception.Message)"
        return $false
    }
}

function Unregister-WCSReRunTask {
    param([switch]$WhatIf)
    if ($WhatIf) { Write-Host "Would unregister '$WCS_ReRunTaskName'"; return $true }
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
