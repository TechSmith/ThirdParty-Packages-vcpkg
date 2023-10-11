param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath
)

Import-Module "$PSScriptRoot/../../ps-modules/Build" -DisableNameChecking

$IsOnMacOS = Get-IsOnMacOS

if(-not $IsOnMacOS) {
    Write-Host "The step is only required for MacOS.  Skipping step..."
    exit
}

Write-Host "Running post-build script..."