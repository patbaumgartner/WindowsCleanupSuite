#requires -Version 5.1
<#
.SYNOPSIS
    Structural tests for the WindowsCleanupSuite (read-only).

.DESCRIPTION
    1. Parses every .ps1 file in the project (Parser::ParseInput).
    2. Verifies each cleanup has a Manifest.psd1, Disable and Restore scripts
       (7 original + 3 new data-driven + 4 menu-era cleanups).
    3. Verifies manifests import and define ProtectedPatterns (DSA protected).
    4. Verifies the menu-era cleanups pass the new schema checks (levels, entries).
    5. Verifies extension manifests (TempAndJunkFiles, DNSReset).
    6. Verifies menu/core/tools/docs files exist.
    7. Menu smoke test: non-interactive preview (nothing changes).
    8. Independence from the previous project (run-full-debloat, etc.).

.EXAMPLE
    & 'WindowsCleanupSuite\Tests\Invoke-SuiteTests.ps1'
#>
[CmdletBinding()]
param()

$SuiteRoot = Split-Path -Parent $PSScriptRoot
$script:Passed = 0
$script:Failed = 0

function Test-SuiteCheck {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Pass,
        [string]$Detail = ''
    )

    if ($Pass) {
        $script:Passed++
        Write-Host "  PASS: $Name"
    } else {
        $script:Failed++
        Write-Host "  FAIL: $Name$(if ($Detail) { " - $Detail" })"
    }
}

Write-Host 'Structural tests for WindowsCleanupSuite'
Write-Host "Suite root: $SuiteRoot"
Write-Host ''

# --- 1. Every .ps1 file parses ---------------------------------------------------
foreach ($file in @(Get-ChildItem -Path $SuiteRoot -Recurse -File -Include '*.ps1' -ErrorAction SilentlyContinue)) {
    $tokens = $null
    $errors = $null
    $ast = $null
    $parseOk = $true
    $detail = ''
    try {
        $ast = [System.Management.Automation.Language.Parser]::ParseInput((Get-Content -Raw -Path $file.FullName -ErrorAction Stop), [ref]$tokens, [ref]$errors)
    } catch {
        $parseOk = $false
        $detail = $_.Exception.Message
    }
    $errors = @($errors | Where-Object { $null -ne $_ })
    if ($errors.Count -gt 0) {
        $detail = ($errors | Select-Object -First 1 | ForEach-Object { "$($_.Message) (line $($_.Extent.StartLine))" }) -join '; '
    }
    $pass = $parseOk -and ($ast -ne $null) -and ($errors.Count -eq 0)
    Test-SuiteCheck -Name "Parses: $(Split-Path -Leaf $file.FullName)" -Pass $pass -Detail $detail
}

# --- 2. Cleanup structure -----------------------------------------------------------
$expectedCleanups = @(
    @{ Cleanup = 'StartupBloat';      Manifest = 'Manifest.psd1'; Disable = 'Disable-StartupBloat.ps1';             Restore = 'Restore-StartupBloat.ps1';             Protected = @('*DSA*') },
    @{ Cleanup = 'WindowsSpeedup';    Manifest = 'Manifest.psd1'; Disable = 'Disable-ServicesAndTasks.ps1';       Restore = 'Restore-ServicesAndTasks.ps1';       Protected = @('*DSA*', '*Driver*Support*') },
    @{ Cleanup = 'InstalledSoftware'; Manifest = 'Manifest.psd1'; Disable = 'Disable-InstalledSoftware.ps1';      Restore = 'Restore-InstalledSoftware.ps1';      Protected = @('*DSA*', '*Driver*Support*') },
    @{ Cleanup = 'WindowsAI';         Manifest = 'Manifest.psd1'; Disable = 'Disable-WindowsAI.ps1';               Restore = 'Restore-WindowsAI.ps1';               Protected = @('*DSA*', '*Driver*Support*') },
    @{ Cleanup = 'Privacy';           Manifest = 'Manifest.psd1'; Disable = 'Disable-Privacy.ps1';                  Restore = 'Restore-Privacy.ps1';                  Protected = @('*DSA*', '*Driver*Support*') },
    @{ Cleanup = 'Browsers';          Manifest = 'Manifest.psd1'; Disable = 'Disable-Browsers.ps1';                 Restore = 'Restore-Browsers.ps1';                 Protected = @('*DSA*', '*Driver*Support*') },
    @{ Cleanup = 'Network';           Manifest = 'Manifest.psd1'; Disable = 'Disable-Network.ps1';                  Restore = 'Restore-Network.ps1';                  Protected = @('*DSA*', '*Driver*Support*') },
    @{ Cleanup = 'TempAndJunkFiles';  Manifest = 'Manifest.psd1'; Disable = 'Disable-TempAndJunkFiles.ps1';       Restore = 'Restore-TempAndJunkFiles.ps1';       Protected = @('*DSA*', '*Driver*Support*') },
    @{ Cleanup = 'PowerPlan';         Manifest = 'Manifest.psd1'; Disable = 'Enable-UltimatePerformancePlan.ps1'; Restore = 'Restore-PowerPlan.ps1';             Protected = @('*DSA*', '*Driver*Support*') },
    @{ Cleanup = 'DNSReset';          Manifest = 'Manifest.psd1'; Disable = 'Disable-DNSReset.ps1';                Restore = 'Restore-DNSReset.ps1';                Protected = @('*DSA*', '*Driver*Support*') },
    # Menu-era cleanups
    @{ Cleanup = 'PrivacySettings';   Manifest = 'Manifest.psd1'; Disable = 'Disable-PrivacySettings.ps1';        Restore = 'Restore-PrivacySettings.ps1';        Protected = @('*DSA*', '*Driver*Support*') },
    @{ Cleanup = 'WindowsUpdates';    Manifest = 'Manifest.psd1'; Disable = 'Disable-WindowsUpdates.ps1';         Restore = 'Restore-WindowsUpdates.ps1';         Protected = @('*DSA*', '*Driver*Support*') },
    @{ Cleanup = 'OneDrive';          Manifest = 'Manifest.psd1'; Disable = 'Disable-OneDrive.ps1';               Restore = 'Restore-OneDrive.ps1';               Protected = @('*DSA*', '*Driver*Support*') },
    @{ Cleanup = 'ExtremeExtras';     Manifest = 'Manifest.psd1'; Disable = 'Disable-ExtremeExtras.ps1';         Restore = 'Restore-ExtremeExtras.ps1';         Protected = @('*DSA*', '*Driver*Support*') }
)

