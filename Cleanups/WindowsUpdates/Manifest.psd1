# WindowsCleanupSuite - WindowsUpdates cleanup manifest.
#
# Registry entries applied by Disable-WindowsUpdates.ps1. Changes are backed up
# (JSON records in Backups\WindowsUpdates) so Restore-WindowsUpdates.ps1 can
# restore the previous values. Services entries set the named service to a
# given startup type (requires Administrator).
@{
    Project           = 'WindowsCleanupSuite'
    Cleanup           = 'WindowsUpdates'
    Topic             = 'WindowsUpdates'
    Description       = 'Adjusts Windows Update settings: service to Manual, disables auto-restart and driver updates, disables peer download sharing.'
    ProtectedPatterns = @('*DSA*', '*Driver*Support*')

    Services = @(
        @{ Name = 'wuauserv'; Action = 'Manual'; Reason = 'Set Windows Update service to Manual (no automatic installs; on-demand only)' }
    )

    RegistryEntries = @(
        @{ Level = 1; Path = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'; Name = 'IsContinuousInnovationOptedIn'; Value = 0; Reason = 'Disable "Get the latest updates as soon as they are available"' },
        @{ Level = 1; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'ExcludeWUDriversInQualityUpdate'; Value = 1; Reason = 'Exclude drivers from Windows Update (keep drivers separate)' },
        @{ Level = 1; Path = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\PolicyState'; Name = 'ExcludeWUDrivers'; Value = 1; Reason = 'Exclude drivers from Windows Update (native policy for Windows 11)' },
        @{ Level = 1; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching'; Name = 'SearchOrderConfig'; Value = 3; Reason = 'Disable driver auto-update on Windows Update and give drivers lower auto priority' },
        @{ Level = 2; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings'; Name = 'DownloadMode'; Value = 0; Reason = 'Disable Delivery Optimization peer sharing of updates/apps' },
        @{ Level = 2; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'; Name = 'HiberbootEnabled'; Value = 0; Reason = 'Disable Fast Startup (full shutdown; less stale-state issues)' }
    )
}
