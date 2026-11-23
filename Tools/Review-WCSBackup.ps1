#requires -Version 5.1
<#
.SYNOPSIS
    Reviews the backup records written by WindowsCleanupSuite (Backups\<Cleanup>\**)
    before restoring - interactive picker, or -List for a non-interactive dump.

.DESCRIPTION
    Every cleanup writes JSON/TXT backup records under Backups\<Cleanup>\.
    This tool enumerates them via Get-SuiteBackupReview (Core\CleanupEngine.ps1) and shows
    one row per record: cleanup folder, file, record type, name and a one-line detail -
    i.e. exactly what a restore would undo.

    -List               non-interactive: print all records grouped by cleanup, then exit.
    -Cleanup Name       restrict the review to one cleanup subfolder of Backups\.
    interactive (default):
        1. summary per cleanup (record counts)
        2. pick a cleanup (number, 'a' or Enter = all) to see its records
        3. optionally run the restore (Tools\Restore-WCSBackup.ps1 -Backups);
           restoring requires Administrator.

.PARAMETER List
    Non-interactive: list every backup record and exit (no restore).

.PARAMETER Cleanup
    Only review this cleanup subfolder of Backups\ (e.g. WindowsSpeedup).

.PARAMETER Restore
    After the review, run Tools\Restore-WCSBackup.ps1 -Backups (requires Administrator).

.PARAMETER WhatIf
    Preview: show what would be restored, but do not run the restore.

.EXAMPLE
    & 'Tools\Review-WCSBackup.ps1'                              # interactive review, optional restore
    & 'Tools\Review-WCSBackup.ps1' -List                        # dump all records (non-interactive)
    & 'Tools\Review-WCSBackup.ps1' -Cleanup WindowsSpeedup -List
    Runners\Run-Menu.ps1 -ReviewBackups                          # same as -List via the menu runner
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$List,
    [string]$Cleanup = '',
    [switch]$Restore
)

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Core\CleanupEngine.ps1')

$SuiteRoot   = Get-SuiteRoot
$backupRoot  = Join-Path $SuiteRoot 'Backups'
$restoreTool = Join-Path $SuiteRoot 'Tools\Restore-WCSBackup.ps1'

function Read-WCSReviewInput {
    <# One line of piped/console input; $null only on EOF. #>
    param([string]$Prompt)
    $value = Read-Host $Prompt
    if ($null -eq $value) { return $null }
    return ([string]$value).Trim()
}

function Show-WCSBackupReviewRows {
    param([psobject[]]$Rows, [string]$Title = '')
    if ($Title) { Write-Host '' ; Write-Host "--- $Title ---" -ForegroundColor Magenta }
    if (-not $Rows.Count) { Write-Host '  (no backup records)' -ForegroundColor DarkGray; return }
    $i = 0
    foreach ($row in $Rows) {
        $i++
        Write-Host ("  [{0,3}] {1,-15} {2} | {3}" -f $i, $row.Type, $row.Name, $row.Detail)
        Write-Host ("        file: $($row.File)") -ForegroundColor DarkGray
    }
}

function Invoke-WCSReviewRestore {
    <# Runs Tools\Restore-WCSBackup.ps1 -Backups; admin-gated unless -WhatIf. #>
    if (-not (Test-Path -LiteralPath $restoreTool)) { Write-Warning "  Missing: $restoreTool"; return $false }
    if (-not $WhatIfPreference -and -not (Test-SuiteIsAdmin)) {
        Write-Error '  Restore requires Administrator privileges. Elevate with "Run as Administrator".'
        return $false
    }
    Write-Host ''
    Write-Host 'Running restore (Tools\Restore-WCSBackup.ps1 -Backups)...' -ForegroundColor Cyan
    & $restoreTool -Backups
    return ($LASTEXITCODE -eq 0)
}

