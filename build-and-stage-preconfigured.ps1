param(
    [Parameter(Mandatory=$true)][string]$PackageName, # Name of package from preconfigured-packages.json
    [string]$StagedArtifactsPath = "StagedArtifacts"  # Output path to stage these artifacts to
)

Import-Module "$PSScriptRoot/ps-modules/Util" -Force
 
Write-Banner -Level 1 -Title "Installing preconfigured package: `"$PackageName`""
$pkg = Get-PackageInfo -PackageName $PackageName

Write-Message "$(NL)Running build-and-stage.ps1...$(NL)"
./build-and-stage.ps1 -PackageName $PackageName -PackageAndFeatures $pkg.package -LinkType $pkg.linkType -BuildType $pkg.buildType -StagedArtifactsPath $StagedArtifactsPath -VcpkgHash $pkg.vcpkgHash
