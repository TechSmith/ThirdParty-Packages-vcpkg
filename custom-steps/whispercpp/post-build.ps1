param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$false)][string]$PackageAndFeatures,
    [Parameter(Mandatory=$false)][string]$LinkType,
    [Parameter(Mandatory=$false)][string]$BuildType
)

if ((Get-IsOnWindowsOS)) {
    Update-VersionInfoForDlls -buildArtifactsPath $buildArtifactsPath -versionInfoJsonPath "$PSScriptRoot/version-info.json"
}