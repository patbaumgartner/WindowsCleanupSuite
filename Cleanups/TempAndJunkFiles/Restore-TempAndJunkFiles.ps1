#requires -Version 5.1
<#
.SYNOPSIS
    Deleting temporary files and event logs is not reversible - no restore.

.PARAMETER WhatIf
    Preview mode - shows what would change without touching the system.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

Write-Host 'TempAndJunkFiles: deleting temporary files, logs and event logs is not reversible.'
Write-Host 'Restore actions: none needed (the deleted files are junk by definition).'
