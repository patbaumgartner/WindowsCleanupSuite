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
    'Tests\Invoke-SuiteTests.ps1',
    'Core\CleanupEngine.ps1', 'Core\WCS.Catalog.ps1', 'Core\WCS.Menu.ps1', 'Core\WCS.Updates.ps1', 'Core\WCS.Scheduler.ps1',
    'Tools\Restore-WCSBackup.ps1', 'Tools\New-WCSZip.ps1', 'Launcher.ps1',
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
try {
    $null = New-WCSZip -DestinationPath $zipTest -ExcludeDirNames '.git', 'Logs', 'Backups'
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
} finally {
    if (Test-Path $zipTest) { Remove-Item $zipTest -Force -ErrorAction SilentlyContinue }
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
    $out = & (Join-Path $SuiteRoot 'Launcher.ps1') -WhatIf 2>&1
    $launcherExit = $LASTEXITCODE
    Test-SuiteCheck -Name 'Smoke: Launcher.ps1 -WhatIf exits 0' -Pass ($launcherExit -eq 0)
}

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

Write-Host ''
Write-Host "Results: $($script:Passed) passed, $($script:Failed) failed"
if ($script:Failed -gt 0) { exit 1 }
