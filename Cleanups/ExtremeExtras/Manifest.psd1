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
    Description       = 'Extreme level-4: fully disables push notifications data, app readiness, the Store broker and SMS routing (trade-offs accepted). Requires Administrator.'
    ProtectedPatterns = @('*DSA*', '*Driver*Support*')

    Services = @(
        @{ Name = 'WpnUserService'; Level = 4; Reason = 'Disable Windows push notification data service (toast/notification back end); do not use before apps are set up' },
        @{ Name = 'AppReadiness'; Level = 4; Reason = 'Disable App Readiness service (extra aggressive app launch readiness)' },
        @{ Name = 'StoreBrokerService'; Level = 4; Reason = 'Disable Windows Store broker (Store background sync/trigger)' },
        @{ Name = 'SmsRouter'; Level = 4; Reason = 'Disable SMS routing service' }
    )
}
