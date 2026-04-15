# ThirdParty-Packages-vcpkg
This is a repo that contains YAML and PowerShell scripts to build and publish third party packages which contain one or more libraries, using the [vcpkg](https://github.com/microsoft/vcpkg) package manager.

## Pipelines
Authorized users can access build pipelines here:
- [Build Package (preconfigured)](https://dev.azure.com/techsmith/ThirdParty-Packages-vcpkg/_build?definitionId=789)
- [Build Package (custom)](https://dev.azure.com/techsmith/ThirdParty-Packages-vcpkg/_build?definitionId=790)

### Pipeline: "[Build Package (preconfigured)](https://dev.azure.com/techsmith/ThirdParty-Packages-vcpkg/_build?definitionId=789)"
This pipeline is intended to be used periodically to build packages in a TechSmith-approved way for use in our products, and publish them to releases in this repo.

This pipeline does the following:
1. Allows user to pick a package to build from a dropdown list (defined in: [.pipelines/build-package-preconfigured.yml](.pipelines/build-package-preconfigured.yml))
2. Matches the user's selection with a known list of package configurations (defined in: [preconfigured-packages.json](preconfigured-packages.json))
3. Gets the latest version of the vcpkg repo and bootstraps the vcpkg executable (see: [microsoft/vcpkg](https://github.com/microsoft/vcpkg))
4. Runs `custom-steps/<port-name>/pre-build.ps1`, if it exists for the port that is about to build this package
5. Builds the package for one or more platforms (Mac, Windows, Linux, WASM), using either:
   - The "overlay port" in [custom-ports](custom-ports), if it exists -or-
   - The Microsoft version of the port in: https://github.com/microsoft/vcpkg/tree/master/ports
6. Runs `custom-steps/<port-name>/post-build.ps1`, if it exists for the port that just built this package
7. Publishes pipeline artifacts for:
   - All patched source code used to build all the libraries in this package
   - All the binary artifacts for all libraries built for this package
8. Creates a GitHub release in this repo with the source and binary artifacts for the built package in [TechSmith/ThirdParty-Packages-vcpkg/releases](https://github.com/TechSmith/ThirdParty-Packages-vcpkg/releases)

### Pipeline: "[Build Package (custom)](https://dev.azure.com/techsmith/ThirdParty-Packages-vcpkg/_build?definitionId=790)"
This pipeline is for use when testing out building a new package.  Artifacts from this pipeline should never be shipped to customers.  When you finish testing using this pipeline, you must configure the "[Build Package (preconfigured)](https://dev.azure.com/techsmith/ThirdParty-Packages-vcpkg/_build?definitionId=789)" pipeline to contain your new package with its custom build options and expose it as a new package that a user can choose to build from that pipeline.

This pipeline does the following:
1. Allows user to enter in:
   - A custom package + optional feature flags (ex. `somepackage` or `somepackage[feature1,feature2]`)
   - A link type (`dynamic` or `static`)
   - A build type (`release` or `debug`)
2. Gets the latest version of the vcpkg repo and bootstraps the vcpkg executable (see: [microsoft/vcpkg](https://github.com/microsoft/vcpkg))
3. Builds the package for one or more platforms (Mac, Windows, Linux, WASM)
4. Publishes these packages as pipeline artifacts

## Testing Locally ("Preconfigured Packages")
You can test building and creating local artifacts on your local machine for packages defined in [preconfigured-packages.json](preconfigured-packages.json) by using [./build-package.ps1](build-package.ps1).

### Testing locally for Mac, Windows and Wasm builds
You can build locally from a PowerShell command prompt on Mac or Windows.  By default, build-package.ps1 will detect your OS type (ex. Windows, Mac) and use that as the target platform.  You can override the target platform with the `-TargetPlatform` parameter and build this for wasm instead of either Mac or Windows.

#### Example 1: Build the "tinyxml" package for Mac or Windows (depending on the platform you are on):
```PowerShell
pwsh
./build-package.ps1 tinyxml
```

#### Example 2: Build the "tinyxml" package for wasm:
```PowerShell
pwsh
./build-package.ps1 -PackageName tinyxml -TargetPlatform wasm
```

### Testing locally for Linux on Windows
Linux builds can be developed and run from Windows via [WSL](https://learn.microsoft.com/en-us/windows/wsl/about).  For example, the `ffmpeg-cloud-gpl` package was created using Ubuntu, which is the default WSL OS.

#### Example 3: Build "tinyxml" package for linux in wsl †
```PowerShell
wsl
pwsh
./build-package.ps1 -PackageName tinyxml
```

_† Note: Given that WSL is quite slow when reading / writing files between Linux and Windows, it is actually best to run builds directly within a Linux mounted file location (for example, in wsl you may want to clone this repo to `~/code/ThirdParty-Packages-vcpkg` and use this instead of using the Windows-mounted location of something like `/mnt/c/code/ThirdParty-Packages-vcpkg`)._