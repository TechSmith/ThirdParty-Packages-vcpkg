Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

# Apply patch to vcpkg's pango portfile to add Objective-C language support for macOS
Write-Message "Applying TechSmith patches to vcpkg pango port..."
$patchSuccess = Apply-VcpkgPortPatch -PortName "pango" -PatchFile "$PSScriptRoot/add-objc-language-support.patch"
if (-not $patchSuccess) {
    Write-Message "FATAL: Failed to apply patch to pango port" -Error
    exit 1
}

if ((Get-IsOnMacOS)) {
    Write-Message "Installing setuptools..."
    python3 -m pip install setuptools
}

