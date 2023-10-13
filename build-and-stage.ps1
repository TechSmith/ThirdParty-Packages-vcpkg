param(
    [Parameter(Mandatory=$true)][string]$PackageAndFeatures, # Name of package + optional feature flags ("foo" or "foo[feature1,feature2]")
    [Parameter(Mandatory=$true)][string]$LinkType,           # Linking type: static or dynamic
    [string]$PackageName = "",                               # The base name of the tag to be used when publishing the release (ex. "openssl-static").  If not specified, it will default to "$Package-$LinkType"
    [string]$BuildType = "release",                          # Build type: release or debug
    [string]$StagedArtifactsPath = "StagedArtifacts",        # Output path to stage these artifacts to
    [string]$VcpkgHash = "",                                 # The hash of vcpkg to checkout (if applicable)
    [switch]$ShowDebug = $false                              # Show additional debugging information
)

$global:showDebug = $ShowDebug
Import-Module "$PSScriptRoot/ps-modules/Build" -Force -DisableNameChecking
Run-WriteParamsStep -packageAndFeatures $PackageAndFeatures -scriptArgs $PSBoundParameters
Run-SetupVcPkgStep $VcPkgHash
Run-PreBuildStep $PackageAndFeatures
Run-InstallPackageStep -packageAndFeatures $PackageAndFeatures -linkType $LinkType -buildType $BuildType
Run-FinalizeArtifactsStep -linkType $LinkType -buildType $BuildType
Run-PostBuildStep -packageAndFeatures $PackageAndFeatures -linkType $LinkType -buildType $BuildType
Run-StageArtifactsStep -packageName $PackageName -packageAndFeatures $PackageAndFeatures -linkType $LinkType -buildType $BuildType -stagedArtifactsPath $StagedArtifactsPath

Write-Message "$(NL)$(NL)Done.$(NL)"
