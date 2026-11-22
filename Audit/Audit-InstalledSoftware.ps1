#requires -Version 5.1
<#
.SYNOPSIS
    Audit: cross-references installed software against the InstalledSoftware manifest (bloatware list).

.DESCRIPTION
    Scans HKLM/HKCU Uninstall keys and lists:
    - Total installed software count
    - Bloatware matches (per the WindowsCleanupSuite InstalledSoftware manifest)
    Read-only.

.EXAMPLE
    & 'WindowsCleanupSuite\Audit\Audit-InstalledSoftware.ps1'
#>
[CmdletBinding()]
param()

$SuiteRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $SuiteRoot 'Core\CleanupEngine.ps1')

$manifest = Get-SuiteManifest -CleanupName 'InstalledSoftware'

$uninstallKeys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall')
$installed = @()
foreach ($keyPath in $uninstallKeys) {
    if (-not (Test-Path $keyPath)) { continue }
    foreach ($subKey in (Get-ChildItem $keyPath -ErrorAction SilentlyContinue)) {
        try { $ip = Get-ItemProperty -Path $subKey.PSPath -ErrorAction Stop } catch { continue }
        if (-not ($ip.PSObject.Properties.Name -contains 'DisplayName')) { continue }
        $installed += [pscustomobject]@{
            Name = [string]$ip.DisplayName
            Publisher = if ($ip.PSObject.Properties.Name -contains 'Publisher') { [string]$ip.Publisher } else { '' }
            Version = if ($ip.PSObject.Properties.Name -contains 'DisplayVersion') { [string]$ip.DisplayVersion } else { '' }
            Hive = if ($keyPath -like 'HKCU*') { 'HKCU' } else { 'HKLM' }
        }
    }
}

$bloatware = @()
foreach ($app in $installed) {
    $match = $null
    foreach ($pattern in @($manifest.UwpApps)) {
        if ($pattern.Kept) { continue }
        if ($app.Name -like $pattern.NamePattern) { $match = @{ Type = 'UwpApp'; Pattern = $pattern.NamePattern; Reason = $pattern.Reason }; break }
    }
    if (-not $match) {
        foreach ($w32 in @($manifest.Win32Apps | Where-Object { $null -eq $_.Kept })) {
            if ($app.Name -eq $w32.Name) { $match = @{ Type = 'Win32App'; Pattern = $w32.Name; Reason = $w32.Reason }; break }
        }
    }
    if ($match) { $bloatware += [pscustomobject]@{ Name = $app.Name; Publisher = $app.Publisher; Hive = $app.Hive; Bloatware = $match.Type; Reason = $match.Reason } }
}

Write-Host "Total installed: $($installed.Count)"
Write-Host "Bloatware found: $($bloatware.Count)"
$bloatware | Sort-Object Name | Format-Table -AutoSize Name, Publisher, Hive, Bloatware, Reason | Out-String | Write-Host
