#requires -Version 5.1
<#
.SYNOPSIS
    Restores changes made by the WindowsCleanupSuite, from JSON backups and/or a
    Windows System Restore point.

.DESCRIPTION
    -Backups (default):
      - Runs every cleanup's Restore-*.ps1 script (services, tasks, Run entries,
        startup apps, PowerPlan, DNS, InstalledSoftware, WindowsAI, PrivacySettings,
        WindowsUpdates, OneDrive, ExtremeExtras).
      - Restores generic Type='Registry' records found in Backups\**\*.json.
    -RestorePoint N (or -Latest):
      - Restores the System Restore point with sequence number N via Restore-Computer.
        Note: this triggers an automatic reboot after restoring.

.PARAMETER Backups
    Restore all backups (runs restore scripts + generic registry records).

.PARAMETER RestorePoint
    Restore the System Restore point with this sequence number.

.PARAMETER Latest
    With -RestorePoint: restore the newest System Restore point.

.PARAMETER WhatIf
    Preview mode - shows what would be restored without touching the system.

.EXAMPLE
    & 'Tools\Restore-WCSBackup.ps1'                   # restore all backups
    & 'Tools\Restore-WCSBackup.ps1' -Latest           # restore most recent restore point
    & 'Tools\Restore-WCSBackup.ps1' -RestorePoint 3 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Backups')]
param(
    [Parameter(ParameterSetName = 'Backups')][switch]$Backups,

    [Parameter(ParameterSetName = 'RestorePoint')][int]$RestorePoint,
    [Parameter(ParameterSetName = 'RestorePoint')][switch]$Latest
    # -WhatIf comes from SupportsShouldProcess (declaring it again would conflict).
)

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Core\CleanupEngine.ps1')

# Default parameter set is 'Backups': a bare invocation (no switch) restores backups.
if ($PSCmdlet.ParameterSetName -eq 'Backups' -and -not $PSBoundParameters.ContainsKey('Backups')) { $Backups = $true }

$SuiteRoot = Get-SuiteRoot
$global:WCS_RestoreFailed = $false

# --- Generic registry restore (records written by Set-WCSRegistryEntry) -----------

