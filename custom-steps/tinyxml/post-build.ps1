# This script is here just for testing purposes
param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath,
    [Parameter(Mandatory=$false)][string]$PortAndFeatures,
    [Parameter(Mandatory=$false)][string]$LinkType,
    [Parameter(Mandatory=$false)][string]$BuildType,
    [Parameter(Mandatory=$false)][string]$ModulesRoot,
    [Parameter(Mandatory=$false)][string[]]$Triplets
)

$moduleName = "Build"
if(-not (Get-Module -Name $moduleName)) {
    Import-Module "$ModulesRoot/$moduleName" -Force -DisableNameChecking
}

Write-Message "Test: Running post-build script..."
if (-not (Get-IsOnMacOS)) {
    Write-Message "> Running on Windows!"
    exit
}
Write-Message "> Running on Mac!"
