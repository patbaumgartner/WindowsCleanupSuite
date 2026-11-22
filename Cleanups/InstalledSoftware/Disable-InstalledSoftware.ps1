#requires -Version 5.1
<#
.SYNOPSIS
    Removes commonly unwanted third-party software: Win32 apps (via their
    uninstaller) and Windows 10+ UWP apps (via Get-AppxPackage).

.DESCRIPTION
    - Win32Apps: reads the UninstallString from the HKLM Uninstall keys,
      backs up the key values, and runs the uninstaller.
    - UwpApps: removes UWP apps for all users via Remove-AppxPackage, and
      removes provisioned packages via Remove-AppxProvisionedPackage.

    Based on Marvin700 Remove-BloatwareAppsList.ps1, Raphire Win11Debloat,
    and LeDragoX Win-Debloat-Tools.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\InstalledSoftware\Disable-InstalledSoftware.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest   = Get-SuiteManifest -CleanupName 'InstalledSoftware'
$backupRoot = Get-SuiteBackupRoot -CleanupName 'InstalledSoftware'

# ---------------- Win32 apps ----------------
Write-Host 'Installed-software cleanup (Win32 apps)'
$uninstallKeys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')

foreach ($entry in @($manifest.Win32Apps)) {
    if ($entry.Kept) { Write-Host "  Kept by user request: $($entry.Name)"; continue }
    if (-not $PSCmdlet.ShouldProcess($entry.Name, "Remove Win32 app via uninstaller")) {
        Write-Host "  Would remove Win32 app: $($entry.Name)"
        continue
    }

    $found = $false
    foreach ($keyPath in $uninstallKeys) {
        if (-not (Test-Path $keyPath)) { continue }
        foreach ($subKey in @(Get-ChildItem $keyPath -ErrorAction SilentlyContinue)) {
            try { $ip = Get-ItemProperty -Path $subKey.PSPath -ErrorAction Stop } catch { continue }
            $displayName = if ($ip.PSObject.Properties.Name -contains 'DisplayName') { [string]$ip.DisplayName } else { '' }
            if ($displayName -ne $entry.Name) { continue }
            if ($entry.Publisher -and $ip.PSObject.Properties.Name -contains 'Publisher' -and [string]$ip.Publisher -notlike $entry.Publisher) {
                Write-Host "  Publisher mismatch for '$displayName' ('$($ip.Publisher)' vs '$($entry.Publisher)'), skipping"
                continue
            }
            if ($ip.PSObject.Properties.Name -contains 'UninstallString' -and $ip.UninstallString) {
                $values = @($ip.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
                    @{
                        Name = $_.Name
                        Value = if ($_.Value -is [byte[]]) { [Convert]::ToBase64String($_.Value) } else { $_.Value }
                        Type = Get-WCSRegistryType $_.Value
                    }
                })
                $record = @{
                    Type = 'Win32'; Name = $displayName
                    Publisher = if ($ip.PSObject.Properties.Name -contains 'Publisher') { [string]$ip.Publisher } else { '' }
                    UninstallString = [string]$ip.UninstallString
                    RegKeyPath = $subKey.PSPath
                    Values = $values
                }
                New-SuiteBackupFile -BackupRoot $backupRoot -FileName "win32_$(Get-SuiteSafeFileName $displayName).json" -Record $record
                try {
                    $proc = Start-Process -FilePath cmd.exe -ArgumentList '/c', $ip.UninstallString -Wait -PassThru -ErrorAction SilentlyContinue
                } catch {
                    Write-Warning "  Could not start uninstaller for '$displayName': $($_.Exception.Message) (backup kept in $backupRoot)"
                    $proc = $null
                }
                $exitCode = if ($proc) { $proc.ExitCode } else { $null }
                if ($null -eq $exitCode -or $exitCode -eq 0) {
                    Write-Host "  Removed Win32 app: $displayName"
                } else {
                    Write-Warning "  Uninstaller for '$displayName' exited with code $exitCode (failed or cancelled) - backup kept in $backupRoot"
                }
                $found = $true
            } else {
                Write-Warning "  No uninstaller string for '$displayName' - skipping"
            }
        }
    }
    if (-not $found) { Write-Host "  Win32 app not installed or no uninstaller: $($entry.Name)" }
}

# ---------------- UWP apps ----------------
Write-Host 'Installed-software cleanup (UWP apps)'
# -AllUsers / Remove-AppxPackage -AllUsers need elevation; stay at current-user scope otherwise.
$canAllUsers = Test-SuiteIsAdmin
foreach ($entry in @($manifest.UwpApps)) {
    $pattern = Get-SuiteEntryLabel -Entry $entry
    if ($entry.Kept) { Write-Host "  Kept by user request: $pattern"; continue }
    $uwp = @()
    try {
        if ($canAllUsers) {
            $uwp = @(Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue)
        } else {
            $uwp = @(Get-AppxPackage -Name $pattern -ErrorAction SilentlyContinue)
        }
    } catch { $uwp = @() }
    if (-not $uwp.Count) {
        Write-Host "  Not installed (skipped): $pattern"
        continue
    }

    $scope = if ($canAllUsers) { 'all users' } else { 'current user' }
    foreach ($app in $uwp) {
        if (Test-SuiteIsProtected -Name $app.Name -Manifest $manifest) {
            Write-Host "  Skipped (Protected): $($app.Name)"
            continue
        }
        New-SuiteBackupFile -BackupRoot $backupRoot -FileName "uwp_removed_$(Get-SuiteSafeFileName $app.Name).json" -Record @{
            Type = 'UwpRemoved'; Name = $app.Name; PackageFullName = $app.PackageFullName; Scope = $scope
        }
        # Some packages (e.g. Microsoft.GetHelp) throw a TERMINATING "Access is denied"
        # even for admins - catch per app so one failure does not abort the whole run.
        try {
            if ($canAllUsers) {
                Remove-AppxPackage -AllUsers -Package $app.PackageFullName -ErrorAction SilentlyContinue | Out-Null
            } else {
                Remove-AppxPackage -Package $app.PackageFullName -ErrorAction SilentlyContinue | Out-Null
                Write-Host "  Note: current-user UWP removal is recorded but not auto-restorable - reinstall from the Microsoft Store if needed."
            }
            Write-Host "  Removed UWP app ($scope): $($app.Name)"
        } catch {
            Write-Warning "  Could not remove UWP app $($app.Name): $($_.Exception.Message) (backup kept in $backupRoot)"
        }
    }

    # Provisioned packages (what Windows pre-installs) - only available elevated
    if (-not $canAllUsers) { continue }
    try {
        foreach ($pkg in @(Get-AppxProvisionedPackage -Online -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pattern })) {
            $record = @{ Type = 'UwpProvisioned'; DisplayName = $pkg.DisplayName; PublisherId = $pkg.PublisherId; Architecture = $pkg.Architecture }
            New-SuiteBackupFile -BackupRoot $backupRoot -FileName "uwp_$(Get-SuiteSafeFileName $pkg.DisplayName).json" -Record $record
            try {
                Remove-AppxProvisionedPackage -Online -AllUsers -PackageName $pkg.DisplayName -ErrorAction SilentlyContinue | Out-Null
                Write-Host "  Removed provisioned app: $($pkg.DisplayName)"
            } catch {
                Write-Warning "  Could not remove provisioned app $($pkg.DisplayName): $($_.Exception.Message) (backup kept in $backupRoot)"
            }
        }
    } catch {
        # Provisioned-package removal requires elevation; skip quietly if unavailable.
    }
}

Write-Host "Done. Backups are in $backupRoot"
