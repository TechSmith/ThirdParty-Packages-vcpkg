Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

# Apply patch to vcpkg's pango portfile to add Objective-C language support for macOS
Write-Message "Applying TechSmith patches to vcpkg pango port..."
$patchSuccess = Apply-VcpkgPortPatch -PortName "pango" -PatchFile "$PSScriptRoot/add-objc-language-support.patch"
if (-not $patchSuccess) {
    Write-Message "FATAL: Failed to apply patch to pango port" -Error
    exit 1
}

if ((Get-IsOnMacOS)) {
    Write-Message "Installing build tools via Homebrew..."
    
    # Install build tool prerequisites: autoconf, autoconf-archive, automake, and libtool
    # On the Mac, there is not a clean way to do this with vcpkg.json like there is on Windows.
    # The  dependency tree for these tools is somewhat circular and complex on Mac/Linux, and the 
    # vcpkg maintainers have decided to just assume these tools exist on these environments rather
    # than building them.  See: https://github.com/microsoft/vcpkg/issues/34723#issuecomment-1824852084
    brew install autoconf autoconf-archive automake libtool
    
    Write-Message "Installing setuptools..."
    python3 -m pip install setuptools
}

