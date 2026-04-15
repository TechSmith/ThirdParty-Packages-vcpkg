<#
.SYNOPSIS
  Creates a version-info.json file from DLL files in a directory.

.DESCRIPTION
  Scans all DLL files in the input directory, extracts their version information,
  and creates a version-info.json file. Automatically enriches metadata by reading
  vcpkg's package installation metadata (the *.list files in vcpkg/installed/vcpkg/info)
  to map DLLs to their source ports, then extracting descriptions, versions, product names,
  and copyright information from vcpkg.json and copyright files.

.PARAMETER InputDllDir
  Path to the directory containing DLL files to scan.

.PARAMETER OutputJsonFile
  Path where the version-info.json file will be created.

.PARAMETER VcpkgRoot
  Optional. Path to the vcpkg root directory. If specified, the script will automatically
  enrich DLL metadata from vcpkg sources.

.PARAMETER Triplet
  Optional. The vcpkg triplet used to build the package (e.g., x64-windows-dynamic-release).
  If not specified, the script will attempt to auto-detect it from the vcpkg/installed directory.

.EXAMPLE
  .\create-version-info.json.ps1 -InputDllDir .\bin -OutputJsonFile .\version-info.json

.EXAMPLE
  .\create-version-info.json.ps1 -InputDllDir .\bin -OutputJsonFile .\version-info.json -VcpkgRoot D:\vcpkg -Triplet x64-windows-dynamic-release
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$InputDllDir,

    [Parameter(Mandatory=$true)]
    [string]$OutputJsonFile,

    [Parameter(Mandatory=$false)]
    [string]$VcpkgRoot,
    
    [Parameter(Mandatory=$false)]
    [string]$Triplet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Replace-NullWithEmptyString {
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$object
    )

    $object.PSObject.Properties | ForEach-Object {
        if ($_.Value -eq $null) {
            $_.Value = ""
        }
    }
    return $object
}

function Normalize-VersionNumber {
    param (
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Version
    )
    
    if ([string]::IsNullOrWhiteSpace($Version)) {
        return $Version
    }
    
    # Split version by dots
    $parts = $Version -split '\.'
    
    # If there are 4 parts, remove the 4th part
    if ($parts.Count -eq 4) {
        return ($parts[0..2] -join '.')
    }
    
    return $Version
}

