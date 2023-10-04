Import-Module "$PSScriptRoot/../../ps-modules/Util"

$IsOnMacOS = Get-IsOnMacOS

if(-not $IsOnMacOS) {
    Write-Host "Not on Mac OS.  Exiting..."
    exit
}

Write-Host "Running pre-build script..."
