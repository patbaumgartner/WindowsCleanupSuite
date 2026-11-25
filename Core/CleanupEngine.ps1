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
    # All cleanups in canonical run order (referenced by the menu topics).
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
    # Never overwrite an existing backup: repeated runs must preserve the ORIGINAL
    # pre-change state, otherwise a second run would back up the already-modified
    # state (e.g. service StartType=3 after the first run set it to Manual) and
    # restore would no longer restore the real original configuration.
    if (Test-Path $target) { return $target }
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

# Full service/task enumerations are slow; cache them once per session so
# manifests with many NamePattern entries do not re-enumerate per entry.
function Get-SuiteCachedServices {
    if ($null -eq $global:WCS_ServiceCache) {
        $global:WCS_ServiceCache = @(Get-Service -ErrorAction SilentlyContinue | Sort-Object Name)
    }
    return $global:WCS_ServiceCache
}

function Get-SuiteCachedTasks {
    if ($null -eq $global:WCS_TaskCache) {
        $global:WCS_TaskCache = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Sort-Object TaskPath, TaskName)
    }
    return $global:WCS_TaskCache
}

function Get-WCSRegistryBinaryValue {
    # Get-ItemProperty | Select-Object -ExpandProperty turns a REG_BINARY byte[]
    # into Object[] on PS 5.1 (so '-is [byte[]]' would always be false).
    # The registry provider's .GetValue() keeps the real byte[] and value kind.
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if (-not (Test-Path $Path)) { return $null }
    $key = Get-Item -Path $Path -ErrorAction SilentlyContinue
    if ($null -eq $key) { return $null }
    try { $value = $key.GetValue($Name, $null) } catch { return $null }
    if ($value -is [byte[]]) { return [byte[]]$value }
    return $null
}

function New-WCSStartupDisabledFlag {
    # StartupApproved flags are 12-byte values: byte 0 = 2 enabled / 3 disabled,
    # bytes 1..11 = the timestamp Task Manager writes when toggling the entry.
    param([byte[]]$Existing)
    $flag = New-Object byte[] 12
    if ($null -ne $Existing -and $Existing.Length -ge 12) {
        [Array]::Copy($Existing, 0, $flag, 0, 12)
    }
    $flag[0] = 3
    return $flag
}

function Test-WCSStartupDisabledFlag {
    param([byte[]]$Value)
    if ($null -eq $Value -or $Value.Length -eq 0) { return $false }
    return ([int]$Value[0] -ne 2)
}

function Get-WCSRunStartupApprovedPath {
    # Per-user Task Manager toggle for a Run entry. 32-bit Run keys (including
    # HKLM\Software\WOW6432Node\...\Run) are toggled in the user's Run32 overlay,
    # which means Dropbox can be disabled without elevation.
    param([Parameter(Mandatory = $true)][string]$RunPath)
    if ($RunPath -like '*\StartupApproved\*') { return $RunPath }
    if ($RunPath -like '*\RunOnce') { return '' }
    if ($RunPath -like 'HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run*' -or
        $RunPath -like 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run*') {
        return 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32'
    }
    if ($RunPath -like 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run*') {
        return 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
    }
    return 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
}

function Get-WCSPythonCommand {
    # SQLite helper for app settings (kDrive stores autoStart in .parms.db).
    # Prefer python; fall back to the py launcher with -3.
    foreach ($name in @('python', 'py')) {
        $cmd = Get-Command -Name $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $cmd) {
            $prefix = if ($name -eq 'py') { @('-3') } else { @() }
            return [pscustomobject]@{ Path = $cmd.Source; Prefix = $prefix }
        }
    }
    return $null
}

function Resolve-WCSAppSettingPath {
    param([Parameter(Mandatory = $true)]$Entry)
    if ($Entry.PathKind -eq 'LocalAppData') { return Join-Path $env:LOCALAPPDATA $Entry.Path }
    if ($Entry.PathKind -eq 'AppData') { return Join-Path $env:APPDATA $Entry.Path }
    return $Entry.Path
}

