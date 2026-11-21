# WindowsCleanupSuite - PrivacySettings cleanup manifest.
#
# Level model: 1 (Safe) .. 4 (Extreme). Entries with Level N run when the
# selected menu level is >= N. ProtectedPatterns are never modified.
@{
    Project           = 'WindowsCleanupSuite'
    Cleanup           = 'PrivacySettings'
    Topic             = 'PrivacySettings'
    Description       = 'Disables Windows telemetry, advertising ID, tailored experiences and personalization via HKCU/HKLM privacy settings (win11debloat-style registry policies).'
    ProtectedPatterns = @('*DSA*', '*Driver*Support*')

    Entries = @(
        # --- Level 1 (Safe) - universal privacy toggles (HKCU) ---
        @{ Level = 1; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Value = 0; Reason = 'Disable the Windows advertising ID (tracked ads, suggestions)' },
        @{ Level = 1; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Value = 0; Reason = 'Disable "Tailored experiences" (version/experience personalization)' },
        @{ Level = 1; Path = 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy'; Name = 'HasAccepted'; Value = 0; Reason = 'Decline online speech recognition consent (voice dictation consent)' },
        @{ Level = 1; Path = 'HKCU:\Software\Microsoft\Input\TipPC'; Name = 'Enabled'; Value = 0; Reason = 'Disable "Suggested Input Methods" (implicit pen input prediction)' },
        @{ Level = 1; Path = 'HKCU:\Software\Microsoft\InputPersonalization'; Name = 'RestrictImplicitInkCollection'; Value = 1; Reason = 'Restrict implicit ink collection' },
        @{ Level = 1; Path = 'HKCU:\Software\Microsoft\InputPersonalization'; Name = 'RestrictImplicitTextCollection'; Value = 1; Reason = 'Restrict implicit text collection' },
        @{ Level = 1; Path = 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore'; Name = 'HarvestContacts'; Value = 0; Reason = 'Disable harvesting of contacts for learned input suggestions' },
        @{ Level = 1; Path = 'HKCU:\Software\Microsoft\Personalization\Settings'; Name = 'AcceptedPrivacyPolicy'; Value = 0; Reason = 'Decline the personalization privacy policy' },

        # --- Level 2 (Balanced) ---
        @{ Level = 2; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_TrackProgs'; Value = 0; Reason = 'Stop tracking app launches in the taskbar' },
        @{ Level = 2; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name = 'AllowTelemetry'; Value = 1; Reason = 'Windows 11-safe telemetry level (Win10: 0 = Basic); prevents Win11 breakage' },
        @{ Level = 2; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Value = 0; Reason = 'Disable publishing user activities (timeline/places shared to Microsoft)' },

        # --- Level 3 (Aggressive) ---
        @{ Level = 3; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353694Enabled'; Value = 0; Reason = 'Disable Windows Spotlight (desktop picture suggestions)' },
        @{ Level = 3; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-3423Enabled'; Value = 0; Reason = 'Disable suggested apps & content in Settings/Home' },
        @{ Level = 3; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353695Enabled'; Value = 0; Reason = 'Disable suggested apps in Start menu' },

        # --- Level 4 (Extreme) ---
        # NOTE: AllowTelemetry=0 on Windows 11 would break the OS (min level 1); the
        # script therefore keeps it at 1 on Windows 11 builds (>= 22000) when Level=4.
        @{ Level = 4; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 0; Reason = 'Disable telemetry entirely (stronger than Level 2; Windows 11 keeps min 1)' }
    )
}