foreach ($expected in $expectedCleanups) {
    $cleanupRoot = Join-Path $SuiteRoot ('Cleanups\' + $expected.Cleanup)
    Test-SuiteCheck -Name "Directory exists: Cleanups\$($expected.Cleanup)" -Pass (Test-Path $cleanupRoot)
    Test-SuiteCheck -Name "Script exists: $($expected.Disable)" -Pass (Test-Path (Join-Path $cleanupRoot $expected.Disable))
    Test-SuiteCheck -Name "Script exists: $($expected.Restore)" -Pass (Test-Path (Join-Path $cleanupRoot $expected.Restore))

    $manifestPath = Join-Path $cleanupRoot $expected.Manifest
    $manifest = $null
    if (Test-Path $manifestPath) {
        try { $manifest = Import-PowerShellDataFile -Path $manifestPath -ErrorAction Stop } catch { $manifest = $null }
    }
    Test-SuiteCheck -Name "Manifest imports: $($expected.Manifest)" -Pass ($null -ne $manifest)
    if ($manifest) {
        Test-SuiteCheck -Name 'Manifest defines ProtectedPatterns' -Pass ($null -ne $manifest.ProtectedPatterns -and @($manifest.ProtectedPatterns).Count -gt 0)
        foreach ($p in $expected.Protected) {
            Test-SuiteCheck -Name "Manifest ProtectedPatterns covers '$p'" -Pass (@($manifest.ProtectedPatterns) -contains $p)
        }
        $entriesKey = switch ($expected.Cleanup) {
            'StartupBloat'      { 'Targets' }
            'InstalledSoftware' { 'Win32Apps' }
            'WindowsAI'         { 'Entries' }
            'Privacy'           { 'Entries' }
            'Browsers'          { 'Entries' }
            'Network'           { 'Entries' }
            'TempAndJunkFiles'  { 'Directories' }
            'PowerPlan'         { 'PowerPlans' }
            'DNSReset'          { 'Commands' }
            'PrivacySettings'   { 'Entries' }
            'WindowsUpdates'    { 'RegistryEntries' }
            'OneDrive'          { 'Entries' }
            'ExtremeExtras'     { 'Services' }
            default             { 'Services' }
        }
        $entries = @($manifest.$entriesKey | Where-Object { $null -ne $_ })
        Test-SuiteCheck -Name "Manifest defines '$entriesKey' ($($entries.Count) entries)" -Pass ($entries.Count -gt 0)
        if ($expected.Cleanup -eq 'WindowsSpeedup') {
            foreach ($key in @('Tasks', 'RunAutoruns', 'StartupApproved', 'AppModelStartup', 'ProcessStops')) {
                $sub = @($manifest.$key | Where-Object { $null -ne $_ })
                Test-SuiteCheck -Name "Manifest defines '$key' ($($sub.Count) entries)" -Pass ($sub.Count -gt 0)
            }
            $riskySvcs = @($manifest.Services | Where-Object { $null -ne $_ -and $_.Risky -eq $true })
            Test-SuiteCheck -Name "WindowsSpeedup has Risky-flagged services gated by -AllowRisky ($($riskySvcs.Count))" -Pass ($riskySvcs.Count -gt 0)
        }
        if ($expected.Cleanup -eq 'Network') {
            $svcs = @($manifest.Services | Where-Object { $null -ne $_ })
            Test-SuiteCheck -Name "Network manifest defines 'Services' ($($svcs.Count))" -Pass ($svcs.Count -gt 0)
            Test-SuiteCheck -Name 'Network manifest defines Dns block with Servers + Risky' -Pass ($null -ne $manifest.Dns -and @($manifest.Dns.Servers).Count -gt 0 -and $manifest.Dns.Risky -eq $true)
            $riskyReg = @($manifest.Entries | Where-Object { $null -ne $_ -and $_.Risky -eq $true })
            Test-SuiteCheck -Name "Network has Risky-flagged registry entries ($($riskyReg.Count))" -Pass ($riskyReg.Count -gt 0)
        }
        if ($expected.Cleanup -in @('Privacy', 'Browsers', 'Network')) {
            $disablePath = Join-Path $cleanupRoot $expected.Disable
            $disableText = if (Test-Path $disablePath) { Get-Content -Raw -Path $disablePath } else { '' }
            Test-SuiteCheck -Name "$($expected.Cleanup): Disable script has -AllowRisky + SupportsShouldProcess" -Pass ($disableText -match '\[switch\]\$AllowRisky' -and $disableText -match 'SupportsShouldProcess')
        }
    }
}

# --- 3. Menu-era schema checks ------------------------------------------------------

$menuEraCleanups = @('PrivacySettings', 'WindowsUpdates', 'OneDrive', 'ExtremeExtras', 'Privacy', 'Browsers', 'Network')
foreach ($cleanupName in $menuEraCleanups) {
    $manifestPath = Join-Path $SuiteRoot "Cleanups\$cleanupName\Manifest.psd1"
    if (-not (Test-Path $manifestPath)) { continue }
    $manifest = Import-PowerShellDataFile -Path $manifestPath -ErrorAction SilentlyContinue
    Test-SuiteCheck -Name "Schema: $cleanupName manifest imports" -Pass ($null -ne $manifest)
    if (-not $manifest) { continue }

    $entriesKey = @{ PrivacySettings = 'Entries'; WindowsUpdates = 'RegistryEntries'; OneDrive = 'Entries'; ExtremeExtras = 'Services'; Privacy = 'Entries'; Browsers = 'Entries'; Network = 'Entries' }[$cleanupName]
    $entries = @($manifest.$entriesKey | Where-Object { $null -ne $_ })
    Test-SuiteCheck -Name "Schema: $cleanupName defines $entriesKey ($($entries.Count) entries)" -Pass ($entries.Count -gt 0)

    foreach ($entry in $entries) {
        $entryKeys = @($entry.Keys)
        $name = if ($entryKeys -contains 'Name') { [string]$entry.Name } else { '<unnamed>' }
        switch ($cleanupName) {
            'PrivacySettings' {
                Test-SuiteCheck -Name "Schema: PrivacySettings entry '$name' Level in 1..4" -Pass ([int]$entry.Level -ge 1 -and [int]$entry.Level -le 4)
                Test-SuiteCheck -Name "Schema: PrivacySettings entry '$name' has Path/Name/Value/Reason" -Pass (
                    ($entryKeys -contains 'Path') -and
                    ($entryKeys -contains 'Name') -and
                    ($entryKeys -contains 'Value') -and
                    ($entryKeys -contains 'Reason'))
            }
            'Privacy' {
                $hasRegKey = ($entryKeys -contains 'RegistryKey') -or ($entryKeys -contains 'Path') -or ($entryKeys -contains 'Registry') -or ($entryKeys -contains 'Name')
                Test-SuiteCheck -Name "Schema: Privacy entry '$name' has RegistryKey/Name/Value/Reason/Type" -Pass (
                    $hasRegKey -and
                    ($entryKeys -contains 'Reason') -and
                    ($entryKeys -contains 'Value'))
            }
            'Browsers' {
                Test-SuiteCheck -Name "Schema: Browsers entry '$name' has RegistryKey/Name/Value/Reason" -Pass (
                    ($entryKeys -contains 'RegistryKey') -and
                    ($entryKeys -contains 'Name') -and
                    ($entryKeys -contains 'Value') -and
                    ($entryKeys -contains 'Reason'))
            }
            'Network' {
                Test-SuiteCheck -Name "Schema: Network entry '$name' has RegistryKey/Name/Value/Reason or services/DNS sections" -Pass (($entryKeys -contains 'Reason') -or ($manifest.Services) -or ($manifest.Dns))
                foreach ($svc in @($manifest.Services | Where-Object { $_ -ne $null })) {
                    $svcKeys = @($svc.Keys)
                    Test-SuiteCheck -Name "Schema: Network service '$($svc.Name)' has Name + Reason" -Pass (
                        ($svcKeys -contains 'Name') -and
                        ($svcKeys -contains 'Reason'))
                }
                Test-SuiteCheck -Name "Schema: Network defines Dns" -Pass ($null -ne $manifest.Dns)
            }
            'WindowsUpdates' {
                foreach ($svc in @($manifest.Services | Where-Object { $_ -ne $null })) {
                    Test-SuiteCheck -Name "Schema: WindowsUpdates service '$($svc.Name)' action allowed (Manual/Automatic/Disabled)" -Pass ($svc.Action -in @('Manual', 'Automatic', 'Disabled'))
                }
                Test-SuiteCheck -Name "Schema: WindowsUpdates entry '$name' has Path/Name/Value/Reason" -Pass (
                    ($entryKeys -contains 'Path') -and
                    ($entryKeys -contains 'Name') -and
                    ($entryKeys -contains 'Value') -and
                    ($entryKeys -contains 'Reason'))
            }
            'OneDrive' {
                Test-SuiteCheck -Name "Schema: OneDrive entry '$name' has Action + Reason + Path/Name" -Pass (
                    ($entryKeys -contains 'Action') -and
                    ($entryKeys -contains 'Reason') -and
                    ($entryKeys -contains 'Name') -and
                    ($entryKeys -contains 'Path'))
            }
            'ExtremeExtras' {
                Test-SuiteCheck -Name "Schema: ExtremeExtras entry '$name' Level=4 + Reason" -Pass (
                    [int]$entry.Level -eq 4 -and
                    ($entryKeys -contains 'Reason') -and
                    ($entryKeys -contains 'Name'))
            }
        }
    }
}

# --- 3b. Extension manifests ---------------------------------------------------------
$tjManifest = Import-PowerShellDataFile -Path (Join-Path $SuiteRoot 'Cleanups\TempAndJunkFiles\Manifest.psd1')
Test-SuiteCheck -Name 'Extension: TempAndJunkFiles has DiskCleanupSagerun' -Pass ([string]::IsNullOrWhiteSpace($tjManifest.DiskCleanupSagerun) -eq $false)
Test-SuiteCheck -Name 'Extension: TempAndJunkFiles cleans %LOCALAPPDATA%\Temp' -Pass ([bool](@($tjManifest.Directories) -like '%LOCALAPPDATA%\Temp'))
Test-SuiteCheck -Name 'Extension: TempAndJunkFiles cleans Chrome caches' -Pass ([bool](@($tjManifest.Directories) -like '*Chrome*Cache*').Count -ge 3)

$dnsManifest = Import-PowerShellDataFile -Path (Join-Path $SuiteRoot 'Cleanups\DNSReset\Manifest.psd1')
Test-SuiteCheck -Name 'Extension: DNSReset includes RSS tuning command' -Pass ([bool](@($dnsManifest.Commands) -like 'netsh int tcp set global rss=disabled'))
Test-SuiteCheck -Name 'Extension: DNSReset includes autotuning restriction command' -Pass ([bool](@($dnsManifest.Commands) -like 'netsh int tcp set global autotuninglevel=restricted'))

$powerManifest = Import-PowerShellDataFile -Path (Join-Path $SuiteRoot 'Cleanups\PowerPlan\Manifest.psd1')
Test-SuiteCheck -Name 'Extension: PowerPlan has PowerPlans' -Pass (@($powerManifest.PowerPlans).Count -gt 0)

# --- 4. Runner / audit / engine / menu / tools files --------------------------------
foreach ($rel in @(
    'Runners\Run-Menu.ps1',
    'Audit\Audit-State.ps1', 'Audit\Audit-InstalledSoftware.ps1', 'Audit\Audit-RunningServices.ps1', 'Audit\Check-SystemHealth.ps1', 'Audit\Perf-Snapshot.ps1',
    'Tests\Invoke-SuiteTests.ps1', 'Tests\Invoke-PS51ParseCheck.ps1',
    'Core\CleanupEngine.ps1', 'Core\WCS.Catalog.ps1', 'Core\WCS.Menu.ps1', 'Core\WCS.Updates.ps1', 'Core\WCS.Scheduler.ps1',
    'Tools\Restore-WCSBackup.ps1', 'Tools\Review-WCSBackup.ps1', 'Tools\New-WCSZip.ps1', 'Launcher.ps1',
    'LICENSE', 'CHANGELOG.md', 'VERSION', 'README.md'
)) {
    Test-SuiteCheck -Name "File exists: $rel" -Pass (Test-Path (Join-Path $SuiteRoot $rel))
}

# Legacy entry points are removed on purpose (no backwards compatibility).
foreach ($legacy in @('Runners\Run-Cleanup.ps1', 'Runners\Run-Monthly.ps1', 'Runners\Restore-All.ps1')) {
    Test-SuiteCheck -Name "Legacy entry point removed: $legacy" -Pass (-not (Test-Path (Join-Path $SuiteRoot $legacy)))
}

# --- 4b. Wiring drift checks: engine order, runner steps, restore coverage ------------
. (Join-Path $SuiteRoot 'Core\CleanupEngine.ps1')
$engineOrder = @(Get-SuiteCleanupNames)
foreach ($expected in $expectedCleanups) {
    Test-SuiteCheck -Name "Engine run order includes '$($expected.Cleanup)'" -Pass ($engineOrder -contains $expected.Cleanup)
    $restore = Get-ChildItem -Path (Join-Path $SuiteRoot "Cleanups\$($expected.Cleanup)") -Filter 'Restore-*.ps1' -ErrorAction SilentlyContinue
    Test-SuiteCheck -Name "Restore flow can restore '$($expected.Cleanup)' (Restore-*.ps1 present)" -Pass ($null -ne $restore)
}

# Catalog wiring: ServicesTasks must map to the individual cleanup scripts
# (the legacy Runners\Run-Cleanup.ps1 orchestrator is gone).
$catalogText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Core\WCS.Catalog.ps1')
Test-SuiteCheck -Name 'Catalog: ServicesTasks no longer points to legacy Run-Cleanup.ps1' -Pass ($catalogText -notmatch 'Runners\\Run-Cleanup\.ps1')
Test-SuiteCheck -Name 'Catalog: ServicesTasks runs StartupBloat + ServicesAndTasks + InstalledSoftware' -Pass (
    $catalogText -match [regex]::Escape("Cleanups\StartupBloat\Disable-StartupBloat.ps1") -and
    $catalogText -match [regex]::Escape("Cleanups\WindowsSpeedup\Disable-ServicesAndTasks.ps1") -and
    $catalogText -match [regex]::Escape("Cleanups\InstalledSoftware\Disable-InstalledSoftware.ps1"))

# No code file may reference the removed legacy runners anymore.
$legacyPattern = 'Run-Cleanup\.ps1|Run-Monthly\.ps1|Restore-All\.ps1'
$codeFiles = @(Get-ChildItem -Path $SuiteRoot -Recurse -File -Include '*.ps1', '*.psd1', '*.yml', '*.yaml' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -ine $PSCommandPath })
$legacyHits = @()
foreach ($f in $codeFiles) { $legacyHits += @(Select-String -Path $f.FullName -Pattern $legacyPattern -ErrorAction SilentlyContinue) }
Test-SuiteCheck -Name 'No code references legacy runners (Run-Cleanup/Run-Monthly/Restore-All)' -Pass ($legacyHits.Count -eq 0)

