#requires -Version 5.1
<#
.SYNOPSIS
    Network cleanup: disables LLMNR, Delivery Optimization, optionally NetBIOS
    over TCP/IP and sets fast public DNS resolvers (all data-driven).

.DESCRIPTION
    - Registry entries from Manifest.psd1 (LLMNR off, DO policy off, NetBIOS
      per adapter when -AllowRisky) via the shared registry engine.
    - Services from Manifest.psd1 (DoSvc -> Manual).
    - DNS servers from Manifest.psd1 (applied only with -AllowRisky); the
      current per-adapter DNS configuration is backed up first.
    Everything is backed up to Backups\Network\; restore with Restore-Network.ps1.
    HKLM/service/DNS changes require Administrator.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.PARAMETER AllowRisky
    Also apply the Risky parts (NetBIOS off, static DNS resolvers).

.EXAMPLE
    & '.\Disable-Network.ps1' -WhatIf
    & '.\Disable-Network.ps1' -AllowRisky
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$AllowRisky
)

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest   = Get-SuiteManifest -CleanupName 'Network'
$backupRoot = Get-SuiteBackupRoot -CleanupName 'Network'
$isAdmin    = Test-SuiteIsAdmin

if (-not $isAdmin -and -not $WhatIfPreference) {
    Write-Warning 'Network: HKLM/service/DNS changes require Administrator; nothing was applied.'
    return
}

# --- 1. Registry entries (LLMNR, Delivery Optimization policy, NetBIOS) ---
foreach ($entry in @($manifest.Entries)) {
    Invoke-SuiteRegistryEntry -Entry $entry -Manifest $manifest -BackupRoot $backupRoot -Preview:$WhatIfPreference -AllowRisky:$AllowRisky
}

# --- 2. Services (Delivery Optimization -> Manual) ---
foreach ($entry in @($manifest.Services)) {
    $mode = if ($entry.Mode) { $entry.Mode } else { 'Manual' }
    Invoke-SuiteServiceEntry -Entry $entry -Manifest $manifest -BackupRoot $backupRoot -Mode $mode -Preview:$WhatIfPreference -AllowRisky:$AllowRisky
}

# --- 3. DNS resolvers (Risky) ---
$dns = $manifest.Dns
if ($dns -and $dns.Enabled) {
    if ($dns.Risky -and -not $AllowRisky) {
        Write-Host "  [dns]     Skipped (Risky - pass -AllowRisky): set DNS to $($dns.Servers -join '/') - $($dns.Reason)"
    } elseif (-not $isAdmin -and -not $WhatIfPreference) {
        Write-Host "  [dns]     Skipped (Admin): set DNS to $($dns.Servers -join '/')"
    } else {
        $ifaces = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue)
        if (-not $ifaces.Count) { $ifaces = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.HardwareInterface }) }
        foreach ($iface in $ifaces) {
            $current = $null; $wasDhcp = $false
            try {
                $addr = Get-DnsClientServerAddress -InterfaceIndex $iface.ifIndex -AddressFamily IPv4 -ErrorAction Stop
                $current = @($addr.ServerAddresses)
                $wasDhcp = ($addr.Dhcp -eq 'Enabled' -or $addr.ConnectionSpecificSuffix -eq '' -and $addr.Dhcp)
                try { $wasDhcp = ((Get-NetIPInterface -InterfaceIndex $iface.ifIndex -AddressFamily IPv4 -ErrorAction Stop).Dhcp) -eq 'Enabled' } catch {}
            } catch { $current = @(); $wasDhcp = $true }

            if ($WhatIfPreference) {
                Write-Host "  [dns]     Would set DNS on '$($iface.Name)' (ifIndex $($iface.ifIndex)) to $($dns.Servers -join ', ') - $($dns.Reason)"
                continue
            }

            New-SuiteBackupFile -BackupRoot $backupRoot -FileName "dns_if$($iface.ifIndex)_$(Get-SuiteSafeFileName $iface.Name).json" -Record @{
                Type = 'Dns'; InterfaceIndex = $iface.ifIndex; InterfaceAlias = $iface.Name
                WasDhcp = [bool]$wasDhcp; PreviousServers = $current; NewServers = @($dns.Servers); Reason = $dns.Reason
            }

            try {
                Set-DnsClientServerAddress -InterfaceIndex $iface.ifIndex -ServerAddresses $dns.Servers -ErrorAction Stop
                Write-Host "  [dns]     Set DNS on '$($iface.Name)' to $($dns.Servers -join ', ')"
            } catch {
                Write-Warning "  [dns]     Failed on '$($iface.Name)': $($_.Exception.Message)"
            }
        }
    }
}

Write-Host ''
Write-Host "Done. Backups are in $backupRoot"
