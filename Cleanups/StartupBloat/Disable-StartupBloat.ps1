#requires -Version 5.1
<#
.SYNOPSIS
    Disables nonessential auto-start entries that slow down Windows login.

.DESCRIPTION
    For every target in Cleanups\StartupBloat\Manifest.psd1 this script:

      - removes the Run/RunOnce registry value (HKLM values need elevation),
      - sets the matching per-user StartupApproved flag to "disabled" so an app
        that re-creates its Run value (on update or on its own) still does NOT
        start at logon,
      - moves matching shortcuts out of the Startup folders into Backups
        (they are not deleted - the app can still be launched manually).

    Everything is recorded under <SuiteRoot>\Backups\StartupBloat so
    Restore-StartupBloat.ps1 can put the original state back. Protected entries
    (Intel Driver & Support Assistant) are never modified. Manual launches of
    the affected apps keep working; only their automatic start is removed.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.

.EXAMPLE
    & 'WindowsCleanupSuite\Cleanups\StartupBloat\Disable-StartupBloat.ps1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot '..\..\Core\CleanupEngine.ps1')

$manifest   = Get-SuiteManifest -CleanupName 'StartupBloat'
$backupRoot = Get-SuiteBackupRoot -CleanupName 'StartupBloat'
$isAdmin    = Test-SuiteIsAdmin

function Disable-SuiteAutoStartName {
    param(
        [psobject]$Target,
        [string]$Name
    )

    $label = Get-SuiteEntryLabel -Entry $Target
    if (Test-SuiteIsProtected -Name $Name -Manifest $manifest) {
        Write-Host "  Skipped (Protected) [$($Target.Hive)] $Name"
        return
    }

    $runPath = $Target.Path
    $runExists = $false
    if (Test-Path $runPath) {
        $runExists = @((Get-Item -Path $runPath).Property) -contains $Name
    }

    $overlayPath = Get-WCSRunStartupApprovedPath -RunPath $runPath
    $canOverlay = $false
    if ($overlayPath) {
        if ($overlayPath -like 'HKLM:*' -and -not $isAdmin) {
            Write-Host "  Skipped StartupApproved flag [$Name] (requires elevation)"
        } else {
            $canOverlay = $true
        }
    }

    $originalFlag = $null
    if ($canOverlay) { $originalFlag = Get-WCSRegistryBinaryValue -Path $overlayPath -Name $Name }
    $flagEnabled = $canOverlay -and ($null -eq $originalFlag -or -not (Test-WCSStartupDisabledFlag -Value $originalFlag))
    $canRemoveRun = $runExists -and ($Target.Hive -ne 'HKLM' -or $isAdmin)

    if (-not $runExists -and -not $flagEnabled) {
        Write-Host "  Already absent/disabled [$($Target.Hive)] $Name"
        return
    }
    if ($runExists -and -not $canRemoveRun -and -not $flagEnabled) {
        Write-Host "  Skipped [$($Target.Hive)] $Name (requires elevation)"
        return
    }

    if (-not $PSCmdlet.ShouldProcess($Name, "Disable auto-start [$($Target.Hive)] $label")) {
        Write-Host "  Would disable [$($Target.Hive)] $Name"
        return
    }

    if ($flagEnabled) {
        New-SuiteBackupFile -BackupRoot $backupRoot -FileName "startupapproved_$($Target.Hive)_$(Get-SuiteSafeFileName $Name).json" -Record @{
            Type = 'StartupApprovedFlag'; Path = $overlayPath; Name = $Name
            ValueBase64 = if ($null -eq $originalFlag) { '' } else { [Convert]::ToBase64String($originalFlag) }
            Existed = ($null -ne $originalFlag); Reason = $label
        }
        try {
            if (-not (Test-Path $overlayPath)) { New-Item -Path $overlayPath -Force | Out-Null }
            Set-ItemProperty -Path $overlayPath -Name $Name -Value (New-WCSStartupDisabledFlag -Existing $originalFlag) -Type Binary -ErrorAction Stop
            Write-Host "  Disabled startup flag [$($Target.Hive)] $Name"
        } catch {
            Write-Warning "  Failed to disable startup flag for '$Name': $($_.Exception.Message)"
        }
    }

    if ($canRemoveRun) {
        $value = $null
        try { $value = (Get-ItemProperty -Path $runPath -Name $Name -ErrorAction Stop).$Name } catch { $value = $null }
        if ($null -ne $value) {
            New-SuiteBackupFile -BackupRoot $backupRoot -FileName "$($Target.Hive)_$(Get-SuiteSafeFileName $Name).txt" -Record @{
                Hive = $Target.Hive; Path = $runPath; Name = $Name; Value = $value
            }
        }
        try {
            Remove-ItemProperty -Path $runPath -Name $Name -ErrorAction Stop
            Write-Host "  Disabled [$($Target.Hive)] $Name"
        } catch {
            Write-Warning "  Failed to disable '$Name': $($_.Exception.Message)"
        }
    }
}

