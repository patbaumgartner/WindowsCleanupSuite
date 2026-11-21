# Browsers cleanup manifest - stop Edge/Chrome/Firefox from running in the
# background after close and disable Edge Startup Boost, so they do not slow
# down logon or consume CPU/RAM when not in use.
@{
    Project           = 'WindowsCleanupSuite'
    Cleanup           = 'Browsers'
    Description       = 'Disables browser background modes (Edge/Chrome BackgroundModeEnabled, Firefox BackgroundAppUpdate), Edge Startup Boost and Firefox Pocket. HKLM policies apply to all users.'
    ProtectedPatterns = @('*DSA*', '*Driver*Support*')

    Entries = @(
        # --- Microsoft Edge ---
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'BackgroundModeEnabled'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Edge: do not keep running in background after close' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'StartupBoostEnabled'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Edge: disable Startup Boost (faster sign-in)' },

        # --- Google Chrome ---
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'BackgroundModeEnabled'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Chrome: do not keep running in background after close' },

        # --- Mozilla Firefox ---
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox'; Name = 'BackgroundAppUpdate'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Firefox: disable background app update' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox'; Name = 'DisablePocket'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Firefox: disable Pocket' }
    )
}
