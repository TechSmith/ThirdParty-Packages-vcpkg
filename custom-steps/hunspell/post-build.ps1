param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath
)

Import-Module "$PSScriptRoot/../../ps-modules/Build" -DisableNameChecking

if ((Get-IsOnMacOS)) {
    Remove-DylibSymlinks -BuildArtifactsPath $BuildArtifactsPath
}
elseif ((Get-IsOnWindowsOS)) {
    Update-VersionInfoForDlls -buildArtifactsPath $buildArtifactsPath -versionInfoJsonPath "$PSScriptRoot/version-info.json"
}