$wsDisableText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Cleanups\WindowsSpeedup\Disable-ServicesAndTasks.ps1')
Test-SuiteCheck -Name 'WindowsSpeedup Disable has -AllowRisky + risky gates (services/tasks/processes)' -Pass ($wsDisableText -match '\[switch\]\$AllowRisky' -and (@([regex]::Matches($wsDisableText, 'Test-SuiteEntryRiskyAllowed')).Count -ge 3))

# --- 4c. Release/snapshot zip layout: New-WCSZip must preserve the structure -------
# (Compress-Archive flattens all entries to file names - even with relative paths -
#  so the 14 Manifest.psd1 would collide and the extracted suite would be unusable.)
. (Join-Path $SuiteRoot 'Tools\New-WCSZip.ps1')
$zipTest = Join-Path ([System.IO.Path]::GetTempPath()) "wcs-zip-test-$PID.zip"
$zipInRoot = Join-Path $SuiteRoot "wcs-zip-test-$PID.zip"
try {
    $null = New-WCSZip -DestinationPath $zipTest -ExcludeDirNames '.git', 'Logs', 'Backups'
    # Destination inside the source root must not end up inside itself.
    $null = New-WCSZip -DestinationPath $zipInRoot -ExcludeDirNames '.git', 'Logs', 'Backups'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $z = [System.IO.Compression.ZipFile]::OpenRead($zipTest)
    $zipEntries = @($z.Entries | ForEach-Object { $_.FullName })
    $z.Dispose()
    Test-SuiteCheck -Name 'Zip: archive contains the suite files' -Pass ($zipEntries.Count -gt 50) -Detail "$($zipEntries.Count) entries"
    Test-SuiteCheck -Name 'Zip: entries keep directory structure (nested entries)' -Pass (@($zipEntries | Where-Object { $_ -match '/' }).Count -gt 50)
    Test-SuiteCheck -Name 'Zip: Runners/Run-Menu.ps1 archived under its folder' -Pass ($zipEntries -contains 'Runners/Run-Menu.ps1')
    Test-SuiteCheck -Name 'Zip: all 14 Manifest.psd1 present (no name collisions)' -Pass (@($zipEntries | Where-Object { $_ -like '*/Manifest.psd1' }).Count -eq 14)
    Test-SuiteCheck -Name 'Zip: no legacy runners in archive' -Pass (@($zipEntries | Where-Object { $_ -match 'Run-Cleanup|Run-Monthly|Restore-All' }).Count -eq 0)
    Test-SuiteCheck -Name 'Zip: .git/Logs/Backups excluded' -Pass (@($zipEntries | Where-Object { $_ -match '(^|/)\.git/|(^|/)Logs/|(^|/)Backups/' }).Count -eq 0)
    $z2 = [System.IO.Compression.ZipFile]::OpenRead($zipInRoot)
    $zipInRootEntries = @($z2.Entries | ForEach-Object { $_.FullName })
    $z2.Dispose()
    Test-SuiteCheck -Name 'Zip: destination inside source root is not archived into itself' -Pass (
        (Test-Path $zipInRoot) -and
        (@($zipInRootEntries | Where-Object { $_ -like 'wcs-zip-test-*' }).Count -eq 0))
} finally {
    if (Test-Path $zipTest) { Remove-Item $zipTest -Force -ErrorAction SilentlyContinue }
    if (Test-Path $zipInRoot) { Remove-Item $zipInRoot -Force -ErrorAction SilentlyContinue }
}

