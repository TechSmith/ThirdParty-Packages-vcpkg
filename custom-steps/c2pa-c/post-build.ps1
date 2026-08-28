param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$false)][string]$PackageAndFeatures,
    [Parameter(Mandatory=$false)][string]$LinkType,
    [Parameter(Mandatory=$false)][string]$BuildType,
    [Parameter(Mandatory=$false)][string]$ModulesRoot,
    [Parameter(Mandatory=$false)][string[]]$Triplets
)

$headerPath = Join-Path $BuildArtifactsPath "include/c2pa.h"
if(-not (Test-Path $headerPath -PathType Leaf)) {
    throw "Missing c2pa-c header: $headerPath"
}

if($IsWindows) {
    $dllPath = Join-Path $BuildArtifactsPath "bin/c2pa_c.dll"
    $importLibraryPath = Join-Path $BuildArtifactsPath "lib/c2pa_c.dll.lib"
    if(-not (Test-Path $dllPath -PathType Leaf)) {
        throw "Missing c2pa-c DLL: $dllPath"
    }
    if(-not (Test-Path $importLibraryPath -PathType Leaf)) {
        throw "Missing c2pa-c import library: $importLibraryPath"
    }

    $moduleName = "Build"
    if(-not (Get-Module -Name $moduleName)) {
        Import-Module "$ModulesRoot/$moduleName" -Force -DisableNameChecking
    }
    Update-VersionInfoForDlls -buildArtifactsPath $BuildArtifactsPath -versionInfoJsonPath "$PSScriptRoot/version-info.json"
}
elseif($IsMacOS) {
    $dylibPath = Join-Path $BuildArtifactsPath "lib/libc2pa_c.dylib"
    if(-not (Test-Path $dylibPath -PathType Leaf)) {
        throw "Missing c2pa-c dylib: $dylibPath"
    }

    $architectures = & lipo -archs $dylibPath
    if($LASTEXITCODE -ne 0 -or $architectures -notmatch "arm64" -or $architectures -notmatch "x86_64") {
        throw "Expected a universal c2pa-c dylib, found architectures: $architectures"
    }
}
