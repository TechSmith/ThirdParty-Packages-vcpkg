Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

# DEBUG: Environment diagnostics
Write-Message "=== DEBUG: Environment Diagnostics ==="
Write-Message "Git version: $(git --version)"
Write-Message "Git core.autocrlf: $(git config --get core.autocrlf)"
Write-Message "Git core.eol: $(git config --get core.eol)"
Write-Message "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Message "OS: $([System.Environment]::OSVersion.VersionString)"

# Copy the macOS CTAD fix patch into the dawn port directory so it can be referenced by the portfile
Write-Message "Copying dawn source patches to port directory..."
$portDir = "vcpkg/ports/dawn"
if (Test-Path $portDir) {
    Copy-Item "$PSScriptRoot/dawn-port-patches/1001-tsc-fix-overloaded-ctad-macos.patch" "$portDir/"
} else {
    Write-Message "WARNING: dawn port directory not found at $portDir" -Error
}

# DEBUG: Patch file diagnostics
Write-Message "=== DEBUG: Patch File Diagnostics ==="
$patchFile = "$PSScriptRoot/tsc-dawn-portfile-customizations.patch"
Write-Message "Patch file path: $patchFile"
Write-Message "Patch file exists: $(Test-Path $patchFile)"
$patchBytes = [System.IO.File]::ReadAllBytes($patchFile)
$crlfCount = 0
$lfOnlyCount = 0
for ($i = 0; $i -lt $patchBytes.Length - 1; $i++) {
    if ($patchBytes[$i] -eq 13 -and $patchBytes[$i+1] -eq 10) { $crlfCount++ }
    elseif ($patchBytes[$i] -eq 10 -and ($i -eq 0 -or $patchBytes[$i-1] -ne 13)) { $lfOnlyCount++ }
}
Write-Message "Patch file line endings: CRLF=$crlfCount, LF-only=$lfOnlyCount"

# DEBUG: Portfile diagnostics before patch
Write-Message "=== DEBUG: Portfile Before Patch ==="
$portfilePath = "vcpkg/ports/dawn/portfile.cmake"
$portfileLines = Get-Content $portfilePath
Write-Message "Line 59: $($portfileLines[58])"
Write-Message "Line 60: $($portfileLines[59])"
Write-Message "Line 61: $($portfileLines[60])"
Write-Message "Line 62: $($portfileLines[61])"
Write-Message "Line 63: $($portfileLines[62])"

# Apply the combined portfile customizations patch that:
# 1. Adds reference to the macOS CTAD fix patch (1002-tsc-fix-overloaded-ctad-macos.patch)
# 2. Installs tint headers manually (since upstream TINT_ENABLE_INSTALL=ON is broken)
Write-Message "Applying dawn portfile customizations..."
if (-not (Apply-VcpkgPortPatch -PortName "dawn" -PatchFile $patchFile)) {
    Write-Message "FATAL: Failed to apply dawn customizations patch" -Error
    exit 1
}

# DEBUG: Portfile diagnostics after patch
Write-Message "=== DEBUG: Portfile After Patch ==="
$portfileLines = Get-Content $portfilePath
Write-Message "Line 59: $($portfileLines[58])"
Write-Message "Line 60: $($portfileLines[59])"
Write-Message "Line 61: $($portfileLines[60])"
Write-Message "Line 62: $($portfileLines[61])"
Write-Message "Line 63: $($portfileLines[62])"
Write-Message "Line 64: $($portfileLines[63])"
Write-Message "Line 65: $($portfileLines[64])"
Write-Message "=== DEBUG: End Diagnostics ==="
