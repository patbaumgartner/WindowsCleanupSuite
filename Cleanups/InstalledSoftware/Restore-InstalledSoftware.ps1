#requires -Version 5.1
<#
.SYNOPSIS
    Restores Win32 apps removed by Disable-InstalledSoftware.ps1.

.DESCRIPTION
    Reads the backup records (JSON) from WindowsCleanupSuite\Backups\InstalledSoftware
    and re-adds the Uninstall registry key values.

    Note: UWP apps removed via Remove-AppxPackage cannot be automatically
    re-installed - reinstall from the Microsoft Store (and re-run Windows
    Update for updates) if needed.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\InstalledSoftware\Restore-InstalledSoftware.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$backupRoot = Get-SuiteBackupRoot -CleanupName 'InstalledSoftware'
$isAdmin    = Test-SuiteIsAdmin

if (-not $isAdmin -and -not $WhatIfPreference) {
    Write-Warning 'Restore-InstalledSoftware: HKLM Uninstall keys require Administrator; run elevated for full effect.'
}

Write-Host 'Restoring removed Win32 apps'
foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'Win32' })) {
    if (-not $record.RegKeyPath -or -not $record.Values) { Write-Warning "Malformed backup record: $($record.Name)"; continue }
    if (-not $PSCmdlet.ShouldProcess($record.Name, 'Restore Win32 app registry entry')) { Write-Host "  Would restore Win32 app: $($record.Name)"; continue }
    if (-not $isAdmin -and $record.RegKeyPath -like 'HKLM:*') { Write-Host "  Skipped (Admin): $($record.Name)"; continue }
    try {
        # The uninstaller usually deletes its Uninstall key - recreate it so the
        # backed-up values can be restored.
        if (-not (Test-Path $record.RegKeyPath)) {
            New-Item -Path $record.RegKeyPath -Force -ErrorAction Stop | Out-Null
            Write-Host "  Recreated registry key: $($record.RegKeyPath)"
        }
        foreach ($value in $record.Values) {
            $val = $value.Value
            $type = if ($value.PSObject.Properties.Name -contains 'Type') { [string]$value.Type } else { '' }
            if ($type -eq 'Binary' -and $val -is [string]) { $val = [byte[]][Convert]::FromBase64String($val) }
            if ($type -and $type -in @('DWord', 'QWord', 'String', 'ExpandString', 'MultiString', 'Binary')) {
                Set-ItemProperty -Path $record.RegKeyPath -Name $value.Name -Value $val -Type $type -ErrorAction Stop
            } else {
                Set-ItemProperty -Path $record.RegKeyPath -Name $value.Name -Value $val -ErrorAction Stop
            }
        }
        Write-Host "  Restored Win32 app: $($record.Name)"
    } catch {
        Write-Error "  Failed to restore $($record.Name): $($_.Exception.Message)"
    }
}

$uwpRemoved = @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'UwpRemoved' })
if ($uwpRemoved.Count) {
    Write-Host ''
    Write-Host "Note: $($uwpRemoved.Count) UWP app(s) were removed via Remove-AppxPackage and cannot be auto-reinstalled:"
    foreach ($u in $uwpRemoved) { Write-Host "  - $($u.Name) [$($u.Scope)]" }
    Write-Host 'To get them back, reinstall from the Microsoft Store (and re-run Windows Update for updates).'
}

$uwpProvisioned = @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'UwpProvisioned' })
if ($uwpProvisioned.Count) {
    Write-Host ''
    Write-Host "Note: $($uwpProvisioned.Count) provisioned app(s) were removed from the Windows image and are NOT auto-restorable:"
    foreach ($p in $uwpProvisioned) {
        $pkgName = if ($p.PSObject.Properties.Name -contains 'PackageName' -and $p.PackageName) { $p.PackageName } else { $p.DisplayName }
        Write-Host "  - $($p.DisplayName) [$pkgName]"
    }
    Write-Host 'To get them back, reinstall the app from the Microsoft Store; new users will then get it provisioned again.'
}