# --- collect the records -----------------------------------------------------------
if (-not (Test-Path -LiteralPath $backupRoot)) {
    Write-Host "No backups yet - $backupRoot does not exist. Run the suite with -Apply first." -ForegroundColor Yellow
    exit 0
}
if ($Cleanup -and -not (Test-Path -LiteralPath (Join-Path $backupRoot $Cleanup))) {
    $available = @((Get-ChildItem -Path $backupRoot -Directory -ErrorAction SilentlyContinue).Name)
    Write-Error "  Unknown cleanup folder: '$Cleanup'. Available: $($available -join ', ')"
    exit 1
}

$rows = @(Get-SuiteBackupReview -BackupRoot $backupRoot -Cleanup $Cleanup)

# --- -List: non-interactive dump ----------------------------------------------------
if ($List) {
    Write-Host "Backup records in $backupRoot" -ForegroundColor Cyan
    if (-not $rows.Count) { Write-Host '  (no backup records)' -ForegroundColor DarkGray; exit 0 }
    $groups = @($rows | Group-Object -Property Cleanup | Sort-Object Name)
    foreach ($g in $groups) {
        Show-WCSBackupReviewRows -Rows @($g.Group) -Title "$($g.Name) ($($g.Count) record(s))"
    }
    Write-Host ''
    Write-Host "Total: $($rows.Count) backup record(s) in $($groups.Count) cleanup folder(s)." -ForegroundColor Green
    Write-Host 'Restore with: Tools\Restore-WCSBackup.ps1 -Backups (requires Administrator).' -ForegroundColor Gray
    exit 0
}

# --- interactive review -------------------------------------------------------------
Write-Host 'WindowsCleanupSuite - backup record review' -ForegroundColor Cyan
Write-Host "Backups root: $backupRoot"
if (-not $rows.Count) {
    Write-Host '  (no backup records)' -ForegroundColor DarkGray
    Write-Host 'Nothing to review - run the suite with -Apply first.' -ForegroundColor Yellow
    exit 0
}

$groups = @($rows | Group-Object -Property Cleanup | Sort-Object Name)
Write-Host ''
Write-Host 'Records per cleanup:'
for ($i = 0; $i -lt $groups.Count; $i++) {
    Write-Host ("  [{0}] {1} - {2} record(s)" -f ($i + 1), $groups[$i].Name, $groups[$i].Count)
}

$pick = Read-WCSReviewInput -Prompt "Cleanup to inspect [1-$($groups.Count)] ('a' or Enter = all)"
if ($null -eq $pick -or $pick -eq '' -or $pick -in @('a', 'all')) {
    $selected = $groups
} elseif ($pick -match '^\d+$' -and [int]$pick -ge 1 -and [int]$pick -le $groups.Count) {
    $selected = @($groups[[int]$pick - 1])
} else {
    Write-Host "  Invalid selection '$pick' - showing all." -ForegroundColor Yellow
    $selected = $groups
}

foreach ($g in $selected) {
    Show-WCSBackupReviewRows -Rows @($g.Group) -Title "$($g.Name) ($($g.Count) record(s))"
}
Write-Host ''
Write-Host "Total: $($rows.Count) backup record(s) in $($groups.Count) cleanup folder(s)." -ForegroundColor Green

# --- optional restore ----------------------------------------------------------------
$doRestore = $Restore
if (-not $doRestore) {
    $ans = Read-WCSReviewInput -Prompt 'Run restore now (Tools\Restore-WCSBackup.ps1 -Backups)? [y/N]'
    if ($null -ne $ans -and $ans -in @('y', 'yes')) { $doRestore = $true }
}
if ($doRestore) {
    if ($WhatIfPreference) {
        Write-Host '  (-WhatIf) Would run: Tools\Restore-WCSBackup.ps1 -Backups' -ForegroundColor Yellow
        exit 0
    }
    if (Invoke-WCSReviewRestore) { exit 0 } else { exit 1 }
}
exit 0