function Get-PortMetadata {
    param (
        [Parameter(Mandatory=$true)]
        [string]$PortName,
        
        [Parameter(Mandatory=$true)]
        [string]$VcpkgRoot,
        
        [Parameter(Mandatory=$true)]
        [string]$CustomPortsDir,
        
        [Parameter(Mandatory=$true)]
        [string]$Triplet
    )
    
    $metadata = @{
        description = $null
        productName = $null
        copyright = $null
        version = $null
    }
    
    # Try to read vcpkg.json from custom-ports first, then vcpkg/ports
    $vcpkgJsonPath = Join-Path $CustomPortsDir "$PortName/vcpkg.json"
    if (-not (Test-Path $vcpkgJsonPath)) {
        $vcpkgJsonPath = Join-Path $VcpkgRoot "ports/$PortName/vcpkg.json"
    }
    
    if (Test-Path $vcpkgJsonPath) {
        try {
            $portJson = Get-Content $vcpkgJsonPath -Raw | ConvertFrom-Json
            
            # Use description for fileDescription
            if ($portJson.PSObject.Properties.Name -contains 'description' -and $portJson.description) {
                # Handle array descriptions (join them into a single line)
                if ($portJson.description -is [Array]) {
                    $metadata.description = $portJson.description -join ' '
                } else {
                    $metadata.description = $portJson.description
                }
            }
            
            # Extract version (check version, version-semver, version-string)
            if ($portJson.PSObject.Properties.Name -contains 'version' -and $portJson.version) {
                $metadata.version = $portJson.version
            } elseif ($portJson.PSObject.Properties.Name -contains 'version-semver' -and $portJson.'version-semver') {
                $metadata.version = $portJson.'version-semver'
            } elseif ($portJson.PSObject.Properties.Name -contains 'version-string' -and $portJson.'version-string') {
                $metadata.version = $portJson.'version-string'
            }
            
            # Try to extract a product name from the port name or description
            # Capitalize the port name as a fallback
            $metadata.productName = (Get-Culture).TextInfo.ToTitleCase($PortName)
            
        } catch {
            Write-Verbose "Could not parse vcpkg.json for port: $PortName"
        }
    }
    
    # Try to read copyright file from share/<portname>/copyright
    $copyrightPath = Join-Path $VcpkgRoot "installed/$Triplet/share/$PortName/copyright"
    if (Test-Path $copyrightPath) {
        try {
            $copyrightContent = Get-Content $copyrightPath -Raw -ErrorAction SilentlyContinue
            
            # Try to extract copyright line - look for copyright markers in priority order
            # Priority: 1) "Copyright (c)" 2) "Copyright ©" 3) "(C)" or "(c)" 4) "©" 5) "Copyright "
            $copyrightLine = $null
            
            # Try to find "Copyright (c)" first (highest priority, case insensitive)
            if ($copyrightContent -match '(?i)Copyright\s+\([Cc]\)\s*[0-9]') {
                $match = [regex]::Match($copyrightContent, '(?i)Copyright\s+\([Cc]\)', [System.Text.RegularExpressions.RegexOptions]::None)
                if ($match.Success) {
                    $startIndex = $match.Index
                    # Extract from "Copyright (c)" to the first period, CR, or LF
                    $remaining = $copyrightContent.Substring($startIndex)
                    if ($remaining -match '(?i)^(Copyright\s+\([Cc]\)[^\r\n\.]+)') {
                        $copyrightLine = $matches[1].Trim()
                    }
                }
            }
            # Try to find "Copyright ©" next
            elseif ($copyrightContent -match '(?i)Copyright\s+©\s*[0-9]') {
                $match = [regex]::Match($copyrightContent, '(?i)Copyright\s+©', [System.Text.RegularExpressions.RegexOptions]::None)
                if ($match.Success) {
                    $startIndex = $match.Index
                    # Extract from "Copyright ©" to the first period, CR, or LF
                    $remaining = $copyrightContent.Substring($startIndex)
                    if ($remaining -match '(?i)^(Copyright\s+©[^\r\n\.]+)') {
                        $copyrightLine = $matches[1].Trim()
                    }
                }
            }
            # Try to find "(C)" or "(c)" (case insensitive)
            elseif ($copyrightContent -match '(?i)\([Cc]\)\s*[0-9]') {
                $startIndex = $copyrightContent.IndexOf('(C)', [System.StringComparison]::OrdinalIgnoreCase)
                if ($startIndex -ge 0) {
                    # Extract from (C) to the first period, CR, or LF
                    $remaining = $copyrightContent.Substring($startIndex)
                    if ($remaining -match '(?i)^(\([Cc]\)[^\r\n\.]+)') {
                        $copyrightLine = $matches[1].Trim()
                    }
                }
            }
            # Try to find "©" 
            elseif ($copyrightContent -match '©\s*[0-9]') {
                $startIndex = $copyrightContent.IndexOf('©')
                if ($startIndex -ge 0) {
                    # Extract from © to the first period, CR, or LF
                    $remaining = $copyrightContent.Substring($startIndex)
                    if ($remaining -match '^(©[^\r\n\.]+)') {
                        $copyrightLine = $matches[1].Trim()
                    }
                }
            }
            # Finally try "Copyright " (case insensitive)
            elseif ($copyrightContent -match '(?i)Copyright\s+[0-9©\(]') {
                if ($copyrightContent -match '(?i)(Copyright[^\r\n\.]+)') {
                    $copyrightLine = $matches[1].Trim()
                }
            }
            
            if ($copyrightLine) {
                # Clean up the copyright line - limit length
                if ($copyrightLine.Length -gt 200) {
                    $copyrightLine = $copyrightLine.Substring(0, 197) + "..."
                }
                $metadata.copyright = $copyrightLine
            }
            
        } catch {
            Write-Verbose "Could not parse copyright file for port: $PortName"
        }
    }
    
    return $metadata
}

