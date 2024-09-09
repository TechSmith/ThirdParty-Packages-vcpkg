Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

if (-not (Get-IsOnMacOS)) {
    exit
}
Write-Message "Installing automake..."
brew install automake
