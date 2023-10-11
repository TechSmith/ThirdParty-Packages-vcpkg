# This script is here just for testing purposes
param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath
)

Import-Module "$PSScriptRoot/../../ps-modules/Build" -DisableNameChecking

Write-Message "Test: Running post-build script..."
if (-not (Get-IsOnMacOS)) {
    Write-Message "> Running on Windows!"
    exit
}
Write-Message "> Running on Mac!"
