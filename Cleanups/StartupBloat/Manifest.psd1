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
        @{ Hive = 'HKCU'; Name = 'Skype for Desktop';                   Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; NamePattern = '*WhatsApp*';                   Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; NamePattern = '*kDrive*';                     Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; NamePattern = '*Dropbox*';                    Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; NamePattern = '*Slack*';                      Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },

        # --- HKLM entries (elevation required to delete the value; the per-user
        #     StartupApproved\Run32 flag for 32-bit entries is set without elevation) ---
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
        @{ Hive = 'HKLM'; Name = 'Intel Graphics Software';             Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKLM'; Name = 'Dropbox';                             Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKLM'; Name = 'OneDrive';                            Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' }
    )

    # Some apps rewrite their own autorun when they are launched manually.
    # Turning off the app-internal setting keeps manual launches working without
    # re-creating the Run value or re-enabling the StartupApproved flag.
    AppAutoStartSettings = @(
        @{
            Name = 'kDrive'; Kind = 'Sqlite'; PathKind = 'LocalAppData'; Path = 'kDrive\.parms.db'
            Table = 'parameters'; Column = 'autoStart'; DisabledValue = 0
            ProcessNames = @('kDrive')
            Reason = 'kDrive re-creates its Run entry and re-enables the startup flag on every launch when this is 1.'
        },
        @{
            Name = 'OneDrive'; Kind = 'Registry'; Path = 'HKCU:\Software\Microsoft\OneDrive'
            ValueName = 'AutoStartEnabled'; DisabledValue = 0
            ProcessNames = @('OneDrive')
            Reason = 'OneDrive re-creates its Run entry when launched manually when this is 1.'
        }
    )

    # Startup folder shortcuts are MOVED to Backups\StartupBloat\StartupFolder
    # (not deleted), so the app can still be launched normally from the Start menu.
    StartupFolders = @(
        @{ Scope = 'User';     NamePattern = '*OneDrive*' },
        @{ Scope = 'User';     NamePattern = '*Dropbox*' },
        @{ Scope = 'User';     NamePattern = '*WhatsApp*' },
        @{ Scope = 'User';     NamePattern = '*kDrive*' },
        @{ Scope = 'User';     NamePattern = '*Teams*' },
        @{ Scope = 'User';     NamePattern = '*Slack*' },
        @{ Scope = 'User';     NamePattern = '*Discord*' },
        @{ Scope = 'User';     NamePattern = '*Skype*' },
        @{ Scope = 'User';     NamePattern = '*Zoom*' },
        @{ Scope = 'User';     NamePattern = '*CCleaner*' },
        @{ Scope = 'AllUsers'; NamePattern = '*OneDrive*' },
        @{ Scope = 'AllUsers'; NamePattern = '*Dropbox*' },
        @{ Scope = 'AllUsers'; NamePattern = '*WhatsApp*' },
        @{ Scope = 'AllUsers'; NamePattern = '*kDrive*' },
        @{ Scope = 'AllUsers'; NamePattern = '*Teams*' },
        @{ Scope = 'AllUsers'; NamePattern = '*Slack*' },
        @{ Scope = 'AllUsers'; NamePattern = '*Discord*' },
        @{ Scope = 'AllUsers'; NamePattern = '*Skype*' },
        @{ Scope = 'AllUsers'; NamePattern = '*Zoom*' }
    )
}
