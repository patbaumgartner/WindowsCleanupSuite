# StartupBloat cleanup manifest.
#
# Data-driven list of auto-start targets: one entry per 'Name' or 'NamePattern',
# each targeting a registry path. 'HKCU' entries need no elevation; 'HKLM'
# entries require an elevated session.
@{
    Project           = 'WindowsCleanupSuite'
    Cleanup           = 'StartupBloat'
    Description       = 'Disables nonessential auto-start registry entries that slow down Windows login.'
    ProtectedPatterns = @(
        '*DSA*',
        '*Driver*Support*',
        'DSATray*'
    )

    Targets = @(
        # --- HKCU entries (no elevation required) ---
        @{ Hive = 'HKCU'; Name = 'com.squirrel.slack.slack';            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Name = 'Discord';                             Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Name = 'Docker Desktop';                     Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Name = 'Teams';                               Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; NamePattern = 'MicrosoftEdgeAutoLaunch_*';    Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Name = 'kDrive';                              Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Name = 'Microsoft.Lists';                     Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Name = 'OneDrive';                            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Name = 'Phone Link';                          Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Name = 'WhatsApp';                            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Name = 'CCleaner';                            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Name = 'Intel Graphics Software';            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Name = 'Skype';                               Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Name = 'zoommsirepair';                       Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Name = 'BraveSoftware Update';                Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Name = 'Lync';                                Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Name = 'Adobe Acrobat Synchronizer';          Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; NamePattern = 'GoogleChromeAutoLaunch_*';     Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },

        # --- HKLM entries (elevation required) ---
        @{ Hive = 'HKLM'; Name = 'Dropbox';                             Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKLM'; Name = 'Discord';                             Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKLM'; Name = 'OneDrive';                            Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKLM'; Name = 'CCleaner';                            Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKLM'; Name = 'InstallHelper';                       Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKLM'; Name = 'Cisco Secure Client';                 Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKLM'; Name = 'AnalyticsSrv';                        Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKLM'; Name = 'ConnectionCenter';                    Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKLM'; Name = 'Redirector';                          Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKLM'; Name = 'CtxsDPS';                             Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKLM'; Name = 'Intel® Graphics Software';            Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKLM'; Name = 'Intel Graphics Software';             Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' }
    )
}
