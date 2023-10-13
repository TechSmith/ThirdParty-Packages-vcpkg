Import-Module "$PSScriptRoot/../../ps-modules/Build" -DisableNameChecking

if (-not (Get-IsOnMacOS)) {
    exit
}
Write-Message "Installing nasm..."
brew install nasm
