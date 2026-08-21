[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ReleaseRoot,

    [string]$ReportPath,

    [switch]$SkipDependencyScan,

    [switch]$WriteManifest
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:Results = New-Object System.Collections.Generic.List[object]

function Add-CheckResult {
    param(
        [ValidateSet('PASS', 'WARNING', 'FAIL')]
        [string]$Status,
        [string]$Check,
        [string]$Detail
    )

    $script:Results.Add([pscustomobject]@{
        Status = $Status
        Check  = $Check
        Detail = $Detail
    }) | Out-Null

    $color = switch ($Status) {
        'PASS'    { 'Green' }
        'WARNING' { 'Yellow' }
        'FAIL'    { 'Red' }
    }
    Write-Host ('[{0,-7}] {1}: {2}' -f $Status, $Check, $Detail) -ForegroundColor $color
}

function Resolve-PackageRoot {
    param([string]$RequestedRoot)

    if (-not (Test-Path -LiteralPath $RequestedRoot -PathType Container)) {
        throw "Release directory does not exist: $RequestedRoot"
    }

    $resolved = (Resolve-Path -LiteralPath $RequestedRoot).Path
    if (Test-Path -LiteralPath (Join-Path $resolved 'bin') -PathType Container) {
        return $resolved
    }

    $candidates = @(
        Get-ChildItem -LiteralPath $resolved -Directory -ErrorAction Stop |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin') -PathType Container }
    )

    if ($candidates.Count -eq 1) {
        Add-CheckResult 'WARNING' 'Package root' (
            "Detected one nested package folder and will inspect it: {0}" -f $candidates[0].FullName)
        return $candidates[0].FullName
    }

    throw "Could not find a bin directory at '$resolved' or exactly one level beneath it."
}

function Test-RequiredPath {
    param(
        [string]$BasePath,
        [string]$RelativePath,
        [ValidateSet('File', 'Directory')]
        [string]$Kind,
        [bool]$Required = $true
    )

    $fullPath = Join-Path $BasePath $RelativePath
    $pathType = if ($Kind -eq 'File') { 'Leaf' } else { 'Container' }
    if (Test-Path -LiteralPath $fullPath -PathType $pathType) {
        Add-CheckResult 'PASS' $RelativePath 'Present'
        return $true
    }

    $status = if ($Required) { 'FAIL' } else { 'WARNING' }
    Add-CheckResult $status $RelativePath ("Missing required {0}" -f $Kind.ToLowerInvariant())
    return $false
}

function Get-ImportedDllNames {
    param(
        [string]$DumpbinPath,
        [string]$BinaryPath
    )

    $output = & $DumpbinPath /nologo /dependents $BinaryPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "dumpbin failed for '$BinaryPath': $($output -join ' ')"
    }

    @(
        $output |
            ForEach-Object {
                if ($_ -match '^\s+([A-Za-z0-9_.-]+\.dll)\s*$') {
                    $matches[1]
                }
            } |
            Sort-Object -Unique
    )
}

