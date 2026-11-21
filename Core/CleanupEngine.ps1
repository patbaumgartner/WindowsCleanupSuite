<#
    WindowsCleanupSuite - shared core engine
    Loaded by every cleanup script:
        . (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

    Provides: suite root/manifest loading, protected-name rules, backup record
    IO, and registry helpers shared by the cleanups.
#>

# Suite root = parent of this Core\ folder: <SuiteRoot>\Core\CleanupEngine.ps1
if ($null -eq $global:SuiteRoot) {
    $global:SuiteRoot = Split-Path -Parent $PSScriptRoot
}

function Get-SuiteRoot {
    return $global:SuiteRoot
}

function Test-SuiteIsAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SuiteManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CleanupName
    )

    # Dynamic validation: any folder under Cleanups\ with a Manifest.psd1 is a valid cleanup.
    $manifestPath = Join-Path (Get-SuiteRoot) "Cleanups\$CleanupName\Manifest.psd1"
    if (-not (Test-Path $manifestPath)) {
        $available = @(Get-ChildItem -Path (Join-Path (Get-SuiteRoot) 'Cleanups') -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName 'Manifest.psd1') } |
            Select-Object -ExpandProperty Name)
        throw "Manifest not found: $manifestPath (available cleanups: $($available -join ', '))"
    }
    return Import-PowerShellDataFile -Path $manifestPath
}

function Get-SuiteCleanupNames {
    # All cleanups in canonical run order (must match Runners\Run-Cleanup.ps1).
    return @('StartupBloat', 'WindowsSpeedup', 'InstalledSoftware', 'WindowsAI', 'Privacy', 'Browsers', 'Network', 'PrivacySettings', 'WindowsUpdates', 'OneDrive', 'ExtremeExtras', 'TempAndJunkFiles', 'PowerPlan', 'DNSReset')
}

function Test-SuiteEntryRiskyAllowed {
    # Entries flagged Risky = $true only run when -AllowRisky is passed.
    param(
        [Parameter(Mandatory = $true)]$Entry,
        [switch]$AllowRisky
    )
    if (-not $Entry.Risky) { return $true }
    return [bool]$AllowRisky
}

function Get-SuiteEntryLabel {
    param([Parameter(Mandatory = $true)]$Entry)
    if ($Entry.NamePattern) { return $Entry.NamePattern }
    return $Entry.Name
}

function Test-SuiteIsProtected {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Manifest
    )

    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    foreach ($pattern in @($Manifest.ProtectedPatterns)) {
        if ($Name -like $pattern) { return $true }
    }
    return $false
}

function Test-SuiteEntryApplies {
    # Entries without a 'Profile' key run in every profile.
    param([Parameter(Mandatory = $true)]$Entry, [Parameter(Mandatory = $true)][string]$Profile)
    if ($Entry.Profile -eq $null) { return $true }
    return ($Entry.Profile -eq $Profile)
}

function Test-SuiteLoginSafeExcluded {
    param([Parameter(Mandatory = $true)]$Entry, $LoginSafeExclusions)
    if (-not $LoginSafeExclusions) { return $false }
    foreach ($excluded in $LoginSafeExclusions) {
        if ($Entry.Name -eq $excluded -or $Entry.NamePattern -eq $excluded) { return $true }
    }
    return $false
}

function Get-SuiteBackupRoot {
    param([Parameter(Mandatory = $true)][string]$CleanupName)
    return Join-Path (Join-Path (Get-SuiteRoot) 'Backups') $CleanupName
}

function Get-SuiteSafeFileName {
    param([Parameter(Mandatory = $true)][string]$Name)
    return ($Name -replace '[\\/:*?"<>|]', '_')
}

function New-SuiteBackupFile {
    param(
        [Parameter(Mandatory = $true)][string]$BackupRoot,
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)]$Record
    )

    $target = Join-Path $BackupRoot $FileName
    if ($WhatIfPreference) { return $target }
    if (-not (Test-Path $BackupRoot)) { New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null }
    $Record | ConvertTo-Json -Depth 4 | Set-Content -Path $target -Encoding UTF8
    return $target
}

function Get-SuiteBackupRecords {
    param([Parameter(Mandatory = $true)][string]$BackupRoot)
    $records = @()
    if (-not (Test-Path $BackupRoot)) { return $records }
    foreach ($file in @(Get-ChildItem -Path $BackupRoot -File -ErrorAction SilentlyContinue)) {
        $content = $null
        try { $content = Get-Content -Raw -Path $file.FullName -ErrorAction Stop } catch { $content = $null }
        if ([string]::IsNullOrWhiteSpace($content)) { continue }
        try { $records += (ConvertFrom-Json -InputObject $content -ErrorAction Stop) }
        catch { Write-Warning "Skipping unreadable backup file '$($file.FullName)'." }
    }
    return $records
}

