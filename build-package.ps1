param(
    [Parameter(Mandatory=$true)][string]$PackageName, # Name of package from preconfigured-packages.json
    [string]$StagedArtifactsPath = "StagedArtifacts", # Output path to stage these artifacts to
    [switch]$ShowDebug = $false,
    [string]$TargetOS = $null
)

Import-Module "$PSScriptRoot/scripts/ps-modules/Build" -Force -DisableNameChecking

Write-Banner -Level 1 -Title "Installing preconfigured package: `"$PackageName`""

if($TargetOS -eq $null) {
    $TargetOS = Get-OSType
}

$pkg = Get-PackageInfo -PackageName $PackageName -TargetOS $TargetOS

if ($pkg -eq $null) {
    Write-Message "Package $PackageName contains no section for TargetOS = $TargetOS, skipping build."
    exit 0
}

Write-Message "$(NL)Running invoke-build.ps1...$(NL)"
./invoke-build.ps1 -PackageName $PackageName -PackageAndFeatures $pkg.package -CustomTriplet $pkg.customTriplet -LinkType $pkg.linkType -BuildType $pkg.buildType -StagedArtifactsPath $StagedArtifactsPath -VcpkgHash $pkg.vcpkgHash -Publish $pkg.publish -ShowDebug:$ShowDebug