# --- 5. Menu smoke test (non-interactive, preview only; nothing should change) --------
$menuScript = Join-Path $SuiteRoot 'Runners\Run-Menu.ps1'
if (Test-Path $menuScript) {
    $smokeTopics = @('ServicesTasks', 'PrivacySettings', 'WindowsUpdates', 'OneDrive', 'Maintenance', 'DNS', 'PowerPlan', 'Privacy', 'Browsers', 'Network')
    Write-Host 'Running menu smoke test (non-interactive, preview) - this runs cleanup previews only...'
    $smokeOutput = & $menuScript -NonInteractive -Level 2 -Topics $smokeTopics 2>&1
    $smokeExit = $LASTEXITCODE
    Test-SuiteCheck -Name 'Smoke: Runners\Run-Menu.ps1 -NonInteractive preview exits 0' -Pass ($smokeExit -eq 0)
}

# --- 5b. Launcher checks ---------------------------------------------------------------
Test-SuiteCheck -Name 'Launcher: has -ZipUrl, -InstallDir, -Launch, -WhatIf params' -Pass (
    (Get-Content -Raw (Join-Path $SuiteRoot 'Launcher.ps1') -ErrorAction SilentlyContinue) -match '\[string\]\$ZipUrl' -and
    (Get-Content -Raw (Join-Path $SuiteRoot 'Launcher.ps1') -ErrorAction SilentlyContinue) -match '\[string\]\$InstallDir' -and
    (Get-Content -Raw (Join-Path $SuiteRoot 'Launcher.ps1')) -match '\[switch\]\$Launch' -and
    (Get-Content -Raw (Join-Path $SuiteRoot 'Launcher.ps1')) -match '\[switch\]\$WhatIf')

Write-Host 'Running Launcher dry run (Launcher.ps1 -WhatIf)...'
$launcherExit = $null
if (Test-Path (Join-Path $SuiteRoot 'Launcher.ps1')) {
    # Capture ALL streams (*>&1): the launcher prints via Write-Host (information
    # stream 6), which plain 2>&1 does not capture - that made this check fail on CI.
    $out = & (Join-Path $SuiteRoot 'Launcher.ps1') -WhatIf *>&1
    $launcherExit = $LASTEXITCODE
    Test-SuiteCheck -Name 'Smoke: Launcher.ps1 -WhatIf exits 0' -Pass ($launcherExit -eq 0)
    Test-SuiteCheck -Name 'Smoke: Launcher.ps1 -WhatIf prints the dry-run (does not download)' -Pass ((($out | Out-String) -replace '\x1b\[[0-9;]*m', '') -match 'dry run')
}

# --- 5c. Launcher one-liner docs + PS 5.1 compatibility --------------------------------
$launcherText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Launcher.ps1') -ErrorAction SilentlyContinue
$readmeText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'README.md') -ErrorAction SilentlyContinue
$oneLiner = 'irm https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/main/Launcher.ps1 | iex'
Test-SuiteCheck -Name 'Docs: one-liner pipes to iex in Launcher help AND README (plain irm never executes)' -Pass (
    $launcherText -match [regex]::Escape($oneLiner) -and $readmeText -match [regex]::Escape($oneLiner))
Test-SuiteCheck -Name 'Launcher: #requires -Version 5.1 (loadable on Windows PowerShell 5.1)' -Pass ($launcherText -match '#requires -Version 5\.1')
Test-SuiteCheck -Name 'Launcher: no PS7-only operators (??, ?., &&, ||)' -Pass ($launcherText -notmatch '\?\?|\?\.|&&|\|\|')

# $PSScriptRoot is empty inside parameter DEFAULT values on PS 5.1 - it must only
# be used in script bodies. Scan all suite files for the param-default pattern.
$paramDefaultRoot = @()
foreach ($f in @(Get-ChildItem -Path $SuiteRoot -Recurse -File -Include '*.ps1' -ErrorAction SilentlyContinue)) {
    if ($f.FullName -match '\\\.git\\') { continue }
    if ((Get-Content -Raw -LiteralPath $f.FullName) -match '=\s*\(Split-Path\s+-Parent\s+\$PSScriptRoot\)') { $paramDefaultRoot += $f.FullName }
}
Test-SuiteCheck -Name 'No $PSScriptRoot in parameter defaults (empty on PS 5.1)' -Pass ($paramDefaultRoot.Count -eq 0) -Detail ($paramDefaultRoot -join '; ')

# Run the PS 5.1 parser over all files when powershell.exe is available (Windows).
$ps51 = if ($env:OS -eq 'Windows_NT') { Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' } else { $null }
if ($ps51 -and (Test-Path $ps51)) {
    & $ps51 -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SuiteRoot 'Tests\Invoke-PS51ParseCheck.ps1') -SuiteRoot $SuiteRoot | Out-Host
    Test-SuiteCheck -Name 'PS 5.1 parser accepts all suite files' -Pass ($LASTEXITCODE -eq 0)
} else {
    Test-SuiteCheck -Name 'PS 5.1 parser accepts all suite files (skipped: no powershell.exe)' -Pass $true
}

