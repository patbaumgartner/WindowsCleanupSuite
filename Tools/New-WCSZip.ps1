#requires -Version 5.1
<#
.SYNOPSIS
    Creates a zip archive of the suite that preserves the directory structure.

.DESCRIPTION
    Compress-Archive flattens every entry to its file name only - with absolute
    paths AND with repo-relative paths - so same-named files (the 14
    Manifest.psd1, ci.yml/release.yml, ...) collide into a single entry and the
    extracted archive is unusable. New-WCSZip uses System.IO.Compression directly
    and writes each file under its source-relative path with '/' separators,
    which is the layout Launcher.ps1 expects after Expand-Archive.

    Dot-source this file, then call New-WCSZip:

    . .\Tools\New-WCSZip.ps1
    New-WCSZip -DestinationPath 'WindowsCleanupSuite-v1.1.0.zip'
#>

function New-WCSZip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        # Directory to archive. Defaults to the repo root (parent of Tools\).
        [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot),

        # Directory names skipped at any depth.
        [string[]]$ExcludeDirNames = @('.git', 'Logs', 'Backups')
    )

    $SourceRoot = (Resolve-Path -Path $SourceRoot -ErrorAction Stop).Path
    $DestinationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath)
    if (Test-Path -LiteralPath $DestinationPath) { Remove-Item -LiteralPath $DestinationPath -Force }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::Open($DestinationPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $count = 0
        foreach ($item in (Get-ChildItem -Path $SourceRoot -File -Recurse -Force -ErrorAction SilentlyContinue)) {
            $rel = $item.FullName.Substring($SourceRoot.Length).TrimStart('\', '/') -replace '\\', '/'
            $segments = $rel -split '/'
            $dirSegments = if ($segments.Count -gt 1) { $segments[0..($segments.Count - 2)] } else { @() }
            if (@($dirSegments | Where-Object { $ExcludeDirNames -contains $_ }).Count -gt 0) { continue }
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, $item.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
            $count++
        }
    } finally {
        $archive.Dispose()
    }

    Write-Output $count
}
