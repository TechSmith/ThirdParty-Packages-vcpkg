Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

if ((Get-IsOnMacOS)) {
	brew install autoconf automake autoconf-archive
}
