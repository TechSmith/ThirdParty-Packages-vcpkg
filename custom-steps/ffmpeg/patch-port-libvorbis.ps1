Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

# ── libvorbis: add Windows .rc version resources so vorbis.dll, vorbisenc.dll,
# and vorbisfile.dll embed their correct libtool interface versions:
#   vorbis.dll     -> 0.4.9   (V_LIB:  current=4, age=4, revision=9)
#   vorbisenc.dll  -> 2.0.12  (VE_LIB: current=2, age=0, revision=12)
#   vorbisfile.dll -> 3.3.8   (VF_LIB: current=6, age=3, revision=8)
# Without this patch the CMake build produces no version resources on Windows,
# causing update-version-info-json.ps1 to fall back to the port version (1.3.7)
# for all three DLLs.
$supportedLibvorbisVersion = "1.3.7"
$libvorbisPortDir = "vcpkg/ports/libvorbis"
$libvorbisVcpkgJson = "$libvorbisPortDir/vcpkg.json"
if (Test-Path $libvorbisVcpkgJson) {
    $libvorbisVersion = (Get-Content $libvorbisVcpkgJson -Raw | ConvertFrom-Json).version
    if ($libvorbisVersion -eq $supportedLibvorbisVersion) {
        Write-Message "Applying libvorbis Windows version resource patch (v$supportedLibvorbisVersion)..."
        Copy-Item "$PSScriptRoot/libvorbis-port-patches/1001-tsc-libvorbis-add-windows-version-resources.patch" "$libvorbisPortDir/"
        $patchSuccess = Apply-VcpkgPortPatch -PortName "libvorbis" -PatchFile "$PSScriptRoot/add-libvorbis-port-patch.patch"
        if (-not $patchSuccess) {
            Write-Message "WARNING: Failed to apply libvorbis portfile patch" -Error
        }
    }
    else {
        Write-Message "libvorbis version is '$libvorbisVersion' (not $supportedLibvorbisVersion), skipping version resource patch"
    }
}
else {
    Write-Message "WARNING: libvorbis port directory not found, skipping version resource patch"
}
