param(
    [Parameter(Mandatory=$true)][string]$PackageName, # Name of package from preconfigured-packages.json
    [string]$StagedArtifactsPath = "StagedArtifacts", # Output path to stage these artifacts to
    [switch]$ShowDebug = $false,
    [string]$TargetPlatform = ""
)

Import-Module "$PSScriptRoot/scripts/ps-modules/Build" -Force -DisableNameChecking

Write-Banner -Level 1 -Title "Installing preconfigured package: `"$PackageName`""

if($TargetPlatform -eq "") {
    $TargetPlatform = Get-OSType
}

$pkg = Get-PackageInfo -PackageName $PackageName -TargetPlatform $TargetPlatform

if ($pkg -eq $null) {
    Write-Message "Package $PackageName contains no section for TargetPlatform = $TargetPlatform, skipping build."
    exit 0
}

Write-Message "$(NL)Running invoke-build.ps1...$(NL)"
./invoke-build.ps1 -PackageName $PackageName -PortAndFeatures $pkg.package -CustomTriplet $pkg.customTriplet -LinkType $pkg.linkType -BuildType $pkg.buildType -StagedArtifactsPath $StagedArtifactsPath -VcpkgHash $pkg.vcpkgHash -Publish $pkg.publish -ShowDebug:$ShowDebug