function Test-BinaryDependencies {
    param(
        [string]$PackageRoot,
        [string]$BinPath
    )

    $dumpbin = Get-Command dumpbin.exe -ErrorAction SilentlyContinue
    if (-not $dumpbin) {
        Add-CheckResult 'WARNING' 'DLL dependency scan' (
            'dumpbin.exe was not found. Run this script from a Visual Studio Developer Command Prompt for a full scan.')
        return
    }

    $windowsDirectory = if ($env:SystemRoot) { $env:SystemRoot } else { $env:WINDIR }
    $systemDirectories = @(
        (Join-Path $windowsDirectory 'System32'),
        (Join-Path $windowsDirectory 'SysWOW64')
    )
    $compilerRuntimePattern = '^(vcruntime|msvcp|concrt)[0-9_]*\.dll$'
    $binaries = @(
        Get-ChildItem -LiteralPath $BinPath -File |
            Where-Object { $_.Extension -in @('.exe', '.dll') }
    )

    if ($binaries.Count -eq 0) {
        Add-CheckResult 'FAIL' 'DLL dependency scan' 'No executable or DLL files were found in bin.'
        return
    }

    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($binary in $binaries) {
        try {
            $imports = Get-ImportedDllNames -DumpbinPath $dumpbin.Source -BinaryPath $binary.FullName
        } catch {
            Add-CheckResult 'WARNING' ("Dependencies: {0}" -f $binary.Name) $_.Exception.Message
            continue
        }

        foreach ($import in $imports) {
            $apiSet = $import -match '^(api-ms-win-|ext-ms-win-)'
            $windowsProvidesDll = $false
            if ($import -notmatch $compilerRuntimePattern) {
                $windowsProvidesDll = $apiSet -or @(
                    $systemDirectories | Where-Object {
                        Test-Path -LiteralPath (Join-Path $_ $import) -PathType Leaf
                    }
                ).Count -gt 0
            }
            if ($windowsProvidesDll) {
                continue
            }

            $localDependency = Join-Path $BinPath $import
            if (-not (Test-Path -LiteralPath $localDependency -PathType Leaf)) {
                $missing.Add(("{0} -> {1}" -f $binary.Name, $import)) | Out-Null
            }
        }
    }

    if ($missing.Count -gt 0) {
        foreach ($item in ($missing | Sort-Object -Unique)) {
            Add-CheckResult 'FAIL' 'Missing DLL dependency' $item
        }
    } else {
        Add-CheckResult 'PASS' 'DLL dependency scan' (
            "All non-system imports for {0} top-level binaries resolve inside bin." -f $binaries.Count)
    }

    $platformPlugin = Join-Path $BinPath 'platforms\qwindows.dll'
    if (Test-Path -LiteralPath $platformPlugin -PathType Leaf) {
        Add-CheckResult 'PASS' 'Qt platform plugin' 'bin\platforms\qwindows.dll is present.'
    } else {
        Add-CheckResult 'FAIL' 'Qt platform plugin' 'bin\platforms\qwindows.dll is missing.'
    }
}

