param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath
)

Import-Module "$PSScriptRoot/../../ps-modules/Build" -DisableNameChecking

if (-not (Get-IsOnMacOS)) {
    exit
}
Remove-DylibSymlinks -BuildArtifactsPath $BuildArtifactsPath
