Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

if (Get-IsOnWindowsOS) {
    & "$PSScriptRoot/patch-port-mp3lame.ps1"
    & "$PSScriptRoot/patch-port-libvorbis.ps1"
}

if (Get-IsOnMacOS) {
    & "$PSScriptRoot/install-nasm-macos.ps1"
}