function Restore-WCSCustomRegistryRecords {
    $root = Join-Path $SuiteRoot 'Backups'
    if (-not (Test-Path $root)) { return }

    # Single-owner rule: every cleanup folder with its own Restore-*.ps1 restores its
    # own records (invoked below) - the generic pass only covers ORPHAN folders
    # (legacy/removed cleanups) so no record is ever restored twice.
    $ownedCleanups = @('StartupBloat', 'WindowsSpeedup', 'InstalledSoftware', 'WindowsAI', 'TempAndJunkFiles', 'PowerPlan', 'DNSReset', 'Privacy', 'Browsers', 'Network', 'PrivacySettings', 'WindowsUpdates', 'OneDrive', 'ExtremeExtras')

    # Backup records are written in two shapes (both JSON, .json or .txt):
    #   - Invoke-SuiteRegistryEntry / Disable-WindowsAI: RegistryKey + HadPrevious + PreviousValue (+ PreviousType/ValueType)
    #   - Set-WCSRegistryEntry:                           Path       + OldExists   + OldValue   (+ OldType)
    # Normalize both so every Type='Registry' record is restorable here.
    foreach ($file in @(Get-ChildItem -Path $root -Recurse -File -Include '*.json', '*.txt' -ErrorAction SilentlyContinue)) {
        $rel = $file.FullName.Substring($root.Length).TrimStart('\', '/')
        $owner = ($rel -split '[\\/]')[0]
        if ($ownedCleanups -contains $owner) { continue }
        $content = $null
        try { $content = Get-Content -Raw -Path $file.FullName -ErrorAction Stop } catch { $global:WCS_RestoreFailed = $true; Write-Warning "  Unreadable backup file: $($file.FullName)"; continue }
        if ([string]::IsNullOrWhiteSpace($content)) { continue }
        try { $records = @((ConvertFrom-Json $content)) } catch { $global:WCS_RestoreFailed = $true; Write-Warning "  Invalid backup JSON: $($file.FullName)"; continue }

        foreach ($raw in @($records | Where-Object { $_.Type -eq 'Registry' -and $_.Name -and ($_.Path -or $_.RegistryKey) })) {
            $record = [ordered]@{
                Path       = if ($raw.Path) { $raw.Path } else { $raw.RegistryKey }
                Name       = $raw.Name
                OldExists  = if ($raw.PSObject.Properties.Name -contains 'OldExists') { [bool]$raw.OldExists } else { [bool]$raw.HadPrevious }
                OldValue   = if ($raw.PSObject.Properties.Name -contains 'OldValue') { $raw.OldValue } else { $raw.PreviousValue }
                OldType    = if ($raw.PSObject.Properties.Name -contains 'OldType' -and $raw.OldType) { $raw.OldType } elseif ($raw.PSObject.Properties.Name -contains 'PreviousType' -and $raw.PreviousType) { $raw.PreviousType } elseif ($raw.ValueType) { $raw.ValueType } else { '' }
            }

            $names = @()
            if (Test-Path $record.Path) { $names = @((Get-Item -Path $record.Path -ErrorAction SilentlyContinue).Property) }
            $targetExists = ($names -contains $record.Name)

            if (-not $PSCmdlet.ShouldProcess("$($record.Path)\$($record.Name)", 'Restore registry backup')) {
                Write-Host "  [reg]     Would restore: $($record.Path)\$($record.Name)"
                continue
            }

            try {
                if ($record.OldExists) {
                    if (-not (Test-Path $record.Path)) { New-Item -Path $record.Path -Force | Out-Null }
                    $value = $record.OldValue
                    if ($record.OldType -eq 'Binary' -and $value -is [string]) { $value = [byte[]][Convert]::FromBase64String($value) }
                    if ($record.OldType) { Set-ItemProperty -Path $record.Path -Name $record.Name -Value $value -Type $record.OldType -ErrorAction Stop }
                    else { Set-ItemProperty -Path $record.Path -Name $record.Name -Value $value -ErrorAction Stop }
                    Write-Host "  [reg]     Restored: $($record.Path)\$($record.Name) = $($record.OldValue)"
                } elseif ($targetExists) {
                    Remove-ItemProperty -Path $record.Path -Name $record.Name -ErrorAction Stop
                    Write-Host "  [reg]     Removed (did not exist before): $($record.Path)\$($record.Name)"
                } else {
                    Write-Host "  [reg]     Skipped (already absent): $($record.Path)\$($record.Name)"
                }
            } catch {
                $global:WCS_RestoreFailed = $true
                Write-Warning "  [reg]     Failed: $($record.Path)\$($record.Name) - $($_.Exception.Message)"
            }
        }
    }
}

function Invoke-WCSToolRestore {
    param([string]$Tool)

    $path = Join-Path $SuiteRoot $Tool
    if (-not (Test-Path $path)) { Write-Warning "  Missing: $Tool - skipping"; return }

    Write-Host "--- $Tool ---"
    $LASTEXITCODE = $null
    try {
        # -ErrorAction Stop turns a cleanup's Write-Error (real restore failure) into a
        # terminating error caught below. Expected probes (missing service/task) do NOT
        # Write-Error, so they cannot cause false failures; -ErrorVariable is not used
        # because it also captures HANDLED probe errors.
        & $path -WhatIf:$WhatIfPreference -ErrorAction Stop
    } catch {
        $global:WCS_RestoreFailed = $true
        Write-Warning "  Restore script failed: $Tool - $($_.Exception.Message)"
    }
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { $global:WCS_RestoreFailed = $true }
}

# --- Backups mode -------------------------------------------------------------------

if ($Backups) {
    Write-Host 'Restoring backups...'
    Restore-WCSCustomRegistryRecords

    foreach ($tool in @(
        'Cleanups\StartupBloat\Restore-StartupBloat.ps1',
        'Cleanups\WindowsSpeedup\Restore-ServicesAndTasks.ps1',
        'Cleanups\InstalledSoftware\Restore-InstalledSoftware.ps1',
        'Cleanups\WindowsAI\Restore-WindowsAI.ps1',
        'Cleanups\TempAndJunkFiles\Restore-TempAndJunkFiles.ps1',
        'Cleanups\PowerPlan\Restore-PowerPlan.ps1',
        'Cleanups\DNSReset\Restore-DNSReset.ps1',
        'Cleanups\Privacy\Restore-Privacy.ps1',
        'Cleanups\Browsers\Restore-Browsers.ps1',
        'Cleanups\Network\Restore-Network.ps1',
        'Cleanups\PrivacySettings\Restore-PrivacySettings.ps1',
        'Cleanups\WindowsUpdates\Restore-WindowsUpdates.ps1',
        'Cleanups\OneDrive\Restore-OneDrive.ps1',
        'Cleanups\ExtremeExtras\Restore-ExtremeExtras.ps1'
    )) {
        Invoke-WCSToolRestore -Tool $tool
    }

    Write-Host ''
    if ($global:WCS_RestoreFailed) {
        Write-Warning 'Restore finished WITH errors - see warnings above.'
        exit 1
    }
    Write-Host 'Restore complete.' -ForegroundColor Green
    exit 0
}

# --- RestorePoint mode ---------------------------------------------------------------

if ($Latest) {
    $points = @(Get-ComputerRestorePoint | Where-Object { $_.SequenceNumber })
    if (-not $points.Count) { Write-Error 'No System Restore points found.'; exit 1 }
    $points = @($points | Sort-Object SequenceNumber)
    $RestorePoint = $points[-1].SequenceNumber
    Write-Host "Restoring newest point: #$RestorePoint"
}

if ($null -ne $RestorePoint) {
    if (-not (Test-SuiteIsAdmin)) {
        Write-Error 'Restoring a System Restore point requires Administrator privileges.'
        exit 1
    }

    $points = @(Get-ComputerRestorePoint | Where-Object { $_.SequenceNumber -eq $RestorePoint })
    if (-not $points.Count) { Write-Error "System Restore point #$RestorePoint not found."; exit 1 }

    # NOTE: the variable is $WhatIfPreference - SupportsShouldProcess does NOT create $WhatIf.
    if (-not $WhatIfPreference) {
        $confirm = Read-Host "Restore point #$RestorePoint ($($points[0].Description))? This triggers a reboot after restoring. Type YES"
        if ($confirm -ne 'YES') { Write-Host 'Canceled.'; exit 0 }
    }

    if ($PSCmdlet.ShouldProcess("SequenceNumber $RestorePoint", 'Restore-Computer')) {
        Restore-Computer -SequenceNumber $RestorePoint -ErrorAction Stop -WhatIf:$WhatIfPreference
        Write-Host "Restore initiated for point #$RestorePoint."
    }
    exit 0
}

Write-Error 'No action specified. Use -Backups or -RestorePoint N [-Latest].'
exit 1
