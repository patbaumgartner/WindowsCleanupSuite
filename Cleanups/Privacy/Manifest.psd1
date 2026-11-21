# Privacy cleanup manifest - telemetry, advertising ID, activity history,
# CEIP, consumer/cloud content, suggested apps, Cortana/search suggestions.
# Based on Raphire Win11Debloat Regfiles (Disable_Telemetry, Disable_Advertising_ID,
# Disable_Activity_History, Disable_CEIP, Disable_Consumer_Experiences,
# Disable_CloudContent, Disable_Cortana, ...) and O&O ShutUp10++ recommendations.
@{
    Project           = 'WindowsCleanupSuite'
    Cleanup           = 'Privacy'
    Description       = 'Disables Windows telemetry, advertising ID, activity history, CEIP, consumer/cloud content, suggested apps (ContentDeliveryManager) and search suggestions. Entries flagged Risky only apply with -AllowRisky.'
    ProtectedPatterns = @('*DSA*', '*Driver*Support*')

    Entries = @(
        # --- Telemetry (Raphire Disable_Telemetry.reg) ---
        @{ RegistryKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name = 'AllowTelemetry'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Telemetry level: Security only (0)' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Telemetry policy: Security only (all users)' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowDeviceNameInTelemetry'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Do not send device name in telemetry' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'DoNotShowFeedbackNotifications'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'No feedback notifications' },
        @{ RegistryKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name = 'AllowTelemetry'; Value = 0; Type = 'DWord'; Reason = 'Telemetry level (current user): Security only' },

        # --- Advertising ID (Raphire Disable_Advertising_ID.reg) ---
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name = 'DisabledByGroupPolicy'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable advertising ID for all users' },
        @{ RegistryKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Value = 0; Type = 'DWord'; Reason = 'Disable advertising ID (current user)' },

        # --- Activity history (Raphire Disable_Activity_History.reg) ---
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableActivityFeed'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable activity feed' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Do not publish user activities' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'UploadUserActivities'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Do not upload user activities' },

        # --- CEIP / AppCompat telemetry ---
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows'; Name = 'CEIPEnable'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Customer Experience Improvement Program' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name = 'AITEnable'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Application Telemetry (AIT)' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name = 'DisableUAR'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable UAR (user activity reporting)' },

        # --- Consumer experiences / cloud content ---
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Microsoft consumer experiences (auto-installed apps)' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableCloudOptimizedContent'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable cloud optimized content' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableSoftLanding'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable soft landing suggestions' },

        # --- Taskbar Widgets / news feed ---
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable taskbar Widgets / news and interests' },

        # --- ContentDeliveryManager: suggested apps, tips, lock-screen ads (HKCU) ---
        @{ RegistryKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'ContentDeliveryAllowed'; Value = 0; Type = 'DWord'; Reason = 'Disable content delivery (suggested apps)' },
        @{ RegistryKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'OemPreInstalledAppsEnabled'; Value = 0; Type = 'DWord'; Reason = 'Disable OEM preinstalled app suggestions' },
        @{ RegistryKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEnabled'; Value = 0; Type = 'DWord'; Reason = 'Disable preinstalled app suggestions' },
        @{ RegistryKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Value = 0; Type = 'DWord'; Reason = 'Disable silent app installs' },
        @{ RegistryKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SoftLandingEnabled'; Value = 0; Type = 'DWord'; Reason = 'Disable soft landing content' },
        @{ RegistryKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338388Enabled'; Value = 0; Type = 'DWord'; Reason = 'Disable subscribed content 338388' },
        @{ RegistryKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338389Enabled'; Value = 0; Type = 'DWord'; Reason = 'Disable subscribed content 338389' },
        @{ RegistryKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338393Enabled'; Value = 0; Type = 'DWord'; Reason = 'Disable subscribed content 338393' },
        @{ RegistryKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353698Enabled'; Value = 0; Type = 'DWord'; Reason = 'Disable subscribed content 353698' },
        @{ RegistryKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SystemPaneSuggestionsEnabled'; Value = 0; Type = 'DWord'; Reason = 'Disable system pane suggestions' },
        @{ RegistryKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'RotatingLockScreenEnabled'; Value = 0; Type = 'DWord'; Reason = 'Disable rotating lock screen' },
        @{ RegistryKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'RotatingLockScreenOverlayEnabled'; Value = 0; Type = 'DWord'; Reason = 'Disable lock screen overlay ads' },

        # --- Search / Cortana suggestions ---
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'AllowCortana'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Cortana in Windows Search' },
        @{ RegistryKey = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'DisableSearchBoxSuggestions'; Value = 1; Type = 'DWord'; Reason = 'Disable search box suggestions' },

        # --- Windows Error Reporting uploads ---
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Windows Error Reporting' }
    )
}
