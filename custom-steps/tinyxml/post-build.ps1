# This script is here just for testing purposes
param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$false)][string]$PackageAndFeatures,
    [Parameter(Mandatory=$false)][string]$LinkType,
    [Parameter(Mandatory=$false)][string]$BuildType
)

Write-Message "Test: Running post-build script..."
if (-not (Get-IsOnMacOS)) {
    Write-Message "> Running on Windows!"
    exit
}
Write-Message "> Running on Mac!"