function Build-DllToPortMapping {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VcpkgRoot,
        
        [Parameter(Mandatory=$true)]
        [string]$Triplet
    )

    $mapping = @{}
    $infoPath = Join-Path $VcpkgRoot "installed/vcpkg/info"
    
    if (-not (Test-Path $infoPath)) {
        Write-Warning "vcpkg info directory not found: $infoPath"
        Write-Warning "Make sure you've built the package first using vcpkg."
        return $mapping
    }
    
    # Get all .list files for this triplet
    $listFiles = Get-ChildItem -Path $infoPath -Filter "*_$Triplet.list" -ErrorAction SilentlyContinue
    
    if ($listFiles.Count -eq 0) {
        Write-Warning "No package list files found for triplet: $Triplet"
        Write-Warning "Available list files:"
        Get-ChildItem -Path $infoPath -Filter "*.list" | ForEach-Object { Write-Warning "  $($_.Name)" }
        return $mapping
    }
    
    foreach ($listFile in $listFiles) {
        # Extract port name from filename (e.g., "zlib_1.3.2_x64-windows-dynamic-release.list" -> "zlib")
        if ($listFile.Name -match '^([^_]+)_') {
            $portName = $matches[1]
            
            # Read the file and find all DLL entries
            $content = Get-Content $listFile.FullName -ErrorAction SilentlyContinue
            foreach ($line in $content) {
                # Look for lines like "x64-windows-dynamic-release/bin/z.dll"
                if ($line -match "^$Triplet/bin/([^/]+\.dll)$") {
                    $dllName = $matches[1]
                    $mapping[$dllName] = $portName
                    Write-Verbose "Mapped: $dllName -> $portName (from $($listFile.Name))"
                }
            }
        }
    }
    
    Write-Verbose "Built DLL-to-port mapping with $($mapping.Count) entries for triplet: $Triplet"
    return $mapping
}

function Find-VcpkgPortForDll {
    param (
        [Parameter(Mandatory=$true)]
        [string]$DllName,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$DllToPortMapping
    )

    if ($DllToPortMapping.ContainsKey($DllName)) {
        $portName = $DllToPortMapping[$DllName]
        Write-Verbose "Found port for $DllName -> $portName (from vcpkg metadata)"
        return "ports/$portName/vcpkg.json"
    }

    Write-Verbose "No port found for $DllName in vcpkg metadata"
    return $null
}

# Validate input directory
if (-not (Test-Path -LiteralPath $InputDllDir -PathType Container)) {
    Write-Error "Input directory not found: $InputDllDir"
    exit 1
}

# Determine paths
$scriptRoot = $PSScriptRoot
$repoRoot = Split-Path (Split-Path $scriptRoot -Parent) -Parent
$customPortsDir = Join-Path $repoRoot "custom-ports"

# Check if output file already exists and read buildNumber if present
$buildNumber = 100  # Default starting value
if (Test-Path -LiteralPath $OutputJsonFile -PathType Leaf) {
    try {
        $existingContent = Get-Content -LiteralPath $OutputJsonFile -Raw -Encoding UTF8
        $existingJson = $existingContent | ConvertFrom-Json
        if ($existingJson.PSObject.Properties.Name -contains 'buildNumber' -and $existingJson.buildNumber) {
            $buildNumber = [int]$existingJson.buildNumber + 1
            Write-Host "Existing version-info.json found. Incrementing buildNumber: $($buildNumber - 1) -> $buildNumber" -ForegroundColor Cyan
        }
    } catch {
        Write-Warning "Could not read existing buildNumber from $OutputJsonFile. Using default: $buildNumber"
    }
}