# --- 5d. Runtime-safe expressions (statements in parens throw at RUNTIME on 5.1+7) ------
# A statement used as an expression must be wrapped in $(...) or @(...); a bare
# "(if ...)" parses as a command invocation and fails with "The term 'if' is not
# recognized" when the line executes (apply mode). Scan comment-stripped code only
# (comments and this test's own pattern strings would false-positive).
function Get-SuiteCodeWithoutComments {
    param([string]$Path)
    return ((Get-Content -LiteralPath $Path) -replace '#.*$', '') -join "`n"
}
$parenStatement = @()
$dotVarChained = @()
foreach ($f in @(Get-ChildItem -Path $SuiteRoot -Recurse -File -Include '*.ps1' -ErrorAction SilentlyContinue)) {
    if ($f.FullName -match '\\\.git\\') { continue }
    $code = Get-SuiteCodeWithoutComments -Path $f.FullName
    # statement-in-parens in expression position: after = , return or at line start
    if ($code -match '(?:^|[=,]|\breturn)\s*\((?:if|switch|foreach|while|for)\b') { $parenStatement += $f.FullName }
    # chained dynamic member .$var.prop parses as (($obj).$var).prop -> always $null
    if ($code -match '\.\$\w+\.\w+') { $dotVarChained += $f.FullName }
}
Test-SuiteCheck -Name 'No statement-in-parens (if/switch/foreach/...) - throws at runtime on PS 5.1 AND 7.x' -Pass ($parenStatement.Count -eq 0) -Detail ($parenStatement -join '; ')
$dotVarName = 'No chained dynamic member access (dot-' + '$var' + '.prop) - always yields $null; use the parenthesized form'
Test-SuiteCheck -Name $dotVarName -Pass ($dotVarChained.Count -eq 0) -Detail ($dotVarChained -join '; ')

# An UNBOUND optional [ValidateSet] parameter throws on variable access (PS 5.1 + 7.x).
# Optional ValidateSet params must be read via $PSBoundParameters only.
$engineText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Core\CleanupEngine.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'Engine: Set-WCSRegistryEntry has no [ValidateSet] on optional -Type (unbound read throws)' -Pass (
    $engineText -match '\[string\]\$Type' -and $engineText -notmatch '\[ValidateSet\([^\)]*\)\]\s*\r?\n\s*\[string\]\$Type')
Test-SuiteCheck -Name 'Engine: -Type read via $PSBoundParameters (safe when unbound) and key created via Test-Path' -Pass (
    $engineText -match '\$PSBoundParameters\.ContainsKey\(''Type''\)' -and $engineText -match 'Test-Path -LiteralPath \$Entry\.Path')
Test-SuiteCheck -Name 'Engine: Get-WCSRegistryValue reads value via .($Entry.Name)' -Pass (
    $engineText -match '\.\(\$Entry\.Name\)')

# --- 5e. Menu: Enter must be accepted immediately (not retried) ------------------------
$menuText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Core\WCS.Menu.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'Menu: Get-WCSMenuInput returns empty string immediately (Enter = accept, no retry loop)' -Pass (
    $menuText -match 'if \(\$null -eq \$value\) \{ return \$null \}' -and $menuText -match 'return \(\[string\]\$value\)\.Trim\(\)')
$topicEnter = '$input -eq ' + "''" + ') { return $selection }'
$levelEnter = '$choice -eq ' + "''" + ') { return $defaultKey }'
Test-SuiteCheck -Name 'Menu: topic menu accepts empty input as "accept selection"' -Pass ($menuText -match [regex]::Escape($topicEnter))
Test-SuiteCheck -Name 'Menu: level menu treats Enter as the default level' -Pass ($menuText -match [regex]::Escape($levelEnter))
Test-SuiteCheck -Name 'Menu: always exits explicitly (exit 0 on success - no stale $LASTEXITCODE leak to Run-Menu)' -Pass ($menuText -match '(?m)^exit 0\s*$')

# --- 5f. Failure isolation + launcher hygiene ------------------------------------------
$instSoft = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Cleanups\InstalledSoftware\Disable-InstalledSoftware.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'InstalledSoftware: UWP removal is per-app try/catch (one denied package cannot abort the run)' -Pass (
    $instSoft -match 'Could not remove UWP app' -and $instSoft -match 'Could not remove provisioned app' -and $instSoft -match 'Could not start uninstaller')
Test-SuiteCheck -Name 'Launcher: wipes old install dir with retry and falls back to a fresh dir when locked' -Pass (
    $launcherText -match 'was locked - using a fresh dir' -and $launcherText -match 'for \(\$i = 0; \$i -lt 3')
Test-SuiteCheck -Name 'Launcher: warns when extracted suite lacks Cleanups\\ or Runners\\' -Pass ($launcherText -match 'looks incomplete')

# --- 6. Independence from the previous project ---------------------------------------
$previousProjectRefs = @('run-full-debloat', 'run-monthly-debloat', 'startup-bloat', 'windows-speedup')
$thisFile = Join-Path $PSScriptRoot 'Invoke-SuiteTests.ps1'
$files = @(Get-ChildItem -Path $SuiteRoot -Recurse -File -Include '*.ps1', '*.psd1' -ErrorAction SilentlyContinue)
foreach ($ref in $previousProjectRefs) {
    $hits = @()
    foreach ($f in $files) {
        if ($f.FullName -ieq $thisFile) { continue }
        $hits += @(Select-String -Path $f.FullName -Pattern $ref -ErrorAction SilentlyContinue)
    }
    Test-SuiteCheck -Name "No references to previous project ('$ref')" -Pass ($hits.Count -eq 0)
}

# --- 9. Feature tests: parallel preview, -Quick mode, scheduler, backup review --------
# 9a. Menu wiring: new switches exist and are forwarded -------------------------------
Test-SuiteCheck -Name 'Menu: param block has -Quick/-NoParallel/-MaxParallel/-ScheduleDays/-ReviewBackups' -Pass (
    $menuText -match '\[switch\]\$Quick' -and
    $menuText -match '\[switch\]\$NoParallel' -and
    $menuText -match '\[int\]\$MaxParallel = 4' -and
    $menuText -match '\[int\]\$ScheduleDays = -1' -and
    $menuText -match '\[switch\]\$ReviewBackups')
Test-SuiteCheck -Name 'Menu: -Apply + -Quick is rejected with exit 1 (quick is preview-only)' -Pass (
    $menuText -match 'if \(\$Apply -and \$Quick\)' -and
    $menuText -match 'preview-only fast mode and cannot be combined with -Apply')
Test-SuiteCheck -Name 'Menu: preview runs in a runspace pool; -Apply/-NoParallel/single job stay sequential' -Pass (
    $menuText -match '\[runspacefactory\]::CreateRunspacePool' -and
    $menuText -match 'if \(\$Apply -or \$NoParallel -or \$jobs\.Count -eq 1\)' -and
    $menuText -match 'Invoke-WCSParallelCleanups')
Test-SuiteCheck -Name 'Menu: -Quick forwarded only to the heavy scanners via Get-WCSCleanupJobArgs' -Pass (
    $menuText -match 'function Get-WCSCleanupJobArgs' -and
    (@([regex]::Matches($menuText, "jobArgs\['Quick'\] = \$true")).Count -ge 2) -and
    $menuText -match 'Disable-ServicesAndTasks\.ps1' -and
    $menuText -match 'Disable-InstalledSoftware\.ps1' -and
    $menuText -match 'Disable-TempAndJunkFiles\.ps1')