function Get-RegistryEntryValues {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Entry
    )

    if (-not (Test-Path $Path)) { return @() }
    $names = @()
    try { $properties = @((Get-Item -Path $Path).Property) } catch { $properties = @() }
    if ($Entry.NamePattern) {
        $names = @($properties | Where-Object { $_ -like $Entry.NamePattern })
    } else {
        $names = @($Entry.Name)
    }

    $found = @()
    foreach ($name in $names) {
        $value = $null
        try { $value = (Get-ItemProperty -Path $Path -Name $name -ErrorAction Stop).$name } catch { $value = $null }
        if ($null -ne $value) { $found += [pscustomobject]@{ Name = $name; Value = $value } }
    }
    return $found
}

# ---------------------------------------------------------------------------
# Generic engines shared by the data-driven cleanups (Privacy, Browsers,
# Network, ...). Entries are manifest rows; every change is backed up first.
# $Preview = $true prints "Would ..." and changes nothing (used with -WhatIf).
# ---------------------------------------------------------------------------

function Invoke-SuiteRegistryEntry {
    param(
        [Parameter(Mandatory = $true)]$Entry,
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$BackupRoot,
        [bool]$Preview = $false,
        [switch]$AllowRisky
    )

    if (-not (Test-SuiteEntryRiskyAllowed -Entry $Entry -AllowRisky:$AllowRisky)) {
        Write-Host "  [reg]     Skipped (Risky - pass -AllowRisky): $(Get-SuiteEntryLabel -Entry $Entry) - $($Entry.Reason)"
        return
    }

    # Resolve target key path(s): single RegistryKey, or every key matching PathPattern.
    $keys = @()
    if ($Entry.PathPattern) {
        $keys = @(Get-ChildItem -Path $Entry.PathPattern -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSPath)
        if (-not $keys.Count) { Write-Host "  [reg]     No key matches: $($Entry.PathPattern) - $($Entry.Reason)"; return }
    } else {
        $keys = @($Entry.RegistryKey)
    }

    foreach ($key in $keys) {
        $names = @()
        if ($Entry.NamePattern) {
            if (Test-Path $key) { $names = @((Get-Item -Path $key).Property | Where-Object { $_ -like $Entry.NamePattern }) }
        } else {
            $names = @($Entry.Name)
        }

        foreach ($name in $names) {
            if (Test-SuiteIsProtected -Name $name -Manifest $Manifest) {
                Write-Host "  [reg]     Skipped (Protected): $key\$name"
                continue
            }
            $needsAdmin = ($Entry.RequiresAdmin -eq $true) -or ($key -like 'HKLM:*')
            if ($needsAdmin -and -not (Test-SuiteIsAdmin)) {
                Write-Host "  [reg]     Skipped (Admin): $key\$name - $($Entry.Reason)"
                continue
            }

            $prev = $null; $had = $false
            try {
                $prop = Get-ItemProperty -Path $key -Name $name -ErrorAction Stop
                $prev = $prop.$name; $had = $true
            } catch { $had = $false }

            if (-not $Preview) {
                $safeKey = ($key -replace '^[^:]*:', '') -replace '[\\/:*?"<>| ]', '_'
                New-SuiteBackupFile -BackupRoot $BackupRoot -FileName "reg_${safeKey}_$(Get-SuiteSafeFileName $name).json" -Record @{
                    Type = 'Registry'; RegistryKey = $key; Name = $name
                    HadPrevious = [bool]$had; PreviousValue = $prev
                    NewValue = $Entry.Value; ValueType = $Entry.Type; Reason = $Entry.Reason
                }
            }

            if ($Preview) {
                Write-Host "  [reg]     Would set: $key\$name = $($Entry.Value) ($($Entry.Type)) - $($Entry.Reason)"
                continue
            }

            try {
                if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
                $type = if ($Entry.Type) { $Entry.Type } else { 'DWord' }
                Set-ItemProperty -Path $key -Name $name -Value $Entry.Value -Type $type -ErrorAction Stop
                Write-Host "  [reg]     Set: $key\$name = $($Entry.Value) - $($Entry.Reason)"
                if ($Entry.StopService) {
                    $svcName = Split-Path -Leaf $key
                    Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                }
            } catch {
                Write-Warning "  [reg]     Failed: $key\$name - $($_.Exception.Message)"
            }
        }
    }
}

