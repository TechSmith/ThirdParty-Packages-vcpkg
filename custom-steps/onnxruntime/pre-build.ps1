Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

# Patch the vcpkg 'onnx' port to add ONNX_DISABLE_STATIC_REGISTRATION=ON.
# When onnx is statically linked into onnxruntime.dll (as our custom triplet does),
# the ONNX schema registration runs twice at DLL load time — once from C++ static
# initializers and once from ORT's own initialization — producing ~611 duplicate
# "already registered" warnings on stderr. This flag disables the static initializer
# registration, eliminating the duplicates.
Write-Message "Applying TechSmith patch to vcpkg onnx port (ONNX_DISABLE_STATIC_REGISTRATION)..."
$patchSuccess = Apply-VcpkgPortPatch -PortName "onnx" -PatchFile "$PSScriptRoot/disable-onnx-static-registration.patch"
if (-not $patchSuccess) {
    Write-Message "FATAL: Failed to apply patch to onnx port" -Error
    exit 1
}
