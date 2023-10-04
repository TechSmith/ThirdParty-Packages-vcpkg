param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath
)

Import-Module "$PSScriptRoot/../../ps-modules/Util"

$IsOnMacOS = Get-IsOnMacOS

if(-not $IsOnMacOS) {
    Write-Host "Not on Mac OS.  Exiting..."
    exit
}

Import-Module "$PSScriptRoot/../../ps-modules/MacUtil"

Write-Host "Running post-build script..."
Push-Location "$BuildArtifactsPath/lib"

Remove-Symlinks -BuildArtifactsPath $BuildArtifactsPath