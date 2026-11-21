# WindowsCleanupSuite - OneDrive cleanup manifest.
#
# Requires Administrator for service changes; all changes are backed up.
@{
    Project           = 'WindowsCleanupSuite'
    Cleanup           = 'OneDrive'
    Topic             = 'OneDrive'
    Description       = 'Disables OneDrive auto-startup and the OneDrive sync service (files remain local/in the cloud folder; no data is deleted).'
    ProtectedPatterns = @('*DSA*', '*Driver*Support*')

    # RemoveFromRun - removes the OneDrive entry from the HKCU Run autorun key.
    # SetService - sets the service to the given startup type (Manual keeps it on-demand).
    Entries = @(
        @{ Action = 'RemoveFromRun'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'OneDrive'; Reason = 'Disable OneDrive auto-start (no sync in background)' },
        @{ Action = 'SetService'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\OneDrive.Sync.Service'; Name = 'OneDrive.Sync.Service'; StartupType = 'Manual'; Reason = 'Disable OneDrive sync service (Manual: on-demand)' }
    )
}