# Default VcpkgRoot if not specified
if ([string]::IsNullOrWhiteSpace($VcpkgRoot)) {
    $defaultVcpkgRoot = Join-Path $repoRoot "vcpkg"
    if (Test-Path $defaultVcpkgRoot) {
        $VcpkgRoot = $defaultVcpkgRoot
        Write-Host "Using vcpkg root: $VcpkgRoot" -ForegroundColor Gray
    }
}

$useVcpkgDetection = -not [string]::IsNullOrWhiteSpace($VcpkgRoot) -and (Test-Path $VcpkgRoot)

# Auto-detect triplet if not specified
if ($useVcpkgDetection -and [string]::IsNullOrWhiteSpace($Triplet)) {
    $installedPath = Join-Path $VcpkgRoot "installed"
    if (Test-Path $installedPath) {
        # Get all triplet directories (exclude "vcpkg" metadata directory)
        $tripletDirs = Get-ChildItem -Path $installedPath -Directory | 
            Where-Object { $_.Name -ne 'vcpkg' } |
            Select-Object -ExpandProperty Name
        
        if ($tripletDirs.Count -eq 1) {
            $Triplet = $tripletDirs[0]
            Write-Host "Auto-detected triplet: $Triplet" -ForegroundColor Gray
        } elseif ($tripletDirs.Count -gt 1) {
            Write-Warning "Multiple triplets found. Please specify -Triplet parameter."
            Write-Warning "Available triplets: $($tripletDirs -join ', ')"
            $useVcpkgDetection = $false
        }
    }
}

# Build DLL-to-port mapping from vcpkg metadata
$dllToPortMapping = @{}
if ($useVcpkgDetection -and -not [string]::IsNullOrWhiteSpace($Triplet)) {
    Write-Host "Building DLL-to-port mapping from vcpkg metadata..." -ForegroundColor Gray
    $dllToPortMapping = Build-DllToPortMapping -VcpkgRoot $VcpkgRoot -Triplet $Triplet
    
    if ($dllToPortMapping.Count -eq 0) {
        Write-Warning "Could not build DLL-to-port mapping. versionSource detection will be disabled."
        $useVcpkgDetection = $false
    } else {
        Write-Host "Found $($dllToPortMapping.Count) DLL(s) in vcpkg metadata" -ForegroundColor Gray
    }
}

Write-Host "Scanning DLLs in: $InputDllDir" -ForegroundColor Cyan
Write-Host ""

$filenamePrefix = "bin/"
$dllCount = 0
$detectedCount = 0

