Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

# ── mp3lame: fix version string so DLL embeds "3.100.2" instead of "3.100"
# LAME 3.100 has LAME_TYPE_VERSION=2 (release) and LAME_PATCH_VERSION=0,
# which causes LAME_PATCH_LEVEL_STRING to be "" and the version string to be
# "3.100". We patch version.h to always include LAME_TYPE_VERSION as a third
# dotted part so the embedded string becomes "3.100.2".
$mp3lamePortDir = "vcpkg/ports/mp3lame"
$mp3lameVcpkgJson = "$mp3lamePortDir/vcpkg.json"
$supportedMp3lameVersion = "3.100"
if (Test-Path $mp3lameVcpkgJson) {
    $mp3lameVersion = (Get-Content $mp3lameVcpkgJson -Raw | ConvertFrom-Json).version
    if ($mp3lameVersion -eq $supportedMp3lameVersion) {
        Write-Message "Applying mp3lame version string fix ($supportedMp3lameVersion -> 3.100.2)..."
        Copy-Item "$PSScriptRoot/mp3lame-port-patches/1001-tsc-mp3lame-fix-version-string.patch" "$mp3lamePortDir/"
        $patchSuccess = Apply-VcpkgPortPatch -PortName "mp3lame" -PatchFile "$PSScriptRoot/add-mp3lame-port-patch.patch"
        if (-not $patchSuccess) {
            Write-Message "WARNING: Failed to apply mp3lame portfile patch" -Error
        }
    }
    else {
        Write-Message "mp3lame version is '$mp3lameVersion' (not $supportedMp3lameVersion), skipping version string patch"
    }
}
else {
    Write-Message "WARNING: mp3lame port directory not found, skipping version string patch"
}
