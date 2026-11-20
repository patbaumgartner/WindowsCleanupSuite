#requires -Version 5.1
<#
.SYNOPSIS
    Disables Microsoft Copilot, Recall, Click to Do, Edge/Chrome/Paint/Notepad AI
    features, and the WSAIFabricSvc AI/analytics service.

.DESCRIPTION
    Sets registry policies/keys. Registry keys based on Raphire Win11Debloat
    Regfiles/*.reg. HKLM keys require Administrator.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\WindowsAI\Disable-WindowsAI.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest   = Get-SuiteManifest -CleanupName 'WindowsAI'
$backupRoot = Get-SuiteBackupRoot -CleanupName 'WindowsAI'
$isAdmin    = Test-SuiteIsAdmin

foreach ($entry in @($manifest.Entries)) {
    $needsAdmin = ($entry.RequiresAdmin -eq $true) -or ($entry.RegistryKey -like 'HKLM:*')
    if ($needsAdmin -and -not $isAdmin) {
        Write-Host "  Skipped (Admin): $($entry.RegistryKey)\$($entry.Name) - $($entry.Reason)"
        continue
    }

    if (-not $PSCmdlet.ShouldProcess("$($entry.RegistryKey)\$($entry.Name)", "Set $($entry.Name) = $($entry.Value) - $($entry.Reason)")) {
        Write-Host "  Would disable: $($entry.RegistryKey)\$($entry.Name)"
        continue
    }

    $previousValue = $null
    try { $previousValue = (Get-ItemProperty -Path $entry.RegistryKey -ErrorAction Stop).PSObject.Properties | Where-Object { $_.Name -eq $entry.Name } | Select-Object -ExpandProperty Value } catch { $previousValue = $null }

    $record = @{ Type = 'Registry'; RegistryKey = $entry.RegistryKey; Name = $entry.Name; PreviousValue = $previousValue; NewValue = $entry.Value; Reason = $entry.Reason }
    New-SuiteBackupFile -BackupRoot $backupRoot -FileName "$(Get-SuiteSafeFileName $entry.RegistryKey)-$(Get-SuiteSafeFileName $entry.Name).json" -Record $record

    try {
        Set-ItemProperty -Path $entry.RegistryKey -Name $entry.Name -Value $entry.Value -Type DWord -ErrorAction Stop
        Write-Host "  Disabled: $($entry.RegistryKey)\$($entry.Name) = $($entry.Value) - $($entry.Reason)"
    } catch {
        Write-Warning "  Failed: $($_.Exception.Message)"
    }

    if ($entry.StopService) {
        Stop-Service -Name 'WSAIFabricSvc' -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Done. Backups are in $backupRoot"
