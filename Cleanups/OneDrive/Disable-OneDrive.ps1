#requires -Version 5.1
<#
.SYNOPSIS
    Disables OneDrive auto-start and background sync service.

.DESCRIPTION
    Data-driven from Cleanups\OneDrive\OneDrive.psd1:
      - RemoveFromRun: removes the OneDrive entry from HKCU\...\Run (backed up).
      - SetService:    sets the named service to the given startup type (backed up).

    The OneDrive app and files are not deleted or touched.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\OneDrive\Disable-OneDrive.ps1'
    & 'WindowsCleanupSuite\Cleanups\OneDrive\Disable-OneDrive.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest   = Get-SuiteManifest -CleanupName 'OneDrive'
$backupRoot = Get-SuiteBackupRoot -CleanupName 'OneDrive'
$isAdmin    = Test-SuiteIsAdmin

foreach ($entry in @($manifest.Entries)) {
    switch ($entry.Action) {
        'RemoveFromRun' {
            $flagPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
            $flag = Get-WCSRegistryBinaryValue -Path $flagPath -Name $entry.Name
            $flagEnabled = ($null -eq $flag -or -not (Test-WCSStartupDisabledFlag -Value $flag))
            $runExists = $false
            if (Test-Path $entry.Path) {
                $runExists = @((Get-Item -Path $entry.Path).Property) -contains $entry.Name
            }
            if (-not $runExists -and -not $flagEnabled) {
                Write-Host "  [od]      Already absent/disabled: $($entry.Name) - $($entry.Reason)"
                continue
            }
            if (-not $PSCmdlet.ShouldProcess($entry.Name, "Remove Run entry and disable startup flag - $($entry.Reason)")) {
                Write-Host "  [od]      Would remove Run entry / disable startup flag: $($entry.Name)"
                continue
            }
            # .($entry.Name), NOT .$entry.Name - the chained form looks up a member
            # named after the entry object itself and always yields $null.
            if ($runExists) {
                $value = (Get-ItemProperty -Path $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue).($entry.Name)
                New-SuiteBackupFile -BackupRoot $backupRoot -FileName "run_$(Get-SuiteSafeFileName $entry.Name).txt" -Record @{
                    Type = 'RunEntry'; Path = $entry.Path; Name = $entry.Name; Value = [string]$value; Reason = $entry.Reason
                }
                try {
                    Remove-ItemProperty -Path $entry.Path -Name $entry.Name -ErrorAction Stop
                    Write-Host "  [od]      Removed Run entry: $($entry.Name)"
                } catch {
                    Write-Warning "  [od]      Failed to remove Run entry $($entry.Name): $($_.Exception.Message)"
                }
            }
            if ($flagEnabled) {
                New-SuiteBackupFile -BackupRoot $backupRoot -FileName "startupapproved_$(Get-SuiteSafeFileName $entry.Name).json" -Record @{
                    Type = 'StartupApprovedFlag'; Path = $flagPath; Name = $entry.Name
                    ValueBase64 = if ($null -eq $flag) { '' } else { [Convert]::ToBase64String($flag) }
                    Existed = ($null -ne $flag); Reason = $entry.Reason
                }
                try {
                    if (-not (Test-Path $flagPath)) { New-Item -Path $flagPath -Force | Out-Null }
                    Set-ItemProperty -Path $flagPath -Name $entry.Name -Value (New-WCSStartupDisabledFlag -Existing $flag) -Type Binary -ErrorAction Stop
                    Write-Host "  [od]      Disabled startup flag: $($entry.Name)"
                } catch {
                    Write-Warning "  [od]      Failed to disable startup flag $($entry.Name): $($_.Exception.Message)"
                }
            }
        }
        'SetService' {
            if (-not $isAdmin -and -not $WhatIfPreference) {
                Write-Warning "  [od]      Skipped (requires Administrator): $($entry.Name)"
                continue
            }
            $obj = Get-Service -Name $entry.Name -ErrorAction SilentlyContinue
            if (-not $obj) {
                Write-Host "  [od]      No match: $($entry.Name) - $($entry.Reason)"
                continue
            }
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($entry.Name)"
            $start = $null
            try { $start = (Get-ItemProperty -Path $regPath -Name 'Start' -ErrorAction Stop).Start } catch { $start = $null }
            if ($null -ne $start -and [int]$start -eq 3) {
                Write-Host "  [od]      Already Manual: $($entry.Name)"
                continue
            }
            if (-not $PSCmdlet.ShouldProcess($entry.Name, "Set start type to $($entry.StartupType) - $($entry.Reason)")) {
                Write-Host "  [od]      Would set: $($entry.Name) -> $($entry.StartupType)"
                continue
            }
            New-SuiteBackupFile -BackupRoot $backupRoot -FileName "svc_$($entry.Name).txt" -Record @{
                Type = 'Service'; Name = $entry.Name; StartType = [int]$start; Reason = $entry.Reason
            }
            try {
                Set-Service -Name $entry.Name -StartupType $entry.StartupType -ErrorAction Stop
                Write-Host "  [od]      Set: $($entry.Name) -> $($entry.StartupType)"
            } catch {
                try {
                    $v = switch ($entry.StartupType) { 'Automatic' { 2 } 'Disabled' { 4 } default { 3 } }
                    Set-ItemProperty -Path $regPath -Name 'Start' -Value $v -Type DWord -ErrorAction Stop
                    Write-Host "  [od]      Set (registry): $($entry.Name) -> $v"
                } catch {
                    Write-Warning "  [od]      Failed: $($entry.Name) - $($_.Exception.Message)"
                }
            }
        }
        default {
            Write-Warning "  [od]      Unknown action '$($entry.Action)' - $($entry.Name)"
        }
    }
}
