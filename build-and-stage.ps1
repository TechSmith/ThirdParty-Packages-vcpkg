param(
    [Parameter(Mandatory=$true)][string]$PackageAndFeatures, # Name of package + optional feature flags ("foo" or "foo[feature1,feature2]")
    [Parameter(Mandatory=$true)][string]$LinkType,           # Linking type: static or dynamic
    [string]$PackageName = "",                               # The base name of the tag to be used when publishing the release (ex. "openssl-static").  If not specified, it will default to "$Package-$LinkType"
    [string]$BuildType = "release",                          # Build type: release or debug
    [string]$StagedArtifactsPath = "StagedArtifacts",        # Output path to stage these artifacts to
    [string]$VcpkgHash = "",                                 # The hash of vcpkg to checkout (if applicable)
    [switch]$ShowDebug = $false                              # Show additional debugging information
)

Import-Module "$PSScriptRoot/ps-modules/Build" -Force -DisableNameChecking

Write-Banner -Level 2 -Title "Starting vcpkg install for: $PackageAndFeatures"
Write-Message "Params:"
Write-Message (Get-PSObjectAsFormattedList -Object $PSBoundParameters)

$vars = Initialize-Variables -showDebug:$ShowDebug -packageAndFeatures $PackageAndFeatures -linkType $LinkType -packageName $PackageName -buildType $BuildType -stagedArtifactsPath $StagedArtifactsPath -vcpkgHash $VcpkgHash
Setup-VcPkg -showDebug:$ShowDebug -repo $vars.vcpkgRepo -repoHash $vars.vcpkgRepoHash -installDir $vars.vcpkgInstallDir -cacheDir $vars.vcpkgCacheDir -bootstrapScript $vars.vcpkgBootstrapScript
Run-PreBuildScriptIfExists -showDebug:$ShowDebug -script $vars.prebuildScript
Install-Package -showDebug:$ShowDebug -vcpkgExe $vars.vcpkgExe -package $PackageAndFeatures -triplets $vars.triplets
ConvertTo-UniversalBinaryIfOnMac -showDebug:$ShowDebug -vcpkgInstallDir $vcpkgInstallDir -preStagePath $vars.preStagePath -x64Dir $vars.macX64Dir -arm64Dir $vars.macArm64Dir
Run-PostBuildScriptIfExists -showDebug:$ShowDebug -script $vars.postbuildScript -preStagePath $vars.preStagePath
Stage-Artifacts -showDebug:$ShowDebug -vcPkgExe $vars.vcpkgExe -preStagePath $vars.preStagePath -stagePath $vars.stagePath -artifactName $vars.artifactName

Write-Message "$(NL)$(NL)Done."
