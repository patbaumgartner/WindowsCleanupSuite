# Power plan cleanup manifest - Marvin700 Ultimate Performance + LeDragoX Optimize-Performance registry tweaks.
@{
    Project = 'WindowsCleanupSuite'
    Cleanup = 'PowerPlan'
    Description = 'Enables the Ultimate Performance power plan (Marvin700) and applies performance registry tweaks (LeDragoX Optimize-Performance).'
    ProtectedPatterns = @('*DSA*', '*Driver*Support*')

    PowerPlans = @(
        @{ Name = 'UltimatePerformance'; GUID = 'e9a42b02-d5df-448d-aa00-03f14749eb61' },
        @{ Name = 'UltimatePerformanceAlt'; GUID = '95533644-e700-4a79-a56c-a89e8cb109d9' }
    )
    RegistryEntries = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'; Name = 'HwSchMode'; Value = 2; Type = 'DWord'; Reason = 'Enable Hardware Accelerated GPU Scheduling (Windows 10+)' },
        @{ Path = 'HKLM:\SYSTEM\ControlSet001\Services\Ndu'; Name = 'Start'; Value = 4; Type = 'DWord'; Reason = 'Disable Ndu High RAM Usage (2 = Enable Ndu, 4 = Disable)' },
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control'; Name = 'WaitToKillServiceTimeout'; Value = 2000; Type = 'DWord'; Reason = 'Reduce service kill timeout (default 20000/5000)' },
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'; Name = 'ClearPageFileAtShutdown'; Value = 0; Type = 'DWord'; Reason = 'Do not clear page file at shutdown' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; Name = 'NetworkThrottlingIndex'; Value = 268435455; Type = 'DWord'; Reason = 'Unlimit network bandwidth (0xffffffff)' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; Name = 'SystemResponsiveness'; Value = 0; Type = 'DWord'; Reason = 'Reserve 100% of CPU to multimedia/gaming tasks' },
        @{ Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseHoverTime'; Value = '250'; Type = 'String'; Reason = 'Reduce mouse hover time (default 400)' },
        @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'MenuShowDelay'; Value = 1; Type = 'DWord'; Reason = 'Reduce animation speed delay to 1ms' },
        @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'AutoEndTasks'; Value = 1; Type = 'DWord'; Reason = "Don't prompt user to end tasks on shutdown" },
        @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'LowLevelHooksTimeout'; Value = 1000; Type = 'DWord'; Reason = 'Reduce mouse/keyboard hooks timeout' },
        @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'WaitToKillAppTimeout'; Value = 5000; Type = 'DWord'; Reason = 'Reduce time to kill apps timeout (default 20000)' }
    )
}
