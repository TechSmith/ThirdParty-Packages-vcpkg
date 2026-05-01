Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

if (-not (Get-IsOnMacOS)) {
    exit
}

Write-Message "Installing nasm..."
brew install nasm

# Fix nasm multipass optimization detection in aom's CMake.
# nasm 3.x changed its help output format so `-hf` no longer shows `-Ox`.
# This patch makes aom use `-hO` to check for multipass support instead.
Write-Message "Applying aom nasm multipass fix..."
$portDir = "vcpkg/ports/aom"
if (Test-Path $portDir) {
    Copy-Item "$PSScriptRoot/aom-port-patches/1001-tsc-aom-fix-nasm-multipass-check.patch" "$portDir/"
    $patchSuccess = Apply-VcpkgPortPatch -PortName "aom" -PatchFile "$PSScriptRoot/add-aom-port-patch.patch"
    if (-not $patchSuccess) {
        Write-Message "WARNING: Failed to apply aom portfile patch" -Error
    }
} else {
    Write-Message "WARNING: aom port directory not found, skipping nasm patch"
}
