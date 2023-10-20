param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath
)

Import-Module "$PSScriptRoot/../../ps-modules/Build" -DisableNameChecking -Force

if (-not (Get-IsOnWindowsOS)) {
    exit
}
Update-VersionInfoForDlls -buildArtifactsPath $buildArtifactsPath -versionInfoJsonPath "$PSScriptRoot/version-info.json"
