param(
    [Parameter(Mandatory=$true)][string]$PortAndFeatures, # Name of package + optional feature flags ("foo" or "foo[feature1,feature2]")
    [string]$LinkType,                                       # Linking type: static or dynamic
    [string]$PackageName = "",                               # The base name of the tag to be used when publishing the release (ex. "openssl-static").  If not specified, it will default to "$Package-$LinkType"
    [string]$BuildType = "release",                          # Build type: release or debug
    [string]$CustomTriplet = "",                             # Optional: Custom triplet to use for vcpkg. Overrides LinkType and BuildType
    [string]$StagedArtifactsPath = "StagedArtifacts",        # Output path to stage these artifacts to
    [string]$VcpkgHash = "",                                 # The hash of vcpkg to checkout (if applicable)
    [PSObject]$PublishInfo = $false,                         # Optional info on what to publish or not publish to the final artifact
    [switch]$ShowDebug = $false                              # Show additional debugging information
)

$global:showDebug = $ShowDebug
Import-Module "$PSScriptRoot/scripts/ps-modules/Build" -Force -DisableNameChecking
Run-WriteParamsStep -portAndFeatures $PortAndFeatures -scriptArgs $PSBoundParameters
Run-CleanupStep
Run-SetupVcPkgStep $VcPkgHash
Run-PreBuildStep $PortAndFeatures

$triplets = Get-Triplets -linkType $linkType -buildType $BuildType -customTriplet $CustomTriplet
Run-InstallCompilerIfNecessary -triplets $triplets
Run-InstallPackageStep -portAndFeatures $PortAndFeatures -triplets $triplets
Run-PrestageAndFinalizeBuildArtifactsStep -triplets $triplets -publishInfo $PublishInfo
Run-PostBuildStep -portAndFeatures $PortAndFeatures -linkType $LinkType -buildType $BuildType -triplets $triplets
Run-StageBuildArtifactsStep -packageName $PackageName -portAndFeatures $PortAndFeatures -linkType $LinkType -buildType $BuildType -customTriplet $CustomTriplet -stagedArtifactsPath $StagedArtifactsPath -publishInfo $PublishInfo
Run-StageSourceArtifactsStep -packageName $PackageName -portAndFeatures $PortAndFeatures -linkType $LinkType -buildType $BuildType -customTriplet $CustomTriplet -stagedArtifactsPath $StagedArtifactsPath

Write-Message "$(NL)$(NL)Done.$(NL)"
