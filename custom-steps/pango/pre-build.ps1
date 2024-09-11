Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

if ((Get-IsOnMacOS)) {
    Write-Message "Installing setuptools..."
    python3 -m pip install setuptools
}
