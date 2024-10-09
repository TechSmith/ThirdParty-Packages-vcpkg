Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

if (Get-IsOnMacOS) {
    Write-Message "Installing nasm..."
    brew install nasm
}

if (Get-IsOnLinux) {
    Write-Message "Verifying required packages are installed..."

    $isClangMissing = -not(dpkg-query -W -f='${Status}' clang 2>/dev/null | Select-String "install ok installed");
    $isPkgConfigMissing = -not(dpkg-query -W -f='${Status}' pkg-config 2>/dev/null | Select-String "install ok installed");
    $isNasmMissing = -not(dpkg-query -W -f='${Status}' nasm 2>/dev/null | Select-String "install ok installed");

    if ($isClangMissing -or $isPkgConfigMissing -or $isNasmMissing) {
        sudo apt-get update
    }

    if ($isClangMissing) {
        sudo apt-get install -y clang
    }

    if ($isPkgConfigMissing) {
        sudo apt-get install -y pkg-config
    }

    if ($isNasmMissing) {
        sudo apt-get install -y nasm
    }
}