Test-SuiteCheck -Name 'Menu: Save-WCSPreferences preserves an existing AutoReRunDays' -Pass (
    $menuText -match '\$existing = Read-WCSPreferences' -and
    $menuText -match 'AutoReRunDays = \$autoDays')
Test-SuiteCheck -Name 'Menu: action 4 schedules from AutoReRunDays pref (0 = unregister), action 5 runs review tool' -Pass (
    $menuText -match "Register-WCSReRunTask -Days \(\[int\]\$ans\)" -and
    $menuText -match "Register-WCSReRunTask -Days \$defaultDays" -and
    $menuText -match 'Tools\\Review-WCSBackup\.ps1')
Test-SuiteCheck -Name 'Runner: Run-Menu.ps1 forwards the new switches' -Pass (
    (Get-Content -Raw (Join-Path $SuiteRoot 'Runners\Run-Menu.ps1') -ErrorAction SilentlyContinue) -match '\[switch\]\$Quick' -and
    (Get-Content -Raw (Join-Path $SuiteRoot 'Runners\Run-Menu.ps1') -ErrorAction SilentlyContinue) -match '\[int\]\$ScheduleDays = -1' -and
    (Get-Content -Raw (Join-Path $SuiteRoot 'Runners\Run-Menu.ps1') -ErrorAction SilentlyContinue) -match '\[switch\]\$ReviewBackups')

# 9b. -Quick on the heavy cleanup scripts ---------------------------------------------
$quickScripts = @(
    'Cleanups\InstalledSoftware\Disable-InstalledSoftware.ps1',
    'Cleanups\TempAndJunkFiles\Disable-TempAndJunkFiles.ps1',
    'Cleanups\WindowsSpeedup\Disable-ServicesAndTasks.ps1'
)
foreach ($rel in $quickScripts) {
    $t = Get-Content -Raw -Path (Join-Path $SuiteRoot $rel) -ErrorAction SilentlyContinue
    Test-SuiteCheck -Name "Quick: $rel declares [switch]\$Quick" -Pass ($t -match '\[switch\]\$Quick')
}
$instText = Get-Content -Raw -Path (Join-Path $SuiteRoot $quickScripts[0]) -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'Quick: InstalledSoftware builds a single-pass Uninstall index and skips the provisioned scan' -Pass (
    $instText -match 'function Get-SuiteUninstallIndex' -and
    $instText -match 'Provisioned-package full scan skipped \(-Quick\)')
$tjText = Get-Content -Raw -Path (Join-Path $SuiteRoot $quickScripts[1]) -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'Quick: TempAndJunkFiles skips the recursive FilePatterns scan in -Quick mode' -Pass (
    $tjText -match 'if \(\$Quick\)' -and
    $tjText -match 'Get-ChildItem -Path \$resolved -Include \$pattern -Recurse')
$wsText = Get-Content -Raw -Path (Join-Path $SuiteRoot $quickScripts[2]) -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'Quick: ServicesAndTasks probes exact names directly and skips the OneDrive pattern scan' -Pass (
    $wsText -match 'Get-Service -Name \$Entry\.Name' -and
    $wsText -match 'Get-ScheduledTask -TaskName \$Entry\.Name -TaskPath \$Entry\.Path' -and
    $wsText -match 'Skipped OneDrive pattern scan \(-Quick\)')

# 9c. Scheduler: AutoReRunDays integration (WhatIf paths are safe non-admin) -----------
. (Join-Path $SuiteRoot 'Core\WCS.Scheduler.ps1')
Test-SuiteCheck -Name 'Scheduler: task name is WindowsCleanupSuite_ReRun' -Pass ($WCS_ReRunTaskName -eq 'WindowsCleanupSuite_ReRun')
# NOTE: -Prefs $null makes the functions read the real Config\UserPreferences.json
# (git-ignored, machine-dependent) - pass an empty object to test the deterministic fallback.
Test-SuiteCheck -Name 'Scheduler: -Days -1 resolves AutoReRunDays pref, fallback 7; explicit days pass through' -Pass (
    ((Get-WCSReRunDays -Days -1 -Prefs ([pscustomobject]@{ AutoReRunDays = 3 })) -eq 3) -and
    ((Get-WCSReRunDays -Days -1 -Prefs ([pscustomobject]@{})) -eq 7) -and
    ((Get-WCSReRunDays -Days 5) -eq 5))
Test-SuiteCheck -Name 'Scheduler: task command line honors stored Level/Topics (fallback -Level 4)' -Pass (
    ((Get-WCSReRunActionArguments -Prefs ([pscustomobject]@{})) -match '-Level 4') -and
    ((Get-WCSReRunActionArguments -Prefs ([pscustomobject]@{ Level = '2'; Topics = @('ServicesTasks', 'PrivacySettings') })) -match '-Level 2') -and
    ((Get-WCSReRunActionArguments -Prefs ([pscustomobject]@{ Level = '2'; Topics = @('ServicesTasks', 'PrivacySettings') })) -match 'ServicesTasks,PrivacySettings'))
Test-SuiteCheck -Name 'Scheduler: -WhatIf register/unregister previews return $true without touching the system' -Pass (
    (Register-WCSReRunTask -Days 3 -WhatIf -Prefs ([pscustomobject]@{})) -eq $true -and
    (Register-WCSReRunTask -Days 0 -WhatIf -Prefs ([pscustomobject]@{})) -eq $true)
$schedText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Core\WCS.Scheduler.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'Scheduler: registers as SYSTEM, admin-gated, -Days range -1..365, reads AutoReRunDays' -Pass (
    $schedText -match 'ValidateRange\(-1, 365\)' -and
    $schedText -match "-User 'SYSTEM'" -and
    $schedText -match 'Test-WCSIsAdmin' -and
    $schedText -match 'AutoReRunDays' -and
    $schedText -match 'if \(\$Days -eq 0\)')

# 9d. Backup review tool ---------------------------------------------------------------
$reviewText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Tools\Review-WCSBackup.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'Review: tool has -List/-Cleanup/-Restore, uses Get-SuiteBackupReview, admin-gates restore' -Pass (
    $reviewText -match '\[switch\]\$List' -and
    $reviewText -match '\[string\]\$Cleanup' -and
    $reviewText -match '\[switch\]\$Restore' -and
    $reviewText -match 'Get-SuiteBackupReview' -and
    $reviewText -match 'Test-SuiteIsAdmin' -and
    $reviewText -match 'Restore-WCSBackup\.ps1')
Test-SuiteCheck -Name 'Engine: Get-SuiteBackupReview enumerates Backups records' -Pass (
    $engineText -match 'function Get-SuiteBackupReview')

# 9e. Smoke: new CLI surfaces exit cleanly ----------------------------------------------
Write-Host 'Running feature smokes (-ReviewBackups, -Apply -Quick reject, -Quick preview)...'
$revOut = & $menuScript -ReviewBackups *>&1
Test-SuiteCheck -Name 'Smoke: Run-Menu -ReviewBackups exits 0 (lists records, no restore)' -Pass ($LASTEXITCODE -eq 0)

$null = & $menuScript -NonInteractive -Level 2 -Apply -Quick *>&1
Test-SuiteCheck -Name 'Smoke: -Apply + -Quick exits 1 immediately' -Pass ($LASTEXITCODE -eq 1)

