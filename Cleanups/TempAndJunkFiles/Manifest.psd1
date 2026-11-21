# Temp-and-junk-files cleanup manifest - Chainski WindowsCleanerUtility + Marvin700 Windows Cleanup/Extended Cleanup.
@{
    Project = 'WindowsCleanupSuite'
    Cleanup = 'TempAndJunkFiles'
    Description = 'Deletes temporary files, log files, event logs, prefetch, crash dumps, PowerShellReadLine cache, caches and other junk (Chainski WindowsCleanerUtility + Marvin700 Windows Cleanup).'
    ProtectedPatterns = @('*DSA*', '*Driver*Support*')

    Directories = @(
        'C:\Windows\Temp',
        'C:\Windows\Minidump',
        'C:\Windows\Prefetch',
        'C:\Windows\SoftwareDistribution\Download',
        'C:\Windows\System32\LogFiles',
        'C:\Windows\Logs\CBS\CbsPersist',
        'C:\Windows\Logs\MoSetup',
        'C:\Windows\Panther',
        '%LOCALAPPDATA%\Microsoft\Windows\Caches',
        '%LOCALAPPDATA%\Microsoft\Windows\WebCache',
        '%LOCALAPPDATA%\Microsoft\Windows\INetCache',
        '%LOCALAPPDATA%\Microsoft\Windows\Explorer',
        '%LOCALAPPDATA%\CrashDumps',
        '%LOCALAPPDATA%\NVIDIA\DXCache',
        '%LOCALAPPDATA%\NVIDIA\GLCache',
        '%APPDATA%\..\locallow\Intel\ShaderCache',
        '%SYSTEMDRIVE%\AMD',
        '%SYSTEMDRIVE%\NVIDIA',
        '%SYSTEMDRIVE%\INTEL',
        '%PROGRAMDATA%\Package Cache',
        '%PROGRAMDATA%\Microsoft\Windows\WER\Temp',
        '%LOCALAPPDATA%\Microsoft\Windows\PowerShell\PSReadLine',
        # --- 2025 additions (Chainski WindowsCleanerUtility + Marvin700 extras) ---
        '%LOCALAPPDATA%\Temp',
        '%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache',
        '%LOCALAPPDATA%\Google\Chrome\User Data\Default\Code Cache',
        '%LOCALAPPDATA%\Google\Chrome\User Data\Default\GPUCache'
    )
    FilePatterns = @('*.tmp', '*.log', '*.old', '*.trace', '*.bak', 'memory.dmp')
    ClearEventLogs = $true
    # Default Disk Cleanup preset (cleanmgr /sagerun:5), backups optional but enabled by default
    DiskCleanupSagerun = 5
}