function Restore-SuiteRegistryRecords {
    param(
        [Parameter(Mandatory = $true)][string]$BackupRoot,
        [bool]$Preview = $false
    )
    foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $BackupRoot | Where-Object { $_.Type -eq 'Registry' })) {
        if (-not $record.RegistryKey -or -not $record.Name) { Write-Warning 'Malformed backup record'; continue }
        if ($Preview) {
            Write-Host "  [reg]     Would restore: $($record.RegistryKey)\$($record.Name)"
            continue
        }
        try {
            if (-not (Test-Path $record.RegistryKey)) { New-Item -Path $record.RegistryKey -Force | Out-Null }
            if ($record.HadPrevious -and $null -ne $record.PreviousValue) {
                $type = if ($record.ValueType) { $record.ValueType } else { 'DWord' }
                Set-ItemProperty -Path $record.RegistryKey -Name $record.Name -Value $record.PreviousValue -Type $type -ErrorAction Stop
            } else {
                Remove-ItemProperty -Path $record.RegistryKey -Name $record.Name -ErrorAction SilentlyContinue
            }
            Write-Host "  [reg]     Restored: $($record.RegistryKey)\$($record.Name)"
        } catch {
            Write-Warning "  [reg]     Restore failed: $($record.RegistryKey)\$($record.Name) - $($_.Exception.Message)"
        }
    }
}

function Invoke-SuiteServiceEntry {
    param(
        [Parameter(Mandatory = $true)]$Entry,
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$BackupRoot,
        [string]$Mode = 'Manual',
        [bool]$Preview = $false,
        [switch]$AllowRisky
    )

    if (-not (Test-SuiteEntryRiskyAllowed -Entry $Entry -AllowRisky:$AllowRisky)) {
        Write-Host "  [service] Skipped (Risky - pass -AllowRisky): $(Get-SuiteEntryLabel -Entry $Entry) - $($Entry.Reason)"
        return
    }

    $matches = @()
    if ($Entry.NamePattern) {
        $matches = @(Get-Service -Name $Entry.NamePattern -ErrorAction SilentlyContinue | Sort-Object Name)
    } else {
        $obj = Get-Service -Name $Entry.Name -ErrorAction SilentlyContinue
        if ($obj) { $matches = @($obj) }
    }
    if (-not $matches.Count) {
        Write-Host "  [service] No matches: $(Get-SuiteEntryLabel -Entry $Entry) - $($Entry.Reason)"
        return
    }

    $modeValue = switch ($Mode) { 'Disabled' { 4 } 'Manual' { 3 } 'Automatic' { 2 } default { 3 } }

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

        if ($Preview) {
            Write-Host "  [service] Would set: $($svc.Name) -> $Mode - $($Entry.Reason)"
            continue
        }

        New-SuiteBackupFile -BackupRoot $BackupRoot -FileName "svc_$($svc.Name).txt" -Record @{
            Type = 'Service'; Name = $svc.Name; StartType = [int]$start; Reason = $Entry.Reason
        }

        try {
            Set-Service -Name $svc.Name -StartupType $Mode -ErrorAction Stop
            if ($svc.Status -eq 'Running') { Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue }
            Write-Host "  [service] Set to ${Mode}: $($svc.Name) - $($Entry.Reason)"
        } catch {
            try {
                Set-ItemProperty -Path $regPath -Name 'Start' -Value $modeValue -Type DWord -ErrorAction Stop
                if ($svc.Status -eq 'Running') { Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue }
                Write-Host "  [service] Set to ${Mode} via registry: $($svc.Name) - $($Entry.Reason)"
            } catch {
                Write-Warning "  [service] Failed to change $($svc.Name): $($_.Exception.Message)"
            }
        }
    }
}

function Restore-SuiteServiceRecords {
    param(
        [Parameter(Mandatory = $true)][string]$BackupRoot,
        [bool]$Preview = $false
    )
    foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $BackupRoot | Where-Object { $_.Type -eq 'Service' })) {
        if (-not $record.Name) { continue }
        if ($Preview) {
            Write-Host "  [service] Would restore start type: $($record.Name) -> $($record.StartType)"
            continue
        }
        try {
            $mode = switch ([int]$record.StartType) { 2 { 'Automatic' } 3 { 'Manual' } 4 { 'Disabled' } default { 'Manual' } }
            Set-Service -Name $record.Name -StartupType $mode -ErrorAction SilentlyContinue
            Write-Host "  [service] Restored: $($record.Name) -> $mode"
        } catch {
            Write-Warning "  [service] Restore failed: $($record.Name) - $($_.Exception.Message)"
        }
    }
}

