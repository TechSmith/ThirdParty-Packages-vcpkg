param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath
)

. "$PSScriptRoot\..\..\util.ps1"

$IsOnMacOS = Check-IsOnMacOS

if(-not $IsOnMacOS) {
    Write-Host "Not on Mac OS.  Exiting..."
    exit
}

Write-Host "Running post-build script..."