Import-Module "$PSScriptRoot/../../ps-modules/Build" -DisableNameChecking

if ((Get-IsOnMacOS)) {
	# python3 requires pkg-config and autoconf-archive: https://github.com/python/cpython/blob/3.11/configure.ac#L18
	$installPkgs = "automake", "pkg-config", "autoconf-archive"
	foreach( $pkg in $installPkgs ) {
		Write-Message "Installing $pkg..."
		brew install $pkg
	}
}
