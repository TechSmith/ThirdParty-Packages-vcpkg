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

Write-Banner -Level 2 -Title "Starting vcpkg install for: $PackageAndFeatures"
Write-Message "Params:"
Write-Message (Get-PSObjectAsFormattedList -Object $PSBoundParameters)

$vars = Initialize-Variables -packageAndFeatures $PackageAndFeatures -linkType $LinkType -packageName $PackageName -buildType $BuildType -stagedArtifactsPath $StagedArtifactsPath -vcpkgHash $VcpkgHash
Setup-VcPkg -repo $vars.vcpkgRepo -repoHash $vars.vcpkgRepoHash -installDir $vars.vcpkgInstallDir -cacheDir $vars.vcpkgCacheDir -bootstrapScript $vars.vcpkgBootstrapScript
Run-PreBuildScriptIfExists -script $vars.prebuildScript
Install-Package -vcpkgExe $vars.vcpkgExe -package $PackageAndFeatures -triplets $vars.triplets
ConvertTo-UniversalBinaryIfOnMac -vcpkgInstallDir $vcpkgInstallDir -preStagePath $vars.preStagePath -x64Dir $vars.macX64Dir -arm64Dir $vars.macArm64Dir
Run-PostBuildScriptIfExists -script $vars.postbuildScript -preStagePath $vars.preStagePath
Stage-Artifacts -vcPkgExe $vars.vcpkgExe -preStagePath $vars.preStagePath -stagePath $vars.stagePath -artifactName $vars.artifactName

Write-Message "$(NL)$(NL)Done."
