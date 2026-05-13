Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

# ── macOS-only steps ────────────────────────────────────────────────────────
if (Get-IsOnMacOS) {
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
}

# ── Windows-only steps ──────────────────────────────────────────────────────
if (Get-IsOnWindowsOS) {

    # ── mp3lame: fix version string so DLL embeds "3.100.2" instead of "3.100"
    # LAME 3.100 has LAME_TYPE_VERSION=2 (release) and LAME_PATCH_VERSION=0,
    # which causes LAME_PATCH_LEVEL_STRING to be "" and the version string to be
    # "3.100". We patch version.h to always include LAME_TYPE_VERSION as a third
    # dotted part so the embedded string becomes "3.100.2".
    $mp3lamePortDir = "vcpkg/ports/mp3lame"
    $mp3lameVcpkgJson = "$mp3lamePortDir/vcpkg.json"
    if (Test-Path $mp3lameVcpkgJson) {
        $mp3lameVersion = (Get-Content $mp3lameVcpkgJson -Raw | ConvertFrom-Json).version
        if ($mp3lameVersion -eq "3.100") {
            Write-Message "Applying mp3lame version string fix (3.100 -> 3.100.2)..."
            Copy-Item "$PSScriptRoot/mp3lame-port-patches/1001-tsc-mp3lame-fix-version-string.patch" "$mp3lamePortDir/"
            $patchSuccess = Apply-VcpkgPortPatch -PortName "mp3lame" -PatchFile "$PSScriptRoot/add-mp3lame-port-patch.patch"
            if (-not $patchSuccess) {
                Write-Message "WARNING: Failed to apply mp3lame portfile patch" -Error
            }
        } else {
            Write-Message "mp3lame version is '$mp3lameVersion' (not 3.100), skipping version string patch"
        }
    } else {
        Write-Message "WARNING: mp3lame port directory not found, skipping version string patch"
    }

    # ── libvorbis: add Windows .rc version resources so vorbis.dll, vorbisenc.dll,
    # and vorbisfile.dll embed their correct libtool interface versions:
    #   vorbis.dll     -> 0.4.9   (V_LIB:  current=4, age=4, revision=9)
    #   vorbisenc.dll  -> 2.0.12  (VE_LIB: current=2, age=0, revision=12)
    #   vorbisfile.dll -> 3.3.8   (VF_LIB: current=6, age=3, revision=8)
    # Without this patch the CMake build produces no version resources on Windows,
    # causing update-version-info-json.ps1 to fall back to the port version (1.3.7)
    # for all three DLLs.
    $libvorbisPortDir = "vcpkg/ports/libvorbis"
    $libvorbisVcpkgJson = "$libvorbisPortDir/vcpkg.json"
    if (Test-Path $libvorbisVcpkgJson) {
        $libvorbisVersion = (Get-Content $libvorbisVcpkgJson -Raw | ConvertFrom-Json).version
        if ($libvorbisVersion -eq "1.3.7") {
            Write-Message "Applying libvorbis Windows version resource patch (v1.3.7)..."
            Copy-Item "$PSScriptRoot/libvorbis-port-patches/1001-tsc-libvorbis-add-windows-version-resources.patch" "$libvorbisPortDir/"
            $patchSuccess = Apply-VcpkgPortPatch -PortName "libvorbis" -PatchFile "$PSScriptRoot/add-libvorbis-port-patch.patch"
            if (-not $patchSuccess) {
                Write-Message "WARNING: Failed to apply libvorbis portfile patch" -Error
            }
        } else {
            Write-Message "libvorbis version is '$libvorbisVersion' (not 1.3.7), skipping version resource patch"
        }
    } else {
        Write-Message "WARNING: libvorbis port directory not found, skipping version resource patch"
    }
}
