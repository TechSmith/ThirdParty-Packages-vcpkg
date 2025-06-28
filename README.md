# ThirdParty-Packages-vcpkg
This is a repo that contains yaml and scripts to build and publish third party packages using the vcpkg package manager.

## How it works
There are several steps to building a "package":
1. [build-package.ps1](build-package.ps1) reads the package information from [preconfigured-packages.json](preconfigured-packages.json) and passes that info to [scripts/invoke-build.ps1]
2. [scripts/invoke-build.ps1] Does the following:
  a. Run-CleanupStep
  b. Run-SetupVcPkgStep $VcPkgHash
  c. Run-PreBuildStep $PortAndFeatures
  d. Run-InstallCompilerIfNecessary -triplets $triplets
  e. Run-InstallPackageStep -portAndFeatures $PortAndFeatures -triplets $triplets
  f. Run-PrestageAndFinalizeBuildArtifactsStep -triplets $triplets -publishInfo $PublishInfo
  g. Run-PostBuildStep -portAndFeatures $PortAndFeatures -linkType $LinkType -buildType $BuildType -triplets $triplets
  h. Run-StageBuildArtifactsStep -packageName $PackageName -portAndFeatures $PortAndFeatures -linkType $LinkType -buildType $BuildType -customTriplet $CustomTriplet -stagedArtifactsPath $StagedArtifactsPath -publishInfo $PublishInfo
  i. Run-StageSourceArtifactsStep -packageName $PackageName -portAndFeatures $PortAndFeatures -linkType $LinkType -buildType $BuildType -customTriplet $CustomTriplet -stagedArtifactsPath $StagedArtifactsPath



## Pipelines
Authorized user can access build pipelines here:
- [Build Package (preconfigured)](https://dev.azure.com/techsmith/ThirdParty-Packages-vcpkg/_build?definitionId=789)
- [Build Package (custom)](https://dev.azure.com/techsmith/ThirdParty-Packages-vcpkg/_build?definitionId=790)

### Pipeline: "[Build Package (preconfigured)](https://dev.azure.com/techsmith/ThirdParty-Packages-vcpkg/_build?definitionId=789)"
This pipeline is intended to be used periodically to build packages in a TechSmith-approved way for use in our products.

It does the following:
1. Allows user to pick a package to build from a dropdown list
2. Matches the user's selection with a known list of package configurations (see: [preconfigured-packages.json](preconfigured-packages.json))
3. Gets the latest vcpkg from our clone of it (see: [TechSmith/vcpkg](https://github.com/TechSmith/vcpkg))
4. Builds the package for Mac and Windows
5. Publishes these packages as pipeline artifacts
6. Publishes those artifacts to a GitHub release (see: [TechSmith/ThirdParty-Packages-vcpkg/releases](https://github.com/TechSmith/ThirdParty-Packages-vcpkg/releases))

Future features may include:
- Allow user to optionally enter in a hash of vcpkg to use, rather than always using the latest
- Get vcpkg from Microsoft instead of needing our own clone of it

### Pipeline: "[Build Package (custom)](https://dev.azure.com/techsmith/ThirdParty-Packages-vcpkg/_build?definitionId=790)"
This pipeline is for use when testing out building a new package.  Artifacts from this pipeline should **not** be used in a TechSmith build.  When you finish testing using this pipeline, you must configure the "[Build Package (preconfigured)](https://dev.azure.com/techsmith/ThirdParty-Packages-vcpkg/_build?definitionId=789)" pipeline to contain your new package with it's custom build options and expose it as a new package that a user can choose to build from that pipeline.

It does the following:
1. Allows user to enter in:
  a. A custom package + optional feature flags (ex. `somepackage` or `somepackage[feature1,feature2]`)
  b. A link type (`dynamic` or `static`)
  c. A build type (`release` or `debug`)
2. Gets the latest vcpkg from our clone of it (see: [TechSmith/vcpkg](https://github.com/TechSmith/vcpkg))
3. Builds the package for Mac and Windows
4. Publishes these packages as pipeline artifacts

## Building Locally
Builds can be done locally using PowerShell on Windows, Mac, and Linux, to test and debug a package.

### Testing Linux Builds Locally
Linux builds can be developed and run from Windows via WSL.  The ffmpeg-cloud-gpl pre-configured package for example was created using Ubuntu, which is the default WSL OS.

Given that WSL is quite slow when reading / writing files between Linux and Windows, it's best to run builds directly within a Linux mounted file location (for example `~/projects/ThirdParty-Packages-vcpkg` instead of `/mnt/c/projects/ThirdParty-Packages-vcpkg`).
