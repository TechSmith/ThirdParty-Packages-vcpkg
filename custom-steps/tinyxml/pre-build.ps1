# This script is here just for testing purposes
Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

Write-Message "Test: Running pre-build script..."
if (-not (Get-IsOnMacOS)) {
    Write-Message "> Running on Windows!"
    exit
}
Write-Message "> Running on Mac!"
