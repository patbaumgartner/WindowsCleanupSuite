# WindowsCleanupSuite - ExtremeExtras cleanup manifest (Level 4 only).
#
# Final-level, aggressive services. Requires Administrator. Changes are backed up
# (JSON records in Backups\ExtremeExtras) so Restore-ExtremeExtras.ps1 can restore
# the previous start types.
@{
    Project           = 'WindowsCleanupSuite'
    Cleanup           = 'ExtremeExtras'
    Topic             = 'ExtremeExtras'
    Level             = 4
    Description       = 'Extreme level-4: disables app readiness, the Store broker and SMS routing (trade-offs accepted). Push notifications stay enabled for tray icons. Requires Administrator.'
    # kDrive 4.0.4 waits for Windows notification registration before creating
    # its tray icon, so the push-notification user service is never touched.
    ProtectedPatterns = @('*DSA*', '*Driver*Support*', 'WpnUserService*')

    Services = @(
        @{ Name = 'AppReadiness'; Level = 4; Reason = 'Disable App Readiness service (extra aggressive app launch readiness)' },
        @{ Name = 'StoreBrokerService'; Level = 4; Reason = 'Disable Windows Store broker (Store background sync/trigger)' },
        @{ Name = 'SmsRouter'; Level = 4; Reason = 'Disable SMS routing service' }
    )
}
