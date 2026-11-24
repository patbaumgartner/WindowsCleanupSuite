#requires -Version 5.1
<#
.SYNOPSIS
    Restores power plan settings changed by Enable-UltimatePerformancePlan.ps1.

.DESCRIPTION
    Restores the registry values backed up by Enable-UltimatePerformancePlan.ps1
    (Set-WCSRegistryEntry records in Backups\PowerPlan) and switches the active
    power plan back to the default Balanced plan.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\PowerPlan\Restore-PowerPlan.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest   = Get-SuiteManifest -CleanupName 'PowerPlan'
$backupRoot = Get-SuiteBackupRoot -CleanupName 'PowerPlan'
$isAdmin    = Test-SuiteIsAdmin

if (-not $isAdmin) {
    Write-Warning 'Restore-PowerPlan: HKLM changes require Administrator; run elevated for full effect.'
}

# Restore registry values backed up by Enable-UltimatePerformancePlan.ps1.
foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'Registry' })) {
    if (-not $record.Path -or -not $record.Name) { Write-Warning 'Malformed backup record'; continue }
    if (-not $isAdmin -and $record.Path -like 'HKLM:*') { Write-Host "  Skipped (Admin): $($record.Path)\$($record.Name)"; continue }
    if (-not $PSCmdlet.ShouldProcess("$($record.Path)\$($record.Name)", 'Restore previous value')) {
        Write-Host "  Would restore: $($record.Path)\$($record.Name)"
        continue
    }

    $targetExists = $false
    if (Test-Path $record.Path) {
        $targetExists = (@((Get-Item -Path $record.Path -ErrorAction SilentlyContinue).Property) -contains $record.Name)
    }

    try {
        if ($record.OldExists) {
            if (-not (Test-Path $record.Path)) { New-Item -Path $record.Path -Force | Out-Null }
            Restore-WCSRegistryRecordValue -Record $record -ErrorAction Stop
            Write-Host "  Restored: $($record.Path)\$($record.Name) = $($record.OldValue)"
        } elseif ($targetExists) {
            Remove-ItemProperty -Path $record.Path -Name $record.Name -ErrorAction Stop
            Write-Host "  Removed (did not exist before): $($record.Path)\$($record.Name)"
        } else {
            Write-Host "  Skipped (already absent): $($record.Path)\$($record.Name)"
        }
    } catch {
        Write-Error "  Failed: $($record.Path)\$($record.Name) - $($_.Exception.Message)"
    }
}

# Deactivate Ultimate Performance: re-activate the scheme that was active BEFORE the
# debloat (recorded in powerplan_state.json); fall back to Balanced for older backups.
$powercfg = Join-Path $env:SystemRoot 'System32\powercfg.exe'
$balancedGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'  # Balanced (default)
$stateRecord = @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'PowerPlanState' }) | Select-Object -First 1
$targetGuid = $balancedGuid
$targetLabel = 'Balanced (default)'
if ($stateRecord -and $stateRecord.PreviousActiveScheme) {
    $targetGuid = [string]$stateRecord.PreviousActiveScheme
    $targetLabel = "previous scheme $targetGuid"
}
if (Test-Path $powercfg) {
    if ($PSCmdlet.ShouldProcess($targetGuid, "Set active power plan back to $targetLabel")) {
        & $powercfg -setactive $targetGuid 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Host "  Activated power plan: $targetLabel" }
        else { Write-Warning "  powercfg -setactive $targetGuid failed with exit code $LASTEXITCODE" }
    } else {
        Write-Host "  Would activate power plan: $targetLabel"
    }

    # Restore the previous hibernation state (newer backups record it).
    if ($stateRecord -and $stateRecord.HibernateExists) {
        $onOff = if ([int]$stateRecord.HibernateEnabled -eq 1) { 'ON' } else { 'OFF' }
        if (-not $isAdmin) {
            Write-Host "  Skipped (Admin): restore hibernation (powercfg /HIBERNATE $onOff)"
        } elseif ($PSCmdlet.ShouldProcess('powercfg', "HIBERNATE $onOff (restore previous hibernation state)")) {
            & $powercfg /HIBERNATE $onOff 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Host "  Restored hibernation: $onOff" }
            else { Write-Warning "  powercfg /HIBERNATE $onOff failed with exit code $LASTEXITCODE" }
        } else {
            Write-Host "  Would restore hibernation: $onOff"
        }
    }
}