$results = @(Get-ChildItem -Path "$InputDllDir/" -Filter "*.dll" | ForEach-Object {
    $dllCount++
    $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($_.FullName)
    
    $dllInfo = [PSCustomObject]@{
        filename        = "$filenamePrefix$($_.Name)"
        fileDescription = $versionInfo.FileDescription
        fileVersion     = $versionInfo.FileVersion
        productName     = $versionInfo.ProductName
        productVersion  = $versionInfo.ProductVersion
        copyright       = $versionInfo.LegalCopyright
    }
    
    # Try to detect versionSource if VcpkgRoot is available
    if ($useVcpkgDetection) {
        $versionSource = Find-VcpkgPortForDll -DllName $_.Name -DllToPortMapping $dllToPortMapping
        if ($versionSource) {
            # Extract port name from versionSource path
            $portName = $versionSource -replace '^ports/([^/]+)/vcpkg\.json$', '$1'
            
            # Get metadata from vcpkg port
            $portMetadata = Get-PortMetadata -PortName $portName -VcpkgRoot $VcpkgRoot -CustomPortsDir $customPortsDir -Triplet $Triplet
            
            # Use port metadata to fill in missing fields from DLL
            $finalDescription = $dllInfo.fileDescription
            if ([string]::IsNullOrWhiteSpace($finalDescription) -and $portMetadata.description) {
                $finalDescription = $portMetadata.description
            }
            
            $finalProductName = $dllInfo.productName
            if ([string]::IsNullOrWhiteSpace($finalProductName) -and $portMetadata.productName) {
                $finalProductName = $portMetadata.productName
            }
            
            $finalCopyright = $dllInfo.copyright
            if ([string]::IsNullOrWhiteSpace($finalCopyright) -and $portMetadata.copyright) {
                $finalCopyright = $portMetadata.copyright
            }
            
            # Always use version from vcpkg.json (versionSource) if available
            # This ensures consistency with the port version, not what's embedded in the DLL
            $finalFileVersion = $portMetadata.version
            if ([string]::IsNullOrWhiteSpace($finalFileVersion)) {
                # Fallback to DLL metadata only if vcpkg.json doesn't have version
                $finalFileVersion = $dllInfo.fileVersion
            }
            
            # Normalize versions (strip 4th part if present)
            $finalFileVersion = Normalize-VersionNumber -Version $finalFileVersion
            
            $finalProductVersion = $portMetadata.version
            if ([string]::IsNullOrWhiteSpace($finalProductVersion)) {
                # Fallback to DLL metadata only if vcpkg.json doesn't have version
                $finalProductVersion = $dllInfo.productVersion
            }
            
            # Normalize versions (strip 4th part if present)
            $finalProductVersion = Normalize-VersionNumber -Version $finalProductVersion
            
            # Build the object conditionally including copyright
            $dllInfoEnriched = [ordered]@{
                filename        = $dllInfo.filename
                fileDescription = $finalDescription
                fileVersion     = $finalFileVersion
                productName     = $finalProductName
                productVersion  = $finalProductVersion
            }
            
            # Only add copyright if it's not empty
            if (-not [string]::IsNullOrWhiteSpace($finalCopyright)) {
                $dllInfoEnriched['copyright'] = $finalCopyright
            }
            
            $dllInfo = [PSCustomObject]$dllInfoEnriched
            $detectedCount++
            Write-Host "  ✓ $($_.Name) -> enriched from $versionSource" -ForegroundColor Green
        } else {
            Write-Host "  ? $($_.Name) -> (no port detected)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  • $($_.Name)" -ForegroundColor Gray
    }
    
    # For manual entries, also conditionally include copyright
    if (-not $useVcpkgDetection -or [string]::IsNullOrWhiteSpace($versionSource)) {
        if ([string]::IsNullOrWhiteSpace($dllInfo.copyright)) {
            # Rebuild without copyright field
            $dllInfoWithoutCopyright = [PSCustomObject]@{
                filename        = $dllInfo.filename
                fileDescription = $dllInfo.fileDescription
                fileVersion     = $dllInfo.fileVersion
                productName     = $dllInfo.productName
                productVersion  = $dllInfo.productVersion
            }
            $dllInfo = $dllInfoWithoutCopyright
        }
    }
    
    Replace-NullWithEmptyString -object $dllInfo
})

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Total DLLs: $dllCount" -ForegroundColor White

if ($useVcpkgDetection) {
    Write-Host "  Enriched from vcpkg: $detectedCount" -ForegroundColor Green
    Write-Host "  Manual review needed: $($dllCount - $detectedCount)" -ForegroundColor Yellow
}

$jsonOutput = @{
    buildNumber = $buildNumber
    files = $results
} | ConvertTo-Json -Depth 100

# Write with UTF-8 no BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutputJsonFile, $jsonOutput, $utf8NoBom)

Write-Host ""
Write-Host "Created: $OutputJsonFile" -ForegroundColor Cyan

if ($useVcpkgDetection -and $detectedCount -lt $dllCount) {
    Write-Host ""
    Write-Host "Note: Some DLLs could not be enriched from vcpkg metadata." -ForegroundColor Yellow
    Write-Host "This may be because the DLL was not built by vcpkg, or the package metadata is missing." -ForegroundColor Yellow
}


