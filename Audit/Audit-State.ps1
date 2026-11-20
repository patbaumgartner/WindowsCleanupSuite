#requires -Version 5.1
<#
.SYNOPSIS
    Read-only post-run audit of the WindowsCleanupSuite.

.DESCRIPTION
    Prints the current state of services, scheduled tasks and Run entries from
    the WindowsSpeedup manifest, with an expectation column.
#>
[CmdletBinding()]
param(
    [ValidateSet('Balanced', 'Maximum')]
    [string]$Profile = 'Balanced',
    [switch]$LoginSafe
)

$SuiteRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $SuiteRoot 'Core\CleanupEngine.ps1')

$manifest = Get-SuiteManifest -CleanupName 'WindowsSpeedup'

function Get-SuiteAuditServiceMatches {
    param([psobject]$Entry)
    if ($Entry.NamePattern) {
        $matches = @(Get-Service -Name $Entry.NamePattern -ErrorAction SilentlyContinue)
    } else {
        $obj = Get-Service -Name $Entry.Name -ErrorAction SilentlyContinue
        $matches = if ($obj) { @($obj) } else { @() }
    }
    return $matches
}

function Get-SuiteAuditTaskMatches {
    param([psobject]$Entry)
    $matches = @()
    if ($Entry.NamePattern) {
        $path = $null
        if ($Entry.PathPattern) { $path = $Entry.PathPattern }
        elseif ($Entry.Path) { $path = $Entry.Path }
        $allTasks = if ($path) { @(Get-ScheduledTask -TaskPath $path -ErrorAction SilentlyContinue) } else { @(Get-ScheduledTask -ErrorAction SilentlyContinue) }
        $matches = @($allTasks | Where-Object { $_.TaskName -like $Entry.NamePattern })
    } else {
        $obj = Get-ScheduledTask -TaskPath $Entry.Path -TaskName $Entry.Name -ErrorAction SilentlyContinue
        if ($obj) { $matches = @($obj) }
    }
    return $matches
}

Write-Host 'Post-Run Audit: Services'
$serviceRows = @()
foreach ($entry in @($manifest.Services)) {
    if (-not (Test-SuiteEntryApplies -Entry $entry -Profile $Profile)) { continue }
    $matches = @(Get-SuiteAuditServiceMatches -Entry $entry)
    if (-not $matches.Count) {
        $serviceRows += [pscustomobject]@{ Name = Get-SuiteEntryLabel -Entry $entry; Status = 'NotFound'; StartType = '-'; Expectation = 'NotFound' }
        continue
    }
    foreach ($svc in $matches) {
        if (Test-SuiteIsProtected -Name $svc.Name -Manifest $manifest) {
            $expectation = 'Kept (protected)'
        } elseif ($svc.StartType -eq 'Manual' -or $svc.Status -eq 'Stopped') {
            $expectation = 'Manual/Stopped (targeted)'
        } else {
            $expectation = 'Review manually'
        }
        $serviceRows += [pscustomobject]@{ Name = $svc.Name; Status = $svc.Status; StartType = $svc.StartType; Expectation = $expectation }
    }
}
$serviceRows | Sort-Object Name | Format-Table -AutoSize | Out-String | Write-Host

Write-Host 'Post-Run Audit: Tasks'
$taskRows = @()
foreach ($entry in @($manifest.Tasks)) {
    if (-not (Test-SuiteEntryApplies -Entry $entry -Profile $Profile)) { continue }
    $matches = @(Get-SuiteAuditTaskMatches -Entry $entry)
    if (-not $matches.Count) {
        $taskRows += [pscustomobject]@{ TaskName = Get-SuiteEntryLabel -Entry $entry; State = 'NotFound'; Enabled = $null; Expectation = 'NotFound' }
        continue
    }
    foreach ($task in $matches) {
        if (Test-SuiteIsProtected -Name $task.TaskName -Manifest $manifest) {
            $expectation = 'Kept (protected)'
        } elseif ($task.State -eq 'Disabled') {
            $expectation = 'Disabled (targeted)'
        } else {
            $expectation = 'Review manually'
        }
        $taskRows += [pscustomobject]@{ TaskName = $task.TaskName; State = $task.State; Enabled = $task.Settings.Enabled; Expectation = $expectation }
    }
}
$taskRows | Sort-Object TaskName | Format-Table -AutoSize | Out-String | Write-Host

Write-Host 'Post-Run Audit: Run Keys'
$runRows = @()
foreach ($entry in @($manifest.RunAutoruns)) {
    $names = @()
    if ($entry.NamePattern) {
        if (Test-Path $entry.Path) {
            $names = @((Get-Item -Path $entry.Path).Property | Where-Object { $_ -like $entry.NamePattern })
        }
    } else {
        $names = @($entry.Name)
    }
    foreach ($name in $names) {
        $present = $false
        try { $null = (Get-ItemProperty -Path $entry.Path -Name $name -ErrorAction Stop); $present = $true } catch { $present = $false }
        $expectation = if ($LoginSafe -and $entry.ExcludeWhenLoginSafe) { 'Kept (LoginSafe)' } else { 'Absent (removed by cleanup)' }
        $runRows += [pscustomobject]@{
            Path = $entry.Path; Entry = $name
            Status = if ($present) { 'Present' } else { 'Absent' }
            Expectation = $expectation
        }
    }
}
$runRows | Sort-Object Path, Entry | Format-Table -AutoSize | Out-String | Write-Host

Write-Host ''
Write-Host "Summary: $($serviceRows.Count) services, $($taskRows.Count) tasks, $($runRows.Count) run entries."
