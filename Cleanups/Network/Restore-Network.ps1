#requires -Version 5.1
<#
.SYNOPSIS
    Restores network settings backed up by Disable-Network.ps1 (registry values,
    service start types, per-adapter DNS servers).

.PARAMETER WhatIf
    Preview mode - shows what would be restored without touching the system.

.EXAMPLE
    & '.\Restore-Network.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$backupRoot = Get-SuiteBackupRoot -CleanupName 'Network'

# Registry values and service start types.
Restore-SuiteRegistryRecords -BackupRoot $backupRoot -Preview:$WhatIfPreference
Restore-SuiteServiceRecords -BackupRoot $backupRoot -Preview:$WhatIfPreference

# DNS: reset adapters back to DHCP, or re-apply the backed-up static servers.
foreach ($record in @(Get-SuiteBackupRecords -BackupRoot $backupRoot | Where-Object { $_.Type -eq 'Dns' })) {
    if (-not $record.InterfaceIndex) { continue }
    if ($WhatIfPreference) {
        Write-Host "  [dns]     Would restore DNS on '$($record.InterfaceAlias)' (ifIndex $($record.InterfaceIndex))"
        continue
    }
    try {
        if ($record.WasDhcp) {
            Set-DnsClientServerAddress -InterfaceIndex $record.InterfaceIndex -ResetServerAddresses -ErrorAction Stop
        } elseif (@($record.PreviousServers).Count) {
            Set-DnsClientServerAddress -InterfaceIndex $record.InterfaceIndex -ServerAddresses @($record.PreviousServers) -ErrorAction Stop
        } else {
            Set-DnsClientServerAddress -InterfaceIndex $record.InterfaceIndex -ResetServerAddresses -ErrorAction Stop
        }
        Write-Host "  [dns]     Restored DNS on '$($record.InterfaceAlias)'"
    } catch {
        Write-Warning "  [dns]     Restore failed on '$($record.InterfaceAlias)': $($_.Exception.Message)"
    }
}

Write-Host 'Done.'
