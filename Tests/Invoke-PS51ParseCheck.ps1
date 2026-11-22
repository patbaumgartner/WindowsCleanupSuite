#requires -Version 5.1
<#
.SYNOPSIS
    Parses every suite .ps1/.psd1 file with the Windows PowerShell 5.1 parser.

.DESCRIPTION
    Run with Windows PowerShell 5.1 (powershell.exe), e.g. from CI:

      powershell.exe -NoProfile -ExecutionPolicy Bypass -File Tests\Invoke-PS51ParseCheck.ps1

    Guarantees the suite (including the self-executing Launcher.ps1) stays loadable
    on legacy Windows PowerShell 5.1 - the pwsh 7.x parser accepts syntax that 5.1
    rejects, so the 7.x-only parse check in ci.yml is not sufficient.

.EXAMPLE
    & $env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -File Tests\Invoke-PS51ParseCheck.ps1
#>
[CmdletBinding()]
param(
    [string]$SuiteRoot
)

# NOTE: $PSScriptRoot is EMPTY inside parameter default values on PS 5.1 -
# resolve it in the body instead.
if (-not $SuiteRoot) { $SuiteRoot = Split-Path -Parent $PSScriptRoot }

$bad = 0
foreach ($f in (Get-ChildItem -Path $SuiteRoot -Recurse -File -Include '*.ps1', '*.psd1' -ErrorAction SilentlyContinue)) {
    if ($f.FullName -match '\\\.git\\') { continue }
    $tokens = $null; $errors = $null
    try {
        [System.Management.Automation.Language.Parser]::ParseInput((Get-Content -Raw -LiteralPath $f.FullName -ErrorAction Stop), [ref]$tokens, [ref]$errors) | Out-Null
    } catch {
        Write-Host "PARSE ERROR: $($f.FullName): $($_.Exception.Message)"
        $bad++
        continue
    }
    $errs = @($errors | Where-Object { $null -ne $_ })
    if ($errs.Count -gt 0) {
        Write-Host "SYNTAX ERRORS (PS 5.1 parser) in $($f.FullName):"
        foreach ($e in ($errs | Select-Object -First 3)) { Write-Host "  line $($e.Extent.StartLine): $($e.Message)" }
        $bad++
    }
}
Write-Host "PS $($PSVersionTable.PSVersion) parser: $bad file(s) with errors"
if ($bad -gt 0) { exit 1 }