$quickOut = & $menuScript -NonInteractive -Level 2 -Topics 'ServicesTasks' -Quick *>&1
$quickExit = $LASTEXITCODE
$quickPlain = (($quickOut | Out-String) -replace '\x1b\[[0-9;]*m', '')
Test-SuiteCheck -Name 'Smoke: -NonInteractive -Level 2 -Topics ServicesTasks -Quick preview exits 0' -Pass ($quickExit -eq 0)
Test-SuiteCheck -Name 'Smoke: quick preview header shows +quick and +parallel modes' -Pass (
    $quickPlain -match '\+quick' -and $quickPlain -match '\+parallel')

# --- 10. Hardening regressions (deep-review fixes) --------------------------------------

# 10a. Backups: a second run must never overwrite the ORIGINAL pre-change record.
$tmpBackup = Join-Path ([System.IO.Path]::GetTempPath()) "wcs-backup-test-$PID"
try {
    $null = New-SuiteBackupFile -BackupRoot $tmpBackup -FileName 'svc_test.txt' -Record @{ Type = 'Service'; StartType = 2 }
    $null = New-SuiteBackupFile -BackupRoot $tmpBackup -FileName 'svc_test.txt' -Record @{ Type = 'Service'; StartType = 3 }
    $savedRecord = Get-Content -Raw -Path (Join-Path $tmpBackup 'svc_test.txt') | ConvertFrom-Json
    Test-SuiteCheck -Name 'Backups: repeated runs preserve the ORIGINAL record (no overwrite)' -Pass ($savedRecord.StartType -eq 2)
} finally {
    if (Test-Path $tmpBackup) { Remove-Item -Recurse -Force $tmpBackup -ErrorAction SilentlyContinue }
}

# 10b. -Quick is preview-only in the heavy scripts themselves (not just the menu).
$quickGuardOk = $true
foreach ($rel in @('Cleanups\InstalledSoftware\Disable-InstalledSoftware.ps1', 'Cleanups\TempAndJunkFiles\Disable-TempAndJunkFiles.ps1', 'Cleanups\WindowsSpeedup\Disable-ServicesAndTasks.ps1')) {
    $t = Get-Content -Raw -Path (Join-Path $SuiteRoot $rel) -ErrorAction SilentlyContinue
    if ($t -notmatch '\$Quick -and -not \$WhatIfPreference') { $quickGuardOk = $false }
}
Test-SuiteCheck -Name 'Quick: all three heavy scripts reject -Quick without -WhatIf standalone' -Pass $quickGuardOk

# 10c. InstalledSoftware: provisioned handling is PS 5.1-compatible and preview-safe.
$instText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Cleanups\InstalledSoftware\Disable-InstalledSoftware.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'InstalledSoftware: provisioned scan has no -AllUsers (PS 5.1), removes by PackageName, ShouldProcess-gated' -Pass (
    ($instText -notmatch 'Get-AppxProvisionedPackage -Online -AllUsers') -and
    ($instText -match 'Remove-AppxProvisionedPackage -Online -PackageName \$pkg\.PackageName') -and
    ($instText -match 'ShouldProcess\(\$pkg\.DisplayName, ''Remove provisioned app''\)') -and
    ($instText -match 'PackageName = \$pkg\.PackageName'))
Test-SuiteCheck -Name 'InstalledSoftware: UWP removal is ShouldProcess-gated (preview cannot remove AppX)' -Pass (
    $instText -match 'ShouldProcess\(\$app\.Name, "Remove UWP app \(\$scope\)"\)')
Test-SuiteCheck -Name 'InstalledSoftware: Win32 preview scans installed apps BEFORE the ShouldProcess gate' -Pass (
    $instText -match 'Match installed apps FIRST')
$instRestoreText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Cleanups\InstalledSoftware\Restore-InstalledSoftware.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'InstalledSoftware: restore documents provisioned records as not auto-restorable + admin gate' -Pass (
    ($instRestoreText -match 'UwpProvisioned') -and ($instRestoreText -match 'Skipped \(Admin\)'))

# 10d. LoginSafe exclusions only apply when -LoginSafe was actually requested.
$wsText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Cleanups\WindowsSpeedup\Disable-ServicesAndTasks.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'ServicesAndTasks: LoginSafe exclusions gated behind -LoginSafe' -Pass (
    $wsText -match 'if \(\$LoginSafe -and \(Test-SuiteLoginSafeExcluded')
Test-SuiteCheck -Name 'ServicesAndTasks: AppModel backup records value existence (UserEnabledStartupOnceExists/LastDisabledTimeExists)' -Pass (
    ($wsText -match 'UserEnabledStartupOnceExists') -and ($wsText -match 'LastDisabledTimeExists'))
$wsRestoreText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Cleanups\WindowsSpeedup\Restore-ServicesAndTasks.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'ServicesAndTasks: restore prefers Enabled flag, QWORD LastDisabledTime, removes originally-absent values' -Pass (
    ($wsRestoreText -match 'hasEnabled') -and
    ($wsRestoreText -match '\[long\]\$record\.LastDisabledTime') -and
    ($wsRestoreText -match 'LastDisabledTimeExists') -and
    ($wsRestoreText -match 'VisualFXSettingExists'))

# 10e. TempAndJunkFiles: Package Cache is not junk; admin-only steps are gated.
$tjManifest = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Cleanups\TempAndJunkFiles\Manifest.psd1') -ErrorAction SilentlyContinue
$tjText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Cleanups\TempAndJunkFiles\Disable-TempAndJunkFiles.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'TempAndJunkFiles: Package Cache removed from junk targets (installer payloads)' -Pass (
    $tjManifest -notmatch "'%PROGRAMDATA%\\Package Cache',")
Test-SuiteCheck -Name 'TempAndJunkFiles: admin gates for system dirs, event logs, defrag' -Pass (
    ($tjText -match 'Skipped \(Admin\): clear event logs') -and
    ($tjText -match 'Skipped \(Admin\): defragment') -and
    ($tjText -match '\$resolved -like "\$\(\$env:SystemRoot\)\\\*"'))

# 10f. Network: static DNS on a DHCP interface must survive restore.
$netText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Cleanups\Network\Disable-Network.ps1') -ErrorAction SilentlyContinue
$netRestoreText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Cleanups\Network\Restore-Network.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'Network: backup records WasStaticDns (DNS origin, not IP DHCP state)' -Pass (
    ($netText -match 'WasStaticDns = \[bool\]\$staticDns') -and ($netText -match "NameServer"))
Test-SuiteCheck -Name 'Network: restore honors WasStaticDns and is admin-gated' -Pass (
    ($netRestoreText -match 'WasStaticDns') -and ($netRestoreText -match 'nothing was applied'))

# 10g. PowerPlan: activates the DUPLICATED scheme, backs up previous plan + hibernation.
$ppText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Cleanups\PowerPlan\Enable-UltimatePerformancePlan.ps1') -ErrorAction SilentlyContinue
$ppRestoreText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Cleanups\PowerPlan\Restore-PowerPlan.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'PowerPlan: parses the new GUID from -duplicatescheme and activates it' -Pass (
    ($ppText -match 'Get-WCSPowerCfgGuid') -and ($ppText -match '-setactive \$newGuid'))
Test-SuiteCheck -Name 'PowerPlan: PowerPlanState backup (previous scheme + hibernation); hibernate admin-gated' -Pass (
    ($ppText -match "Type = 'PowerPlanState'") -and
    ($ppText -match 'HibernateEnabled') -and
    ($ppText -match 'Skipped \(Admin\): disable hibernate'))
