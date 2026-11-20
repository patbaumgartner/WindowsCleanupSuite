#requires -Version 5.1
<#
.SYNOPSIS
    DNS reset is not reversible - no restore actions.

.PARAMETER WhatIf
    Preview mode.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

Write-Host 'DNSReset: DNS cache reset is not reversible - no restore actions.'
