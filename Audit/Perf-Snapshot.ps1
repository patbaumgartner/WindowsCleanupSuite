#requires -Version 5.1
<#
.SYNOPSIS
    Read-only performance snapshot: boot time/uptime, active power plan,
    hibernation availability, disk usage, RAM/CPU, top processes, service count.

.DESCRIPTION
    Prints a report and writes a JSON snapshot to Logs\<timestamp>-perf-<phase>.json
    so runs can be compared before/after a cleanup. Runners\Run-Cleanup.ps1 calls
    this with -Phase Before and -Phase After. Fully read-only.

.PARAMETER Phase
    Label stored with the snapshot: Before, After or Standalone (default).

.EXAMPLE
    & 'WindowsCleanupSuite\Audit\Perf-Snapshot.ps1' -Phase Before
#>
[CmdletBinding()]
param(
    [ValidateSet('Before', 'After', 'Standalone')]
    [string]$Phase = 'Standalone'
)

$SuiteRoot = Split-Path -Parent $PSScriptRoot
$LogsRoot  = Join-Path $SuiteRoot 'Logs'
if (-not (Test-Path $LogsRoot)) { New-Item -ItemType Directory -Path $LogsRoot -Force | Out-Null }

$ts   = Get-Date -Format 'yyyyMMdd-HHmmss'
$now  = Get-Date
$os   = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
$boot = if ($os) { [datetime]$os.LastBootUpTime } else { $null }
$uptime = if ($boot) { $now - $boot } else { $null }

# Power plan + available sleep states (hibernate).
$powercfg = Join-Path $env:SystemRoot 'System32\powercfg.exe'
$activePlan = if (Test-Path $powercfg) { (& $powercfg /getactivescheme) -join ' ' } else { 'unknown' }
$availStates = if (Test-Path $powercfg) { @(& $powercfg /a) } else { @() }
$hibernateAvailable = [bool]($availStates -match 'Hibernate')

# Disks (fixed drives).
$disks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue |
    Select-Object DeviceID,
        @{ n = 'SizeGB'; e = { [math]::Round($_.Size / 1GB, 1) } },
        @{ n = 'FreeGB'; e = { [math]::Round($_.FreeSpace / 1GB, 1) } },
        @{ n = 'FreePct'; e = { if ($_.Size) { [math]::Round(100 * $_.FreeSpace / $_.Size, 1) } else { $null } } })

# Memory / CPU.
$memTotalGB = if ($os) { [math]::Round($os.TotalVisibleMemorySize / 1MB, 1) } else { $null }
$memFreeGB  = if ($os) { [math]::Round($os.FreePhysicalMemory / 1MB, 1) } else { $null }
$memUsedPct = if ($memTotalGB -and $memFreeGB -ne $null) { [math]::Round(100 * ($memTotalGB - $memFreeGB) / $memTotalGB, 1) } else { $null }
$cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1

# Top processes by cumulative CPU and by working set.
$topCpu = @(Get-Process | Sort-Object CPU -Descending | Select-Object -First 8 |
    Select-Object Name, Id, @{ n = 'CPU_s'; e = { [math]::Round($_.CPU, 1) } }, @{ n = 'WS_MB'; e = { [math]::Round($_.WorkingSet64 / 1MB, 0) } })
$topMem = @(Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 8 |
    Select-Object Name, Id, @{ n = 'WS_MB'; e = { [math]::Round($_.WorkingSet64 / 1MB, 0) } })

# Services.
$allServices = @(Get-Service -ErrorAction SilentlyContinue)
$svcRunning  = @($allServices | Where-Object { $_.Status -eq 'Running' }).Count
$svcTotal    = $allServices.Count

$snapshot = [ordered]@{
    Timestamp          = $now.ToString('yyyy-MM-dd HH:mm:ss')
    Phase              = $Phase
    LastBootUpTime     = if ($boot) { $boot.ToString('yyyy-MM-dd HH:mm:ss') } else { $null }
    Uptime             = if ($uptime) { $uptime.ToString('d\.hh\:mm\:ss') } else { $null }
    ActivePowerPlan    = $activePlan
    HibernateAvailable = $hibernateAvailable
    Disks              = $disks
    MemoryGB           = @{ Total = $memTotalGB; Free = $memFreeGB; UsedPct = $memUsedPct }
    CPU                = if ($cpu) { @{ Name = $cpu.Name; LoadPct = $cpu.LoadPercentage } } else { $null }
    TopByCpu           = $topCpu
    TopByMemory        = $topMem
    Services           = @{ Running = $svcRunning; Total = $svcTotal }
}

Write-Host "=== Perf Snapshot ($Phase) - $($snapshot.Timestamp) ==="
Write-Host ("Last boot: {0}   Uptime: {1}" -f $snapshot.LastBootUpTime, $snapshot.Uptime)
Write-Host ("Power plan: {0}   Hibernate available: {1}" -f $snapshot.ActivePowerPlan, $snapshot.HibernateAvailable)
Write-Host ("Memory: {0} GB total, {1} GB free ({2}% used)" -f $memTotalGB, $memFreeGB, $memUsedPct)
if ($cpu) { Write-Host ("CPU: {0} (load {1}%)" -f $cpu.Name, $cpu.LoadPercentage) }
Write-Host 'Disks:'
$disks | Format-Table -AutoSize | Out-String | Write-Host
Write-Host ("Services: {0} running of {1}" -f $svcRunning, $svcTotal)
Write-Host 'Top processes by CPU:'
$topCpu | Format-Table -AutoSize | Out-String | Write-Host
Write-Host 'Top processes by memory:'
$topMem | Format-Table -AutoSize | Out-String | Write-Host

$outFile = Join-Path $LogsRoot "$ts-perf-$($Phase.ToLower()).json"
$snapshot | ConvertTo-Json -Depth 5 | Set-Content -Path $outFile -Encoding UTF8
Write-Host "Snapshot written: $outFile"
