Import-Module "$PSScriptRoot/../../ps-modules/Build" -DisableNameChecking

if (-not (Get-IsOnMacOS)) {
    exit
}
Write-Message "Installing setuptools..."
python3 -m pip install setuptools
