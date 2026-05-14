Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

# Enable tint header installation (all platforms).
# The upstream dawn port sets TINT_ENABLE_INSTALL=OFF; we need it ON so that
# tint public headers are installed alongside dawn.
Write-Message "Enabling TINT_ENABLE_INSTALL in dawn portfile..."
$patchFile = "$PSScriptRoot/1003-tsc-enable-tint-install.patch"
if (-not (Apply-VcpkgPortPatch -PortName "dawn" -PatchFile $patchFile)) {
    Write-Message "FATAL: Failed to apply tint install patch" -Error
    exit 1
}

if (-not (Get-IsOnMacOS)) {
    exit
}

# Fix Apple Clang CTAD issue with the `overloaded` helper struct in Tint.
# Apple Clang does not support implicit CTAD for aggregates (C++20 P1816R0),
# so we add an explicit deduction guide.
Write-Message "Applying dawn overloaded CTAD fix for macOS..."
$portDir = "vcpkg/ports/dawn"
$portfile = "$portDir/portfile.cmake"
if (Test-Path $portfile) {
    # Copy the source patch into the port directory
    Copy-Item "$PSScriptRoot/dawn-port-patches/1002-tsc-fix-overloaded-ctad-macos.patch" "$portDir/"

    # Directly insert our patch reference into the portfile's PATCHES list.
    # We avoid Apply-VcpkgPortPatch because its --inaccurate-eof flag strips
    # trailing newlines, merging the closing ')' with the next line.
    $content = Get-Content $portfile -Raw
    $anchor = "012-fix-non-target-leaking.patch"
    $insertion = @"
        012-fix-non-target-leaking.patch
        # Apple Clang does not support implicit CTAD for aggregates (P1816R0/P1021R4).
        # Add explicit deduction guide for the ``overloaded`` helper struct.
        1002-tsc-fix-overloaded-ctad-macos.patch
"@
    $newContent = $content.Replace("        $anchor", $insertion)
    if ($newContent -eq $content) {
        Write-Message "WARNING: Could not find anchor line '$anchor' in portfile.cmake" -Error
    } else {
        Set-Content -Path $portfile -Value $newContent -NoNewline
        Write-Message "Successfully patched portfile.cmake to include CTAD fix"
    }
} else {
    Write-Message "WARNING: dawn port directory not found, skipping CTAD patch"
}