function Get-WCSSqliteSingleValue {
    param(
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$Table,
        [Parameter(Mandatory = $true)][string]$Column,
        [switch]$Immutable
    )
    if (-not (Test-Path -LiteralPath $Database)) { return $null }
    $python = Get-WCSPythonCommand
    if ($null -eq $python) { return $null }

    $code = @'
import sqlite3, sys, urllib.parse
db, table, column, mode = sys.argv[1:5]
if mode == 'immutable':
    uri = 'file:' + urllib.parse.quote(db.replace('\\', '/')) + '?mode=ro&immutable=1'
    con = sqlite3.connect(uri, uri=True, timeout=5)
else:
    con = sqlite3.connect(db, timeout=10)
try:
    row = con.execute('select "{0}" from "{1}" limit 1'.format(column, table)).fetchone()
    print('' if row is None or row[0] is None else row[0])
finally:
    con.close()
'@
    $mode = if ($Immutable) { 'immutable' } else { 'normal' }
    $args = @() + @($python.Prefix) + @('-c', $code, $Database, $Table, $Column, $mode)
    $output = & $python.Path @args 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return (($output -join "`n").Trim())
}

function Set-WCSSqliteSingleValue {
    param(
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$Table,
        [Parameter(Mandatory = $true)][string]$Column,
        [Parameter(Mandatory = $true)][int]$Value
    )
    if (-not (Test-Path -LiteralPath $Database)) { return $false }
    $python = Get-WCSPythonCommand
    if ($null -eq $python) { return $false }

    $code = @'
import sqlite3, sys
db, table, column, value = sys.argv[1:5]
con = sqlite3.connect(db, timeout=10)
try:
    con.execute('update "{0}" set "{1}"=?'.format(table, column), (int(value),))
    con.commit()
finally:
    con.close()
'@
    $args = @() + @($python.Prefix) + @('-c', $code, $Database, $Table, $Column, [string]$Value)
    $null = & $python.Path @args 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Stop-WCSAppProcesses {
    param([string[]]$Names)
    foreach ($name in @($Names | Where-Object { $_ } | Sort-Object -Unique)) {
        $procs = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
        if ($procs.Count -eq 0) { continue }
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
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

            # Nothing to do when the value already matches - skip backup+mutation so
            # repeated (e.g. scheduled) runs stay clean and never churn backups.
            if ($had -and ([string]$prev -eq [string]$Entry.Value)) {
                Write-Host "  [reg]     Already set: $key\$name = $($Entry.Value)"
                continue
            }

            # PreviousType = the kind of the OLD value (ValueType is the NEW kind);
            # restore must use the old kind or a changed type would be restored wrong.
            $prevType = if ($had) { Get-WCSRegistryType $prev } else { '' }

            if (-not $Preview) {
                $safeKey = ($key -replace '^[^:]*:', '') -replace '[\\/:*?"<>| ]', '_'
                New-SuiteBackupFile -BackupRoot $BackupRoot -FileName "reg_${safeKey}_$(Get-SuiteSafeFileName $name).json" -Record @{
                    Type = 'Registry'; RegistryKey = $key; Name = $name
                    HadPrevious = [bool]$had; PreviousValue = $prev; PreviousType = $prevType
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
                # Write-Error (non-terminating): the menu counts error records and exits
                # nonzero - a failed mutation must not look like a successful run.
                Write-Error "  [reg]     Failed: $key\$name - $($_.Exception.Message)"
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
                # Prefer the recorded kind of the OLD value; ValueType (the NEW kind)
                # is only a best-effort fallback for older backups.
                $type = 'DWord'
                if ($record.PSObject.Properties.Name -contains 'PreviousType' -and $record.PreviousType) { $type = [string]$record.PreviousType }
                elseif ($record.ValueType) { $type = [string]$record.ValueType }
                Set-ItemProperty -Path $record.RegistryKey -Name $record.Name -Value $record.PreviousValue -Type $type -ErrorAction Stop
            } else {
                Remove-ItemProperty -Path $record.RegistryKey -Name $record.Name -ErrorAction SilentlyContinue
            }
            Write-Host "  [reg]     Restored: $($record.RegistryKey)\$($record.Name)"
        } catch {
            Write-Error "  [reg]     Restore failed: $($record.RegistryKey)\$($record.Name) - $($_.Exception.Message)"
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
        $matches = @(Get-SuiteCachedServices | Where-Object { $_.Name -like $Entry.NamePattern })
    } else {
        $matches = @(Get-SuiteCachedServices | Where-Object { $_.Name -eq $Entry.Name })
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
        if ([int]$start -eq $modeValue) {
            Write-Host "  [service] Already ${Mode}: $($svc.Name) - $($Entry.Reason)"
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
                Write-Error "  [service] Failed to change $($svc.Name): $($_.Exception.Message)"
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
            # -ErrorAction Stop: with SilentlyContinue an access-denied would still
            # print 'Restored' - success must only be reported after a real success.
            Set-Service -Name $record.Name -StartupType $mode -ErrorAction Stop
            Write-Host "  [service] Restored: $($record.Name) -> $mode"
        } catch {
            Write-Error "  [service] Restore failed: $($record.Name) - $($_.Exception.Message)"
        }
    }
}

# --- Shared registry helpers (new cleanups) ----------------------------------------

function Get-WCSRegistryValue {
    param([Parameter(Mandatory = $true)]$Entry)

    try {
        # NOTE: must be .($Entry.Name) - a chained .$Entry.Name parses as
        # (($result).$Entry).Name, i.e. a member named after the hashtable -> always $null.
        $value = (Get-ItemProperty -Path $Entry.Path -Name $Entry.Name -ErrorAction Stop).($Entry.Name)
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
        # NOTE: no [ValidateSet] here - reading an UNBOUND optional [ValidateSet]
        # parameter throws ("The variable cannot be validated because the value is
        # not a valid value for the Type variable") on PS 5.1 and 7.x. Callers omit
        # -Type on purpose; it is validated manually below via $PSBoundParameters.
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

    # NOTE: compute old value/type BEFORE the hashtable - `(if ...)` (statement in
    # parentheses) parses as a command invocation and throws at runtime:
    # "The term 'if' is not recognized" on PS 5.1 AND 7.x. Only $(if ...) is safe.
    $oldValue = $null
    $oldType = ''
    if ($current.Exists) {
        if ($current.Value -is [byte[]]) { $oldValue = [Convert]::ToBase64String($current.Value) } else { $oldValue = $current.Value }
        $oldType = Get-WCSRegistryType $current.Value
    }
    $fileName = "reg_$(Get-SuiteSafeFileName "$($Entry.Path)\$($Entry.Name)").txt"
    New-SuiteBackupFile -BackupRoot $BackupRoot -FileName $fileName -Record @{
        Type = 'Registry'
        Path = $Entry.Path
        Name = $Entry.Name
        OldExists = [bool]$current.Exists
        OldValue = $oldValue
        OldType = $oldType
        NewValue = $Entry.Value
        Reason = $Entry.Reason
    }

    try {
        # Create the KEY only when the key itself is missing - the value may not
        # exist yet while the key does ("A key in this path already exists").
        if (-not (Test-Path -LiteralPath $Entry.Path)) {
            New-Item -Path $Entry.Path -Force -ErrorAction Stop | Out-Null
        }
        # Determine the value type: explicit -Type (validated), else $Entry.Type,
        # else inferred from the value. Never read $Type when unbound - see param note.
        $type = ''
        if ($PSBoundParameters.ContainsKey('Type')) {
            $type = [string]$PSBoundParameters['Type']
            if ($type -notin @('DWord', 'String', 'QWord', 'ExpandString', 'MultiString', 'Binary')) {
                Write-Warning "  [reg]     Invalid -Type '$type' for $($Entry.Path)\$($Entry.Name) - inferring from value instead"
                $type = ''
            }
        }
        if ([string]::IsNullOrWhiteSpace($type)) {
            $entryType = $null
            if ($Entry -is [System.Collections.IDictionary]) { if ($Entry.Contains('Type')) { $entryType = $Entry['Type'] } }
            elseif ($null -ne $Entry.PSObject.Properties['Type']) { $entryType = $Entry.PSObject.Properties['Type'].Value }
            if (-not [string]::IsNullOrWhiteSpace([string]$entryType)) { $type = [string]$entryType }
        }
        if ([string]::IsNullOrWhiteSpace($type)) { $type = Get-WCSRegistryType $Entry.Value }
        Set-ItemProperty -Path $Entry.Path -Name $Entry.Name -Value $Entry.Value -Type $type -ErrorAction Stop
        Write-Host "  [reg]     Set: $($Entry.Path)\$($Entry.Name) = $($Entry.Value) ($type)"
    } catch {
        Write-Error "  [reg]     Failed: $($Entry.Path)\$($Entry.Name) - $($_.Exception.Message)"
    }
}

function Get-SuiteBackupReview {
    <#
        Enumerates Backups\<Cleanup>\** and returns one review row per backup record:
        Cleanup, File (relative to BackupRoot), Type, Name, Detail (one-liner).
        Used by Tools\Review-WCSBackup.ps1 to show what a restore would undo.
    #>
    param(
        [string]$BackupRoot = '',
        [string]$Cleanup = ''    # optional: only this cleanup subfolder
    )
    if ([string]::IsNullOrWhiteSpace($BackupRoot)) { $BackupRoot = Join-Path (Get-SuiteRoot) 'Backups' }
    $rows = @()
    if (-not (Test-Path -LiteralPath $BackupRoot)) { return $rows }

    $dirs = @(Get-ChildItem -Path $BackupRoot -Directory -ErrorAction SilentlyContinue)
    if ($Cleanup) { $dirs = @($dirs | Where-Object { $_.Name -eq $Cleanup }) }

    foreach ($dir in $dirs) {
        $files = @(Get-ChildItem -Path $dir.FullName -Recurse -File -Include '*.json', '*.txt' -ErrorAction SilentlyContinue)
        foreach ($file in $files) {
            $content = $null
            try { $content = Get-Content -Raw -LiteralPath $file.FullName -ErrorAction Stop } catch { continue }
            if ([string]::IsNullOrWhiteSpace($content)) { continue }
            $records = $null
            try { $records = @(ConvertFrom-Json -InputObject $content -ErrorAction Stop) } catch { continue }

            foreach ($rec in $records) {
                if ($null -eq $rec) { continue }
                $props = @($rec.PSObject.Properties.Name)
                $type = if ($props -contains 'Type' -and $rec.Type) { [string]$rec.Type } else { 'Unknown' }

                $name = ''
                foreach ($cand in @('Name', 'DisplayName', 'TaskName')) {
                    if ($props -contains $cand -and $rec.$cand) { $name = [string]$rec.$cand; break }
                }
                $path = ''
                if ($props -contains 'Path' -and $rec.Path) { $path = [string]$rec.Path }
                elseif ($props -contains 'RegistryKey' -and $rec.RegistryKey) { $path = [string]$rec.RegistryKey }
                elseif ($props -contains 'TaskPath' -and $rec.TaskPath) { $path = [string]$rec.TaskPath }
                $reason = if ($props -contains 'Reason') { [string]$rec.Reason } else { '' }

                $detail = switch ($type) {
                    'Registry' {
                        $old = '<absent>'
                        if ($props -contains 'OldExists' -and $rec.OldExists) { $old = "$($rec.OldValue)" }
                        elseif ($props -contains 'HadPrevious' -and $rec.HadPrevious) { $old = "$($rec.PreviousValue)" }
                        $new = ''
                        if ($props -contains 'NewValue') { $new = "$($rec.NewValue)" }
                        elseif ($props -contains 'Value') { $new = "$($rec.Value)" }
                        "$path\$name : $old -> $new"
                    }
                    'Service'    { "$name : StartType=$($rec.StartType)" }
                    'Task'       { "$path\$name : State=$($rec.State) Enabled=$($rec.Enabled)" }
                    'Win32'      { "$name : uninstall string recorded" }
                    'UwpRemoved' { "$name : $($rec.PackageFullName) ($($rec.Scope))" }
                    'UwpProvisioned' { "$name (provisioned package)" }
                    'StartupApproved' { "$path\$name" }
                    'AppModelStartup' { "$path\$name : State=$($rec.State)" }
                    { $_ -in @('RunAutorun', 'RunEntry') } { "$path\$name : $($rec.Value)" }
                    default      { if ($reason) { $reason } else { $name } }
                }

                $rel = $file.FullName
                if ($rel.StartsWith($BackupRoot, [StringComparison]::OrdinalIgnoreCase)) {
                    $rel = $rel.Substring($BackupRoot.Length).TrimStart('\', '/')
                } else {
                    $rel = Split-Path -Leaf $file.FullName
                }

                $rows += [pscustomobject]@{
                    Cleanup = $dir.Name
                    File    = $rel
                    Type    = $type
                    Name    = $name
                    Detail  = $detail
                }
            }
        }
    }
    return $rows
}

function Restore-WCSRegistryRecordValue {
    <#
        Restores a registry value from a backup record produced by Set-WCSRegistryEntry
        (Type='Registry', OldExists, OldValue, OldType). Returns $true when restored.
    #>
    # NOTE: untyped on purpose - callers pass records from Get-SuiteBackupRecords,
    # which are PSCustomObject (ConvertFrom-Json); a [hashtable] constraint would
    # fail parameter binding at runtime.
    param([Parameter(Mandatory = $true)]$Record)

    if (-not $Record.OldExists) { return $false }
    $value = $Record.OldValue
    if ($Record.OldType -eq 'Binary' -and $value -isnot $null -and $value -is [string]) {
        $value = [byte[]][Convert]::FromBase64String($value)
    }
    $oldType = [string]$Record.OldType
    if (-not [string]::IsNullOrWhiteSpace($oldType)) {
        Set-ItemProperty -Path $Record.Path -Name $Record.Name -Value $value -Type $oldType -ErrorAction Stop
    } else {
        Set-ItemProperty -Path $Record.Path -Name $Record.Name -Value $value -ErrorAction Stop
    }
    return $true
}

