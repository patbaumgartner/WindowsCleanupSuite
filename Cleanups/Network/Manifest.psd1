# Network cleanup manifest - LLMNR off, Delivery Optimization off (service +
# policy), NetBIOS over TCP/IP off per adapter (Risky), fast public DNS (Risky).
@{
    Project           = 'WindowsCleanupSuite'
    Cleanup           = 'Network'
    Description       = 'Reduces background network chatter and speeds up name resolution: disables LLMNR multicast, Delivery Optimization peer caching (DoSvc -> Manual + policy), optionally NetBIOS over TCP/IP (Risky) and sets fast public DNS resolvers (Risky).'
    ProtectedPatterns = @('*DSA*', '*Driver*Support*')

    # Generic registry values (see Core\CleanupEngine.ps1 Invoke-SuiteRegistryEntry).
    # PathPattern expands to one key per matching subkey (here: per network adapter).
    Entries = @(
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'; Name = 'EnableMulticast'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable LLMNR (Link-Local Multicast Name Resolution)' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DODownloadMode'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Delivery Optimization: HTTP only, no peer caching' },
        @{ PathPattern = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*'; Name = 'NetbiosOptions'; Value = 2; Type = 'DWord'; RequiresAdmin = $true; Risky = $true; Reason = 'Disable NetBIOS over TCP/IP on all adapters (Risky: breaks legacy SMB name browsing)' }
    )

    # Services set to the given start mode (backed up first).
    Services = @(
        @{ Name = 'DoSvc'; Mode = 'Manual'; Reason = 'Delivery Optimization service (on-demand only)' }
    )

    # DNS: set static resolvers on all physical IPv4 adapters. Risky because it
    # changes name resolution; restore resets adapters back to DHCP.
    Dns = @{
        Enabled  = $true
        Servers  = @('1.1.1.1', '8.8.8.8')
        Risky    = $true
        Reason   = 'Use fast public DNS resolvers (Cloudflare/Google) on all physical adapters'
    }
}
