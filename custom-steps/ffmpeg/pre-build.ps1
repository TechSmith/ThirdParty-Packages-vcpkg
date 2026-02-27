Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

Write-Message "Applying TechSmith patches..."
$patchSuccess = Apply-VcpkgPortPatch -PortName "ffmpeg" -PatchFile "$PSScriptRoot/1001-tsc-cve-patch.patch"
if (-not $patchSuccess) {
    Write-Message "FATAL: Failed to apply patch to pango port" -Error
    exit 1
}