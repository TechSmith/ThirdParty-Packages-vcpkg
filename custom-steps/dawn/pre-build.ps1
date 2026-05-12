Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

if (-not (Get-IsOnMacOS)) {
    exit
}

# Fix Apple Clang CTAD issue with the `overloaded` helper struct in Tint.
# Apple Clang does not support implicit CTAD for aggregates (C++20 P1816R0),
# so we add an explicit deduction guide.
Write-Message "Applying dawn overloaded CTAD fix for macOS..."
$portDir = "vcpkg/ports/dawn"
if (Test-Path $portDir) {
    Copy-Item "$PSScriptRoot/dawn-port-patches/1002-tsc-fix-overloaded-ctad-macos.patch" "$portDir/"
    $patchSuccess = Apply-VcpkgPortPatch -PortName "dawn" -PatchFile "$PSScriptRoot/add-dawn-port-patch.patch"
    if (-not $patchSuccess) {
        Write-Message "WARNING: Failed to apply dawn portfile patch" -Error
    }
} else {
    Write-Message "WARNING: dawn port directory not found, skipping CTAD patch"
}