Test-SuiteCheck -Name 'PowerPlan: restore reactivates PreviousActiveScheme and restores hibernation ON/OFF' -Pass (
    ($ppRestoreText -match 'PreviousActiveScheme') -and ($ppRestoreText -match 'HIBERNATE \$onOff'))

# 10h. Menu/entry points: apply safety + honest failures + -WhatIf support.
$menuText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Core\WCS.Menu.ps1') -ErrorAction SilentlyContinue
$runnerText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Runners\Run-Menu.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'Menu: both entry scripts support -WhatIf (SupportsShouldProcess)' -Pass (
    ($menuText -match 'CmdletBinding\(SupportsShouldProcess = \$true\)') -and
    ($runnerText -match 'CmdletBinding\(SupportsShouldProcess = \$true\)'))
Test-SuiteCheck -Name 'Menu: apply requires confirmation (-AutoApprove), aborts without a restore point' -Pass (
    ($menuText -match 'function Confirm-WCSApply') -and
    (@(Select-String -Path (Join-Path $SuiteRoot 'Core\WCS.Menu.ps1') -Pattern 'Apply aborted: no System Restore point').Count -ge 2))
Test-SuiteCheck -Name 'Menu: missing cleanup script aborts job construction (no partial apply)' -Pass (
    $menuText -match 'Write-Error "  Missing script:')
Test-SuiteCheck -Name 'Menu: sequential runner fails on Write-Error (-ErrorAction Stop)' -Pass (
    $menuText -match '& \$job\.Path \@argHash -ErrorAction Stop')
Test-SuiteCheck -Name 'Menu: preferences written atomically (temp file + Move-Item)' -Pass (
    $menuText -match 'Move-Item -Path \$tmp -Destination \$file -Force')
Test-SuiteCheck -Name 'Menu: -ScheduleDays forwards -WhatIf to the scheduler' -Pass (
    $menuText -match 'Register-WCSReRunTask -Days \$ScheduleDays -WhatIf:\$WhatIfPreference')

# 10i. Scheduler: SYSTEM task hardening + argument-injection validation.
Test-SuiteCheck -Name 'Scheduler: task action uses -NoProfile -ExecutionPolicy Bypass and System32 PowerShell preferred' -Pass (
    ($schedText -match '-NoProfile -ExecutionPolicy Bypass -File') -and
    ($schedText -match 'if \(Test-Path \$systemPs\) \{ return \$systemPs \}'))
$injectedArgs = Get-WCSReRunActionArguments -Prefs ([pscustomobject]@{ Level = '4 -AllowRisky'; Topics = @('ServicesTasks', 'Bad;Topic') })
Test-SuiteCheck -Name 'Scheduler: hostile stored Level/Topics cannot inject task arguments' -Pass (
    ($injectedArgs -match '-Level 4') -and
    ($injectedArgs -notmatch '-AllowRisky') -and
    ($injectedArgs -notmatch 'Bad;Topic') -and
    ($injectedArgs -match "ServicesTasks"))
Test-SuiteCheck -Name 'Scheduler: unreadable prefs file fails registration instead of falling back to -Level 4' -Pass (
    $schedText -match 'unreadable/invalid JSON')

# 10j. Engine honesty + restore type fidelity.
Test-SuiteCheck -Name 'Engine: generic registry records capture PreviousType (old kind) + NewValue' -Pass (
    ($engineText -match 'PreviousType = \$prevType') -and ($engineText -match 'NewValue = \$Entry.Value'))
Test-SuiteCheck -Name 'Engine: service restore uses -ErrorAction Stop (no fake success)' -Pass (
    $engineText -match 'Set-Service -Name \$record\.Name -StartupType \$mode -ErrorAction Stop')
$toolText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Tools\Restore-WCSBackup.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'Restore tool: no bare $WhatIf variable (only $WhatIfPreference)' -Pass (
    ($toolText -notmatch '\(-not \$WhatIf\)') -and ($toolText -notmatch '-WhatIf:\$WhatIf(?![A-Za-z])'))
Test-SuiteCheck -Name 'Restore tool: single-owner restore (no duplicate registry passes) + error propagation' -Pass (
    ($toolText -match '\$ownedCleanups') -and ($toolText -match '-WhatIf:\$WhatIfPreference -ErrorAction Stop'))

# 10k. Updates + audits + zip helper hardening.
$updatesText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Core\WCS.Updates.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'Updates: re-debloat forwards Topics/AllowRisky via HASHTABLE splat (array splat mis-binds MaxParallel)' -Pass (
    ($updatesText -match '\[string\[\]\]\$Topics') -and
    ($updatesText -match "\`$menuArgs\['Topics'\]") -and
    ($updatesText -match '& \$menu \@menuArgs'))
# Behavioral: the exact menu-action-3 call shape must not throw a MaxParallel binding error.
. (Join-Path $SuiteRoot 'Core\WCS.Updates.ps1')
$redebloatOut = Invoke-WCSDebloatAfterUpdates -Level Balanced -Topics @('PowerPlan') *>&1
$redebloatText = ($redebloatOut | Out-String)
Test-SuiteCheck -Name 'Updates: re-debloat with Topics binds correctly (no MaxParallel transformation error)' -Pass (
    ($redebloatText -notmatch 'MaxParallel') -and
    ($redebloatText -notmatch 'Cannot process argument transformation') -and
    ($redebloatText -match 'Topics: PowerPlan'))
$auditStateText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Audit\Audit-State.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'Audit-State: PathPattern compared with -like (wildcards work)' -Pass (
    $auditStateText -match '\$pathIsPattern -and \$_\.TaskPath -like \$path')
$healthText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Audit\Check-SystemHealth.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'Check-SystemHealth: repair steps hard admin-gated (scan stays read-only)' -Pass (
    ($healthText -match 'Skipped \(Admin\): repair step') -and ($healthText -match '\$WhatIfPreference'))
$zipHelperText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Tools\New-WCSZip.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'New-WCSZip: LiteralPath for wildcard-safe source handling' -Pass (
    ($zipHelperText -match 'Resolve-Path -LiteralPath') -and ($zipHelperText -match 'Get-ChildItem -LiteralPath'))

# 10m. Updates: per-package (-PackageIds) and --force winget support.
# (README documents Invoke-WCSUpdateManager -PackageIds/-Force/-IncludeUnknown.)
$updatesText = Get-Content -Raw -Path (Join-Path $SuiteRoot 'Core\WCS.Updates.ps1') -ErrorAction SilentlyContinue
Test-SuiteCheck -Name 'Updates: -PackageIds/-Force/-IncludeUnknown supported, --include-unknown in default winget cmd' -Pass (
    ($updatesText -match '\[string\[\]\]\$PackageIds = @\(\)\)') -and
    ($updatesText -match '\[switch\]\$Force') -and
    ($updatesText -match '\[switch\]\$IncludeUnknown') -and
    ($updatesText -match "'--include-unknown'") -and
    ($updatesText -match '--force') -and
    ($updatesText -match '--id.*\$id'))

# 10l. Smoke: -WhatIf now binds on the entry point (scheduler preview path).
$null = & $menuScript -ScheduleDays 3 -WhatIf *>&1
Test-SuiteCheck -Name 'Smoke: Run-Menu -ScheduleDays 3 -WhatIf exits 0 (preview, no registration)' -Pass ($LASTEXITCODE -eq 0)

Write-Host ''
Write-Host "Results: $($script:Passed) passed, $($script:Failed) failed"
if ($script:Failed -gt 0) { exit 1 }
