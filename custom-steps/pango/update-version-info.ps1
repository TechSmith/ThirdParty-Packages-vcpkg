<#
.SYNOPSIS
  Updates fileVersion and productVersion in version-info.json from per-file source manifests.

.DESCRIPTION
  - Reads a version-info.json file.
  - For each entry under .files[]:
      * If "versionSource" is present, combine RootPath + versionSource.
      * Validate the file exists; if any is missing, stop without writing.
      * Read the source JSON (e.g., vcpkg.json) and extract the version.
        Supports common vcpkg manifest keys: version, version-semver, version-string, version-date.
      * Set fileVersion and productVersion to the extracted version.
  - Writes the updated version-info.json (UTF‑8 without BOM).

.PARAMETER VersionInfoPath
  Path to version-info.json to update.

.PARAMETER RootPath
  The base directory that will be combined with each files[i].versionSource.

.EXAMPLE
  .\Update-VersionInfo.ps1 -VersionInfoPath .\version-info.json -RootPath C:\dev\vcpkg
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$VersionInfoPath,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Extract a version from a manifest file using common vcpkg keys (or any key starting with "version")
function Get-VersionFromManifest {
    param(
        [Parameter(Mandatory=$true)]
        [psobject]$Manifest,
        [string[]]$CandidateKeys = @('version', 'version-semver', 'version-string', 'version-date')
    )

    # Try known version keys first
    foreach ($k in $CandidateKeys) {
        if ($Manifest.PSObject.Properties.Name -contains $k) {
            $val = $Manifest.$k
            if ($null -ne $val -and "$val".Trim()) {
                return "$val"
            }
        }
    }

    # Fallback pattern: any property starting with "version" except "port-version"
    $props = $Manifest.PSObject.Properties.Name | Where-Object {
        $_ -like 'version*' -and $_ -ne 'port-version'
    }
    foreach ($p in $props) {
        $val = $Manifest.$p
        if ($null -ne $val -and "$val".Trim()) {
            return "$val"
        }
    }

    return $null
}

# --- Load version-info.json ---
if (-not (Test-Path -LiteralPath $VersionInfoPath)) {
    throw "version-info.json not found at: $VersionInfoPath"
}

try {
    $versionInfoRaw = Get-Content -LiteralPath $VersionInfoPath -Raw -Encoding UTF8
    # PS 5.1 compatibility: ConvertFrom-Json has no -Depth parameter
    $versionInfo = $versionInfoRaw | ConvertFrom-Json
} catch {
    throw "Failed to parse JSON from $VersionInfoPath. $_"
}

if ($null -eq $versionInfo.files -or $versionInfo.files.Count -eq 0) {
    Write-Warning "No 'files' array found in $VersionInfoPath. Nothing to do."
    return
}


#--- Single pass: validate + update ---
$updatedCount = 0
foreach ($f in $versionInfo.files) {

    # StrictMode-safe guard — skip entries without versionSource
    if (-not ($f.PSObject.Properties.Name -contains 'versionSource') -or
        [string]::IsNullOrWhiteSpace($f.versionSource)) {
        continue
    }

    $fullPath = Join-Path -Path $RootPath -ChildPath $f.versionSource

    # Validate existence (throws early, before any write happens)
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "Missing versionSource file for [$($f.filename)]: $fullPath"
    }

    # Read manifest
    try {
        $manifestText = Get-Content -LiteralPath $fullPath -Raw -Encoding UTF8
        $manifest = $manifestText | ConvertFrom-Json   # PS5‑compatible
    } catch {
        throw "Failed to parse manifest JSON at $fullPath. $_"
    }

    # Extract version
    $ver = Get-VersionFromManifest -Manifest $manifest
    if (-not $ver) {
        throw "No usable version field found in manifest: $fullPath"
    }

    # Update fields
    $f.fileVersion = $ver
    $f.productVersion = $ver
    $updatedCount++
}

# --- Write output JSON (UTF-8 without BOM) ---
try {
    # Minimal change for Windows PowerShell 5.1: depth cannot exceed 100
    $outJson = $versionInfo | ConvertTo-Json -Depth 100
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($VersionInfoPath, $outJson, $utf8NoBom)

    Write-Host "Success: updated $updatedCount entries and wrote to $VersionInfoPath"
} catch {
    throw "Failed to write updated version-info.json. $_"
}