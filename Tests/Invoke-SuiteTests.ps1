#requires -Version 5.1
<#
.SYNOPSIS
    Structural tests for the WindowsCleanupSuite (read-only).

.DESCRIPTION
    1. Parses every .ps1 file in the project (Parser::ParseInput).
    2. Verifies each cleanup has a Manifest.psd1, Disable and Restore scripts.
    3. Verifies manifests import and define ProtectedPatterns (DSA protected).
    4. Verifies runners/audit/engine/tests files exist.
    5. Verifies the project does not reference the previous project
       (run-full-debloat, startup-bloat, windows-speedup).

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
    @{ Cleanup = 'TempAndJunkFiles';  Manifest = 'Manifest.psd1'; Disable = 'Disable-TempAndJunkFiles.ps1';       Restore = 'Restore-TempAndJunkFiles.ps1';       Protected = @('*DSA*', '*Driver*Support*') },
    @{ Cleanup = 'PowerPlan';         Manifest = 'Manifest.psd1'; Disable = 'Enable-UltimatePerformancePlan.ps1'; Restore = 'Restore-PowerPlan.ps1';             Protected = @('*DSA*', '*Driver*Support*') },
    @{ Cleanup = 'DNSReset';          Manifest = 'Manifest.psd1'; Disable = 'Disable-DNSReset.ps1';                Restore = 'Restore-DNSReset.ps1';                Protected = @('*DSA*', '*Driver*Support*') }
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
            'TempAndJunkFiles'  { 'Directories' }
            'PowerPlan'         { 'PowerPlans' }
            'DNSReset'          { 'Commands' }
            default             { 'Services' }
        }
        $entries = @($manifest.$entriesKey | Where-Object { $null -ne $_ })
        Test-SuiteCheck -Name "Manifest defines '$entriesKey' ($($entries.Count) entries)" -Pass ($entries.Count -gt 0)
        if ($expected.Cleanup -eq 'WindowsSpeedup') {
            foreach ($key in @('Tasks', 'RunAutoruns', 'StartupApproved', 'AppModelStartup', 'ProcessStops')) {
                $sub = @($manifest.$key | Where-Object { $null -ne $_ })
                Test-SuiteCheck -Name "Manifest defines '$key' ($($sub.Count) entries)" -Pass ($sub.Count -gt 0)
            }
        }
    }
}

# --- 3. Runner / audit / engine files --------------------------------------------------
foreach ($rel in @('Runners\Run-Cleanup.ps1', 'Runners\Run-Monthly.ps1', 'Audit\Audit-State.ps1', 'Audit\Audit-InstalledSoftware.ps1', 'Audit\Audit-RunningServices.ps1', 'Audit\Check-SystemHealth.ps1', 'Tests\Invoke-SuiteTests.ps1', 'Core\CleanupEngine.ps1')) {
    Test-SuiteCheck -Name "File exists: $rel" -Pass (Test-Path (Join-Path $SuiteRoot $rel))
}

# --- 4. Independence from the previous project --------------------------------------------
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
