# WindowsSpeedup cleanup manifest.
#
# Data-driven lists of services, scheduled tasks, startup apps, AppModel startup
# tasks, process stops and visual effects to disable. Entries with Profile =
# 'Balanced' run by default; entries with Profile = 'Maximum' run only with
# -Profile Maximum. ProtectedPatterns are never modified, in any profile/mode.
@{
    Project           = 'WindowsCleanupSuite'
    Cleanup           = 'WindowsSpeedup'
    Description       = 'Disables nonessential Windows services and scheduled tasks to speed up boot and reduce background load.'
    ProtectedPatterns = @(
        '*DSA*',
        '*Driver*Support*'
    )
    LoginSafeExclusions = @(
        'csc_vpnagent',
        'CtxsDPS',
        'CWAUpdaterService',
        'WSearch'
    )
    VisualEffects     = $true

    Services = @(
        # --- Balanced (safe) services ---
        @{ Name = 'DiagTrack'; Reason = 'Microsoft Connected User Experiences and Telemetry'; Profile = 'Balanced' },
        @{ Name = 'SupportAssistAgent'; Reason = 'Dell SupportAssist agent'; Profile = 'Balanced' },
        @{ Name = 'DellTechHub'; Reason = 'Dell TechHub'; Profile = 'Balanced' },
        @{ Name = 'DellClientManagementService'; Reason = 'Dell Client Management Service'; Profile = 'Balanced' },
        @{ Name = 'Dell Digital Delivery Services'; Reason = 'Dell Digital Delivery Services'; Profile = 'Balanced' },
        @{ Name = 'DellPairService'; Reason = 'Dell Pair Service'; Profile = 'Balanced' },
        @{ Name = 'Dell SupportAssist Remediation'; Reason = 'Dell SupportAssist Remediation'; Profile = 'Balanced' },
        @{ Name = 'SystemUsageReportSvc_QUEENCREEK'; Reason = 'Intel System Usage Report (telemetry)'; Profile = 'Balanced' },
        @{ Name = 'dptftcs'; Reason = 'Intel Dynamic Tuning Technology Telemetry'; Profile = 'Balanced' },
        @{ Name = 'ESRV_SVC_QUEENCREEK'; Reason = 'Intel Energy Server Service (telemetry)'; Profile = 'Balanced' },
        @{ Name = 'XTU3SERVICE'; Reason = 'Intel XTU overclock service (not overclocking)'; Profile = 'Balanced' },
        @{ Name = 'Killer Analytics Service'; Reason = 'Killer Network Analytics'; Profile = 'Balanced' },
        @{ Name = 'Killer Provider Data Helper Service'; Reason = 'Killer Provider Data Helper'; Profile = 'Balanced' },
        @{ Name = 'TeamViewer'; Reason = 'TeamViewer always-on background service'; Profile = 'Balanced' },
        @{ Name = 'ZoomCptService'; Reason = 'Zoom VDI Sharing Service'; Profile = 'Balanced' },
        @{ Name = 'ZoomCptServiceForVDIPluginMgmt'; Reason = 'Zoom VDI Plugin Management'; Profile = 'Balanced' },
        @{ Name = 'StiSvc'; Reason = 'Windows Image Acquisition (scanner support)'; Profile = 'Balanced' },
        @{ Name = 'PCManager Service Store'; Reason = 'Microsoft PC Manager background service'; Profile = 'Balanced' },
        @{ Name = 'PhoneSvc'; Reason = 'Phone Link background service'; Profile = 'Balanced' },
        @{ Name = 'FusionService'; Reason = 'Dell Fusion background service'; Profile = 'Balanced' },
        @{ Name = 'OptionsPlusUpdaterService'; Reason = 'Logitech Options+ updater service'; Profile = 'Balanced' },
        @{ Name = 'LogiSyncStub'; Reason = 'Logitech sync helper service'; Profile = 'Balanced' },
        @{ Name = 'edgeupdate'; Reason = 'Microsoft Edge updater service'; Profile = 'Balanced' },
        @{ NamePattern = 'DropboxUpdaterInternalService*'; Reason = 'Dropbox updater internal service'; Profile = 'Balanced' },
        @{ NamePattern = 'DropboxUpdaterService*'; Reason = 'Dropbox updater service'; Profile = 'Balanced' },
        @{ NamePattern = 'GoogleUpdaterInternalService*'; Reason = 'Google updater internal service'; Profile = 'Balanced' },
        @{ NamePattern = 'GoogleUpdaterService*'; Reason = 'Google updater service'; Profile = 'Balanced' },
        @{ Name = 'InventorySvc'; Reason = 'Windows compatibility inventory service'; Profile = 'Balanced' },
        @{ Name = 'TrkWks'; Reason = 'Distributed link tracking client'; Profile = 'Balanced' },
        @{ Name = 'MapsBroker'; Reason = 'Downloaded maps manager'; Profile = 'Balanced' },
        @{ Name = 'dmwappushservice'; Reason = 'Device management WAP push routing service'; Profile = 'Balanced' },
        @{ Name = 'DusmSvc'; Reason = 'Data usage monitoring service'; Profile = 'Balanced' },

        # --- Maximum (aggressive) services ---
        @{ Name = 'CCleaner7'; Reason = 'CCleaner realtime/background service'; Profile = 'Maximum' },
        @{ Name = 'com.docker.service'; Reason = 'Docker Desktop service (set manual when not actively using Docker)'; Profile = 'Maximum' },
        @{ Name = 'IntelGraphicsSoftwareService'; Reason = 'Intel graphics helper service'; Profile = 'Maximum' },
        @{ Name = 'WSLService'; Reason = 'WSL service (set manual if not using WSL every boot)'; Profile = 'Maximum' },
        @{ Name = 'CDPSvc'; Reason = 'Connected Devices Platform service (Phone Link/cross-device triggers)'; Profile = 'Maximum'; Risky = $true },
        @{ NamePattern = 'CDPUserSvc_*'; Reason = 'Connected Devices Platform per-user service (Phone Link/cross-device triggers)'; Profile = 'Maximum'; Risky = $true },
        @{ Name = 'ClickToRunSvc'; Reason = 'Microsoft Office Click-to-Run background service'; Profile = 'Maximum' },
        @{ Name = 'DbxSvc'; Reason = 'Dropbox background service'; Profile = 'Maximum' },
        @{ Name = 'CmService'; Reason = 'Windows container manager service'; Profile = 'Maximum' },
        @{ Name = 'csc_vpnagent'; Reason = 'Cisco Secure Client VPN agent (manual unless VPN always-on is required)'; Profile = 'Maximum'; Risky = $true },
        @{ Name = 'CtxsDPS'; Reason = 'Citrix Device Posture service (manual unless always required)'; Profile = 'Maximum'; Risky = $true },
        @{ Name = 'CWAUpdaterService'; Reason = 'Citrix Workspace updater service'; Profile = 'Maximum'; Risky = $true },
        @{ Name = 'Killer Network Service'; Reason = 'Killer suite background service (driver still works)'; Profile = 'Maximum' },
        @{ Name = 'WSearch'; Reason = 'Windows Search indexing service (maximum performance profile)'; Profile = 'Maximum'; Risky = $true },

        # --- Marvin700 WindowsTweaks_Services additions (Disabled) ---
        @{ Name = 'WpcMonSvc'; Reason = 'Windows PushToInstall Service (telemetry)'; Profile = 'Balanced' },
        @{ Name = 'SharedRealitySvc'; Reason = 'Shared Reality Service (telemetry)'; Profile = 'Balanced' },
        @{ Name = 'autotimesvc'; Reason = 'Auto Time Service'; Profile = 'Balanced' },
        @{ Name = 'wisvc'; Reason = 'Windows Insiders Service'; Profile = 'Balanced' },
        @{ Name = 'SDRSVC'; Reason = 'System Restore Service (set point)'; Profile = 'Balanced' },
        @{ Name = 'MixedRealityOpenXRSvc'; Reason = 'Mixed Reality OpenXR Service'; Profile = 'Balanced' },
        @{ Name = 'WalletService'; Reason = 'Wallet Service'; Profile = 'Balanced' },
        @{ Name = 'SmsRouter'; Reason = 'SMS Router Service'; Profile = 'Balanced' },
        @{ Name = 'MicrosoftEdgeElevationService'; Reason = 'Microsoft Edge Elevation Service'; Profile = 'Balanced' },
        @{ Name = 'RetailDemo'; Reason = 'Retail Demo Service'; Profile = 'Balanced' },
        @{ Name = 'MessagingService'; Reason = 'Messaging Service'; Profile = 'Balanced' },
        @{ Name = 'diagsvc'; Reason = 'Diagnostic Hub Service'; Profile = 'Balanced' },
        @{ Name = 'WerSvc'; Reason = 'Windows Error Reporting Service'; Profile = 'Balanced' },
        @{ Name = 'wercplsupport'; Reason = 'Windows Error Reporting Control Panel Help'; Profile = 'Balanced' },
        @{ Name = 'SEMgrSvc'; Reason = 'SEMgr Service'; Profile = 'Balanced' },
        @{ Name = 'ScDeviceEnum'; Reason = 'Scanner Device Enumeration Service'; Profile = 'Balanced' },
        @{ Name = 'TabletInputService'; Reason = 'Tablet Input Service'; Profile = 'Balanced' },
        @{ Name = 'icssvc'; Reason = 'Internet Connection Sharing Service'; Profile = 'Balanced' },
        @{ Name = 'OneSyncSvc'; Reason = 'OneSync Service'; Profile = 'Balanced' },

        # --- Marvin700 WindowsTweaks_Services additions (Manual) ---
        @{ Name = 'BITS'; Reason = 'Background Intelligent Transfer Service (on-demand)'; Profile = 'Balanced' },
        @{ Name = 'SCardSvr'; Reason = 'Smart Card Service'; Profile = 'Balanced' },
        @{ Name = 'WbioSrvc'; Reason = 'Windows Biometric Service (fingerprint/facial)'; Profile = 'Balanced' },
        @{ Name = 'WMPNetworkSvc'; Reason = 'Windows Media Player Network Sharing Service'; Profile = 'Balanced' },
        @{ Name = 'WpnService'; Reason = 'Windows Push Notification Services (WNS)'; Profile = 'Balanced' }
    )

    Tasks = @(
        # --- Balanced ---
        @{ Path = '\Microsoft\XblGameSave\'; Name = 'XblGameSaveTask'; Reason = 'Xbox game save sync'; Profile = 'Balanced' },
        @{ Path = '\Mozilla\'; NamePattern = 'Firefox Background Update*'; Reason = 'Firefox background updater'; Profile = 'Balanced' },
        @{ Path = '\Mozilla\'; NamePattern = 'Firefox Default Browser Agent*'; Reason = 'Firefox default browser agent'; Profile = 'Balanced' },
        @{ Path = '\GoogleUserPEH\'; Name = 'RunPlatformExperienceHelperOnUnlock'; Reason = 'Google platform experience helper on unlock'; Profile = 'Balanced' },
        @{ Path = '\GoogleUserPEH\'; Name = 'RunPlatformExperienceHelper_Daily'; Reason = 'Google platform experience helper daily'; Profile = 'Balanced' },
        @{ Path = '\GoogleUserPEH\'; Name = 'RunPlatformExperienceHelper_Metrics'; Reason = 'Google platform experience helper metrics'; Profile = 'Balanced' },
        @{ PathPattern = '\SoftLanding\*\'; NamePattern = 'SoftLandingCreativeManagementTask'; Reason = 'SoftLanding creative management (adware task)'; Profile = 'Balanced' },
        @{ Path = '\'; NamePattern = 'IntelSURQC-Upgrade*'; Reason = 'Intel telemetry upgrade task'; Profile = 'Balanced' },
        @{ Path = '\'; Name = 'USER_ESRV_SVC_QUEENCREEK'; Reason = 'Intel ESRV per-user task'; Profile = 'Balanced' },
        @{ Path = '\Intel\'; Name = 'Intel Telemetry 3'; Reason = 'Intel telemetry scheduled task'; Profile = 'Balanced' },
        @{ Path = '\'; Name = 'RNIdle Task'; Reason = 'Killer/Rivet Networks idle helper task'; Profile = 'Balanced' },
        @{ Path = '\'; Name = 'Dell SupportAssistAgent AutoUpdate'; Reason = 'Dell SupportAssist auto-update task'; Profile = 'Balanced' },
        @{ Path = '\'; NamePattern = 'MicrosoftEdgeUpdateTaskMachineCore*'; Reason = 'Microsoft Edge updater core task'; Profile = 'Balanced' },
        @{ Path = '\'; NamePattern = 'MicrosoftEdgeUpdateTaskMachineUA*'; Reason = 'Microsoft Edge updater task'; Profile = 'Balanced' },
        @{ Path = '\DropboxSystem\DropboxUpdater\'; NamePattern = 'DropboxUpdaterTaskSystem*'; Reason = 'Dropbox updater scheduled task'; Profile = 'Balanced' },
        @{ Path = '\GoogleSystem\GoogleUpdater\'; NamePattern = 'GoogleUpdaterTaskSystem*'; Reason = 'Google updater scheduled task'; Profile = 'Balanced' },

        # --- Maximum ---
        @{ Path = '\Piriform\'; NamePattern = 'CCleaner*'; Reason = 'CCleaner background/login/reporting task'; Profile = 'Maximum' },
        @{ Path = '\PowerToys\'; NamePattern = 'Autorun*'; Reason = 'PowerToys logon autorun task'; Profile = 'Maximum' },
        @{ Path = '\Microsoft\Office\'; Name = 'Office Actions Server'; Reason = 'Office actions availability task'; Profile = 'Maximum' },
        @{ Path = '\Microsoft\Office\'; Name = 'Office ClickToRun Service Monitor'; Reason = 'Office Click-to-Run service monitor task'; Profile = 'Maximum' },
        @{ Path = '\Microsoft\Office\'; Name = 'Office Automatic Updates 2.0'; Reason = 'Office background updater task'; Profile = 'Maximum' },
        @{ Path = '\Microsoft\Office\'; Name = 'Office Background Push Maintenance'; Reason = 'Office background push task'; Profile = 'Maximum' },
        @{ Path = '\Microsoft\Office\'; Name = 'Office Feature Updates'; Reason = 'Office feature update task'; Profile = 'Maximum' },
        @{ Path = '\Microsoft\Office\'; Name = 'Office Feature Updates Logon'; Reason = 'Office feature update task at logon'; Profile = 'Maximum' },
        @{ Path = '\Microsoft\Office\'; Name = 'Office Startup Maintenance'; Reason = 'Office startup maintenance task'; Profile = 'Maximum' },
        @{ Path = '\Microsoft\Office\'; Name = 'Office Serviceability Manager'; Reason = 'Office serviceability maintenance task'; Profile = 'Maximum' },
        @{ Path = '\Microsoft\Office\'; Name = 'Office Performance Monitor'; Reason = 'Office performance monitor task'; Profile = 'Maximum' },
        @{ Path = '\Microsoft\Office\'; Name = 'Office Feature Updates 2.0'; Reason = 'Office feature updates 2.0 task'; Profile = 'Maximum' },
        @{ Path = '\Microsoft\Office\'; Name = 'Office Telemetry Agent'; Reason = 'Office telemetry agent task'; Profile = 'Maximum' },
        @{ Path = '\Microsoft\Windows\Sustainability\'; Name = 'SustainabilityTelemetry'; Reason = 'Windows sustainability telemetry task'; Profile = 'Maximum' },
        @{ Path = '\Microsoft\Windows\DirectX\'; Name = 'DirectXDatabaseUpdater'; Reason = 'DirectX database updater task'; Profile = 'Maximum' },
        @{ Path = '\Intel\'; NamePattern = '*'; Reason = 'All non-protected Intel scheduled tasks (Intel DSA* tasks are protected - required for driver updates)'; Profile = 'Maximum' },

        # --- Marvin700 WindowsTweaks_Tasks additions ---
        @{ Path = '\'; Name = 'Proxy'; Reason = 'Autochk Proxy'; Profile = 'Balanced' },
        @{ Path = '\'; Name = 'Consolidator'; Reason = 'CEIP Consolidator'; Profile = 'Balanced' },
        @{ Path = '\'; Name = 'KernelCeipTask'; Reason = 'CEIP KernelCeipTask'; Profile = 'Balanced' },
        @{ Path = '\'; Name = 'Uploader'; Reason = 'CEIP Uploader'; Profile = 'Balanced' },
        @{ Path = '\'; Name = 'UsbCeip'; Reason = 'CEIP UsbCeip'; Profile = 'Balanced' },
        @{ Path = '\Microsoft\Windows\DiskDiagnostic\'; Name = 'Microsoft-Windows-DiskDiagnosticDataCollector'; Reason = 'Disk Diagnostic'; Profile = 'Balanced' },
        @{ Path = '\Microsoft\Windows\Maps\'; NamePattern = 'MapsToastTask'; Reason = 'Maps Toast'; Profile = 'Balanced' },
        @{ Path = '\Microsoft\Windows\Maps\'; NamePattern = 'MapsUpdateTask'; Reason = 'Maps Update'; Profile = 'Balanced' },
        @{ Path = '\Microsoft\Windows\Shell\'; NamePattern = 'FamilySafetyMonitor'; Reason = 'Family Safety Monitor'; Profile = 'Balanced' },
        @{ Path = '\Microsoft\Windows\Shell\'; NamePattern = 'FamilySafetyRefreshTask'; Reason = 'Family Safety Refresh'; Profile = 'Balanced' },
        @{ Path = '\Microsoft\Windows\Shell\'; NamePattern = 'FamilySafetyUpload'; Reason = 'Family Safety Upload'; Profile = 'Balanced' },
        @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'FODCleanupTask'; Reason = 'Feature-on-Demand Cleanup Task'; Profile = 'Balanced' },
        @{ Path = '\Microsoft\Windows\AppCompat\'; Name = 'ProgramDataUpdater'; Reason = 'AppCompat ProgramDataUpdater'; Profile = 'Balanced' },
        @{ Path = '\Microsoft\Windows\AppCompat\'; Name = 'StartupAppTask'; Reason = 'AppCompat StartupAppTask'; Profile = 'Balanced' }
    )

    RunAutoruns = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'OneDrive'; Reason = 'OneDrive background autorun'; ExcludeWhenLoginSafe = $true },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'Microsoft.Lists'; Reason = 'Microsoft Lists OneDrive-backed autorun' }
    )

    StartupApproved = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'BingSvc'; Reason = 'Bing startup service app entry' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Microsoft.Lists'; Reason = 'Microsoft Lists startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Teams'; Reason = 'Teams startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'kDrive'; Reason = 'kDrive startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Microsoft.YourPhone'; Reason = 'Phone Link startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Phone Link'; Reason = 'Phone Link startup app (alt name)' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'WhatsApp.Root'; Reason = 'WhatsApp startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Discord'; Reason = 'Discord startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Windscribe'; Reason = 'Windscribe startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'OneDrive'; Reason = 'OneDrive startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'CCleaner'; Reason = 'CCleaner startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Intel Graphics Software'; Reason = 'Intel Graphics startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Skype'; Reason = 'Skype startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'zoommsirepair'; Reason = 'Zoom MSI repair startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'BraveSoftware Update'; Reason = 'Brave browser updater startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Lync'; Reason = 'Lync/Skype for Business startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Adobe Acrobat Synchronizer'; Reason = 'Adobe Acrobat cloud sync startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; NamePattern = 'GoogleChromeAutoLaunch_*'; Reason = 'Google Chrome auto-launch startup app' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; NamePattern = 'MicrosoftEdgeAutoLaunch_*'; Reason = 'Microsoft Edge auto-launch startup app' }
    )

    AppModelStartup = @(
        @{ Path = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.YourPhone_8wekyb3d8bbwe\YourPhone.Start'; Name = 'State'; DisableValue = 1; Reason = 'Phone Link startup task' },
        @{ Path = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\5319275A.WhatsAppDesktop_cv1g1gvanyjgm\WhatsAppStartupTask'; Name = 'State'; DisableValue = 1; Reason = 'WhatsApp startup task' },
        @{ Path = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MSTeams_8wekyb3d8bbwe\TeamsTfwStartupTask'; Name = 'State'; DisableValue = 1; Reason = 'New Teams startup task' },
        @{ Path = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MicrosoftWindows.CrossDevice_cw5n1h2txyewy\CrossDevice.Start'; Name = 'State'; DisableValue = 1; Reason = 'Mobile devices cross-device startup task' }
    )

    ProcessStops = @(
        @{ Name = 'Discord'; Reason = 'Discord user app' },
        @{ Name = 'slack'; Reason = 'Slack user app' },
        @{ Name = 'ms-teams'; Reason = 'Microsoft Teams user app' },
        @{ Name = 'Teams'; Reason = 'Classic Teams process name variant' },
        @{ Name = 'Docker Desktop'; Reason = 'Docker Desktop GUI process' },
        @{ Name = 'Dropbox'; Reason = 'Dropbox desktop process' },
        @{ Name = 'OneDrive'; Reason = 'OneDrive desktop process' },
        @{ Name = 'OneDrive.Sync.Service'; Reason = 'OneDrive sync service process' },
        @{ Name = 'PhoneExperienceHost'; Reason = 'Phone Link app process' },
        @{ Name = 'CrossDeviceService'; Reason = 'Cross-device background process' },
        @{ Name = 'CrossDeviceResume'; Reason = 'Cross-device resume process' },
        @{ Name = 'WhatsApp'; Reason = 'WhatsApp desktop process' }
    )
}