# --- Shared registry helpers (new cleanups) ----------------------------------------

function Get-WCSRegistryValue {
    param([Parameter(Mandatory = $true)]$Entry)

    try {
        $value = (Get-ItemProperty -Path $Entry.Path -Name $Entry.Name -ErrorAction Stop).$Entry.Name
        if ($null -eq $value) {
            return [pscustomobject]@{ Exists = $false; Value = $null; Type = '' }
        }
        return [pscustomobject]@{ Exists = $true; Value = $value; Type = (Get-WCSRegistryType $value) }
    } catch {
        return [pscustomobject]@{ Exists = $false; Value = $null; Type = '' }
    }
}

function Get-WCSRegistryType {
    param($Value)
    if ($null -eq $Value) { return 'String' }
    if ($Value -is [bool]) { return 'Binary' }
    if ($Value -is [byte[]]) { return 'Binary' }
    if ($Value -is [int]) { return 'DWord' }
    if ($Value -is [long]) { return 'QWord' }
    return 'String'
}

function Set-WCSRegistryEntry {
    <#
        Sets a registry value after backing up the current state.
        Records: Type='Registry', OldExists, OldValue, OldType, Path, Name, Reason.
        Restorable by Restore-<Cleanup>.ps1 (filters on Type='Registry').
    #>
    param(
        [Parameter(Mandatory = $true)]$Entry,
        [Parameter(Mandatory = $true)][string]$BackupRoot,
        [ValidateSet('DWord', 'String', 'QWord')]
        [string]$Type
    )

    $current = Get-WCSRegistryValue -Entry $Entry
    $isSame = $false
    if ($current.Exists) {
        $isSame = ($current.Value -eq $Entry.Value)
    }

    if ($isSame) {
        Write-Host "  [reg]     Already set: $($Entry.Path)\$($Entry.Name) = $($Entry.Value)"
        return
    }

    if (-not $PSCmdlet.ShouldProcess("$($Entry.Path)\$($Entry.Name)", "Set $($Entry.Name) = $($Entry.Value) - $($Entry.Reason)")) {
        Write-Host "  [reg]     Would set: $($Entry.Path)\$($Entry.Name) = $($Entry.Value)"
        return
    }

    $fileName = "reg_$(Get-SuiteSafeFileName "$($Entry.Path)\$($Entry.Name)").txt"
    New-SuiteBackupFile -BackupRoot $BackupRoot -FileName $fileName -Record @{
        Type = 'Registry'
        Path = $Entry.Path
        Name = $Entry.Name
        OldExists = [bool]$current.Exists
        OldValue = (if ($current.Exists) { if ($current.Value -is [byte[]]) { [Convert]::ToBase64String($current.Value) } else { $current.Value } } else { $null })
        OldType = (if ($current.Exists) { Get-WCSRegistryType $current.Value } else { '' })
        Reason = $Entry.Reason
    }

    try {
        if (-not $current.Exists) {
            New-Item -Path $Entry.Path -ErrorAction Stop | Out-Null
        }
        $type = $Type
        if ([string]::IsNullOrWhiteSpace($type)) { $type = Get-WCSRegistryType $Entry.Value }
        Set-ItemProperty -Path $Entry.Path -Name $Entry.Name -Value $Entry.Value -Type $type -ErrorAction Stop
        Write-Host "  [reg]     Set: $($Entry.Path)\$($Entry.Name) = $($Entry.Value) ($type)"
    } catch {
        Write-Warning "  [reg]     Failed: $($Entry.Path)\$($Entry.Name) - $($_.Exception.Message)"
    }
}

function Restore-WCSRegistryRecordValue {
    <#
        Restores a registry value from a backup record produced by Set-WCSRegistryEntry
        (Type='Registry', OldExists, OldValue, OldType). Returns $true when restored.
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Record)

    if (-not $Record.OldExists) { return $false }
    $value = $Record.OldValue
    if ($Record.OldType -eq 'Binary' -and $value -isnot $null -and $value -is [string]) {
        $value = [byte[]][Convert]::FromBase64String($value)
    }
    Set-ItemProperty -Path $Record.Path -Name $Record.Name -Value $value -ErrorAction Stop
    return $true
}

