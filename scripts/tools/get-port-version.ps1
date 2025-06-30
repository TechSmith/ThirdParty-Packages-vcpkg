param(
    [Parameter(Mandatory=$true)]
    [string]$PackageName,
    [string]$OverlayPortsPath = 'custom-ports'
)

Import-Module "$PSScriptRoot/../ps-modules/Build" -Force -DisableNameChecking

$myOverlayPath = Join-Path $PSScriptRoot "../../$OverlayPortsPath"
$pkg = Get-PackageInfo -PackageName $PackageName -TargetPlatform $TargetPlatform
$portName = (Get-PortNameOnly $pkg.package)
$portVersion = Get-VcpkgPortVersion -portName $PortName -overlayPortsPath $myOverlayPath
if ($portVersion) {
    Write-Host $portVersion
}