function Write-HashManifest {
    param(
        [string]$PackageRoot,
        [string]$Destination,
        [string[]]$ExcludedPaths = @()
    )

    $destinationFullPath = [System.IO.Path]::GetFullPath($Destination)
    $excludedFullPaths = @(
        $ExcludedPaths | ForEach-Object { [System.IO.Path]::GetFullPath($_) }
    )
    $mutableSettingsPrefix = [System.IO.Path]::GetFullPath(
        (Join-Path $PackageRoot 'settings')).TrimEnd([char[]]@('\', '/')) +
        [System.IO.Path]::DirectorySeparatorChar
    $files = @(
        Get-ChildItem -LiteralPath $PackageRoot -File -Recurse |
            Where-Object {
                $fullPath = [System.IO.Path]::GetFullPath($_.FullName)
                $isMutableSetting = $fullPath.StartsWith(
                    $mutableSettingsPrefix,
                    [System.StringComparison]::OrdinalIgnoreCase)
                $fullPath -ne $destinationFullPath -and
                    $fullPath -notin $excludedFullPaths -and
                    -not $isMutableSetting
            } |
            Sort-Object FullName
    )

    $lines = foreach ($file in $files) {
        try {
            $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        } catch {
            Add-CheckResult 'WARNING' 'SHA-256 manifest' (
                "Skipped unreadable file '{0}': {1}" -f $file.FullName, $_.Exception.Message)
            continue
        }
        $relative = $file.FullName.Substring($PackageRoot.Length).TrimStart([char[]]@('\', '/'))
        '{0}  {1}' -f $hash, $relative.Replace('\', '/')
    }

    $parent = Split-Path -Parent $Destination
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $Destination -Value $lines -Encoding UTF8
    $hashCount = @($lines).Count
    Add-CheckResult 'PASS' 'SHA-256 manifest' (
        "Wrote {0} file hashes to {1}" -f $hashCount, $Destination)
}

Write-Host ''
Write-Host 'PZTools Windows Release Verification' -ForegroundColor Cyan
Write-Host '====================================' -ForegroundColor Cyan

try {
    $packageRoot = Resolve-PackageRoot -RequestedRoot $ReleaseRoot
} catch {
    Write-Host ("[FAIL   ] Package root: {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 2
}

Write-Host ("Package root: {0}" -f $packageRoot)
Write-Host ''

if (-not $ReportPath) {
    $ReportPath = Join-Path $packageRoot 'PZTools-release-verification.txt'
}

$requiredDirectories = @('bin', 'config')
$recommendedDirectories = @('brushes', 'docs', 'licenses', 'lua', 'plugins', 'themes', 'translations')
$requiredExecutables = @('bin\PZWorldEd.exe', 'bin\TileZed.exe', 'bin\BuildingEd.exe')
$requiredRuntimeFiles = @('bin\zlib1.dll', 'bin\worlded.dll')
$requiredCatalogues = @(
    'config\Rules.txt',
    'config\Blends.txt',
    'config\Tilesets.txt',
    'config\TMXConfig.txt',
    'config\BuildingTiles.txt',
    'config\BuildingFurniture.txt',
    'config\BuildingTemplates.txt',
    'config\RoomNames.txt',
    'config\RoomTone.txt',
    'config\WorldDefaults.txt'
)
$recommendedDocuments = @(
    'AUTHORS.txt',
    'COPYING.txt',
    'SOURCE-OFFER.txt',
    'THIRD_PARTY_NOTICES.txt',
    'UPSTREAM-HISTORY.md'
)

foreach ($path in $requiredDirectories) {
    [void](Test-RequiredPath $packageRoot $path 'Directory' $true)
}
foreach ($path in $recommendedDirectories) {
    [void](Test-RequiredPath $packageRoot $path 'Directory' $false)
}
foreach ($path in $requiredExecutables) {
    [void](Test-RequiredPath $packageRoot $path 'File' $true)
}
foreach ($path in $requiredRuntimeFiles) {
    [void](Test-RequiredPath $packageRoot $path 'File' $true)
}
foreach ($path in $requiredCatalogues) {
    [void](Test-RequiredPath $packageRoot $path 'File' $true)
}
foreach ($path in $recommendedDocuments) {
    [void](Test-RequiredPath $packageRoot $path 'File' $false)
}

$binPath = Join-Path $packageRoot 'bin'
if ((Test-Path -LiteralPath $binPath -PathType Container) -and -not $SkipDependencyScan) {
    Test-BinaryDependencies -PackageRoot $packageRoot -BinPath $binPath
} elseif ($SkipDependencyScan) {
    Add-CheckResult 'WARNING' 'DLL dependency scan' 'Skipped by request.'
}

if ($WriteManifest) {
    $manifestPath = Join-Path $packageRoot 'SHA256SUMS.txt'
    Write-HashManifest -PackageRoot $packageRoot -Destination $manifestPath -ExcludedPaths @($ReportPath)
}

$failureCount = @($script:Results | Where-Object Status -eq 'FAIL').Count
$warningCount = @($script:Results | Where-Object Status -eq 'WARNING').Count
$passCount = @($script:Results | Where-Object Status -eq 'PASS').Count

$reportDirectory = Split-Path -Parent $ReportPath
if ($reportDirectory -and -not (Test-Path -LiteralPath $reportDirectory)) {
    New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
}

$reportLines = @(
    'PZTools Windows Release Verification',
    ('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')),
    ('Package root: {0}' -f $packageRoot),
    ('Summary: {0} passed, {1} warning(s), {2} failure(s)' -f $passCount, $warningCount, $failureCount),
    ''
)
$reportLines += $script:Results | ForEach-Object {
    '[{0}] {1}: {2}' -f $_.Status, $_.Check, $_.Detail
}
Set-Content -LiteralPath $ReportPath -Value $reportLines -Encoding UTF8

Write-Host ''
Write-Host ("Summary: {0} passed, {1} warning(s), {2} failure(s)" -f $passCount, $warningCount, $failureCount) -ForegroundColor Cyan
Write-Host ("Report:  {0}" -f $ReportPath)

if ($failureCount -gt 0) {
    Write-Host 'RESULT: RELEASE IS NOT READY' -ForegroundColor Red
    exit 1
}

Write-Host 'RESULT: RELEASE PASSED REQUIRED CHECKS' -ForegroundColor Green
exit 0
