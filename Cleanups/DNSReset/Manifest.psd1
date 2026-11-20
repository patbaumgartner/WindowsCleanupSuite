# DNS reset cleanup manifest - Chainski WindowsCleanerUtility + Marvin700.
@{
    Project = 'WindowsCleanupSuite'
    Cleanup = 'DNSReset'
    Description = 'Resets the DNS resolver cache and network stack settings (Chainski WindowsCleanerUtility DNS reset + Marvin700).'
    ProtectedPatterns = @('*DSA*', '*Driver*Support*')

    Commands = @(
        'ipconfig /release',
        'ipconfig /renew',
        'ipconfig /flushdns',
        'netsh int ip reset',
        'netsh winsock reset',
        'netsh interface ipv4 reset',
        'netsh interface ipv6 reset'
    )
}
