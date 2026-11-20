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
        [ValidateSet('StartupBloat', 'WindowsSpeedup', 'InstalledSoftware', 'WindowsAI', 'TempAndJunkFiles', 'PowerPlan', 'DNSReset')]
        [string]$CleanupName
    )

    $manifestPath = Join-Path (Get-SuiteRoot) "Cleanups\$CleanupName\Manifest.psd1"
    if (-not (Test-Path $manifestPath)) {
        throw "Manifest not found: $manifestPath"
    }
    return Import-PowerShellDataFile -Path $manifestPath
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
    return Join-Path (Get-SuiteRoot) 'Backups' $CleanupName
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