foreach ($target in @($manifest.Targets)) {
    $runPath = $target.Path
    $overlayPath = Get-WCSRunStartupApprovedPath -RunPath $runPath

    $names = @()
    if ($target.NamePattern) {
        if (Test-Path $runPath) { $names = @((Get-Item -Path $runPath).Property | Where-Object { $_ -like $target.NamePattern }) }
    } else {
        $names = @($target.Name)
    }

    # A Run value can be gone while its StartupApproved flag is still enabled
    # (that is why apps come back after a logoff). Include those names as well.
    if ($overlayPath -and (Test-Path $overlayPath)) {
        $overlayNames = @((Get-Item -Path $overlayPath).Property | Where-Object {
            if ($target.NamePattern) { $_ -like $target.NamePattern } else { $_ -eq $target.Name }
        })
        $names = @(($names + $overlayNames) | Sort-Object -Unique)
    }

    foreach ($name in $names) {
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        Disable-SuiteAutoStartName -Target $target -Name $name
    }
}

# --- Startup folder shortcuts -------------------------------------------------------
$startupFolders = @{
    User     = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup')
    AllUsers = (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Startup')
}

foreach ($entry in @($manifest.StartupFolders)) {
    if ($entry.Scope -eq 'AllUsers' -and -not $isAdmin) {
        Write-Host "  Skipped StartupFolder [$($entry.NamePattern)] (requires elevation)"
        continue
    }
    $folder = $startupFolders[$entry.Scope]
    if (-not $folder -or -not (Test-Path $folder)) { continue }

    foreach ($file in @(Get-ChildItem -Path $folder -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $entry.NamePattern })) {
        $destDir = Join-Path $backupRoot "StartupFolder\$($entry.Scope)"
        $dest = Join-Path $destDir $file.Name
        if (Test-Path $dest) {
            Write-Host "  Already moved: $($file.Name)"
            continue
        }
        if (-not $PSCmdlet.ShouldProcess($file.Name, 'Move shortcut out of Startup folder')) {
            Write-Host "  Would move StartupFolder shortcut: $($file.Name)"
            continue
        }
        try {
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
            New-SuiteBackupFile -BackupRoot $backupRoot -FileName "startupshortcut_$($entry.Scope)_$(Get-SuiteSafeFileName $file.Name).json" -Record @{
                Type = 'StartupShortcut'; Scope = $entry.Scope; Name = $file.Name
                SourcePath = $file.FullName; BackupPath = $dest; Reason = $entry.NamePattern
            }
            Move-Item -LiteralPath $file.FullName -Destination $dest -ErrorAction Stop
            Write-Host "  Moved StartupFolder shortcut: $($file.Name)"
        } catch {
            Write-Warning "  Failed to move StartupFolder shortcut '$($file.Name)': $($_.Exception.Message)"
        }
    }
}

Write-Host "Done. Backups are in $backupRoot"
