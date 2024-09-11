param(
    [Parameter(Mandatory=$true)][string]$PackageName, # Name of package from preconfigured-packages.json
    [string]$StagedArtifactsPath = "StagedArtifacts", # Output path to stage these artifacts to
    [switch]$ShowDebug = $false
)

Import-Module "$PSScriptRoot/scripts/ps-modules/Build" -Force -DisableNameChecking
 
Write-Banner -Level 1 -Title "Installing preconfigured package: `"$PackageName`""
$pkg = Get-PackageInfo -PackageName $PackageName

Write-Message "$(NL)Running invoke-build.ps1...$(NL)"
./invoke-build.ps1 -PackageName $PackageName -PackageAndFeatures $pkg.package -LinkType $pkg.linkType -BuildType $pkg.buildType -StagedArtifactsPath $StagedArtifactsPath -VcpkgHash $pkg.vcpkgHash -ShowDebug:$ShowDebug
