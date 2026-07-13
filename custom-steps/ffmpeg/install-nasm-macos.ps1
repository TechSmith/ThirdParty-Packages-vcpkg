Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

if (-not (Get-IsOnMacOS)) {
    return
}

if (-not (Get-Command brew -ErrorAction SilentlyContinue)) {
    throw "Homebrew is required to install nasm on macOS, but 'brew' was not found on PATH."
}

$isNasmInstalled = (Get-Command nasm -ErrorAction SilentlyContinue) -ne $null
if ($isNasmInstalled) {
    Write-Message "nasm already installed."
    return
}

Write-Message "Installing nasm..."
brew install nasm
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install nasm via Homebrew."
}
