#requires -Version 5.1
<#
.SYNOPSIS
    Audit: lists running services.

.DESCRIPTION
    Reports every running service on the machine. Read-only.

.EXAMPLE
    & 'WindowsCleanupSuite\Audit\Audit-RunningServices.ps1'
#>
[CmdletBinding()]
param()

$rows = @(Get-Service | Where-Object { $_.Status -eq 'Running' } | Select-Object -Property Name, Status, DisplayName | Sort-Object Name)
Write-Host "Running services: $($rows.Count)"
$rows | Format-Table -AutoSize | Out-String | Write-Host
