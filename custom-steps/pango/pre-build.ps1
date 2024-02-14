Import-Module "$PSScriptRoot/../../ps-modules/Build" -DisableNameChecking

if ((Get-IsOnMacOS)) {
	brew uninstall --ignore-dependencies python
	brew install python@3.11
	brew link --overwrite python@3.11
}
