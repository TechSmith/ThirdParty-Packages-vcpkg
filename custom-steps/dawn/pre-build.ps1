Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

# Copy the macOS CTAD fix patch into the dawn port directory so it can be referenced by the portfile
Write-Message "Copying dawn source patches to port directory..."
$portDir = "vcpkg/ports/dawn"
if (Test-Path $portDir) {
    Copy-Item "$PSScriptRoot/dawn-port-patches/1001-tsc-fix-overloaded-ctad-macos.patch" "$portDir/"
} else {
    Write-Message "WARNING: dawn port directory not found at $portDir" -Error
}

# Apply the combined portfile customizations patch that:
# 1. Adds reference to the macOS CTAD fix patch (1002-tsc-fix-overloaded-ctad-macos.patch)
# 2. Installs tint headers manually (since upstream TINT_ENABLE_INSTALL=ON is broken)
Write-Message "Applying dawn portfile customizations..."
$patchFile = "$PSScriptRoot/tsc-dawn-portfile-customizations.patch"
if (-not (Apply-VcpkgPortPatch -PortName "dawn" -PatchFile $patchFile)) {
    Write-Message "FATAL: Failed to apply dawn customizations patch" -Error
    exit 1
}
