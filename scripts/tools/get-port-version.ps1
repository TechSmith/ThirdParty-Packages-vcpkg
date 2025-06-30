param(
    [Parameter(Mandatory=$true)]
    [string]$PackageName,
    [string]$TargetPlatform,
    [string]$OverlayPortsPath = 'custom-ports'
)

Import-Module "$PSScriptRoot/../ps-modules/Build" -Force -DisableNameChecking

Write-Host "> PackageName is: $PackageName"
$myOverlayPath = Join-Path $PSScriptRoot "../../$OverlayPortsPath"
$pkg = Get-PackageInfo -PackageName $PackageName -TargetPlatform $TargetPlatform
$portName = (Get-PortNameOnly $pkg.package)
Write-Host "> PortName is: $portName"

$pathToVcpkgExe = Join-Path $PSScriptRoot "../../$(Get-VcPkgExe)"
Write-Host "> Path to vcpkg.exe is: $pathToVcpkgExe"

$portVersion = Get-VcpkgPortVersion -portName $portName -pathToVcpkgExe $pathToVcpkgExe -overlayPortsPath $myOverlayPath
if ($portVersion) {
    Write-Host $portVersion
}
