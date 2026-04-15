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

## Managing Version Information for Windows DLLs

For Windows builds, packages can include version information metadata in their DLL files. This is managed through `version-info.json` files located in `custom-steps/<port-name>/` directories.

### version-info.json File Structure

A `version-info.json` file contains metadata for all DLLs in a package. Here's an example structure:

```json
{
  "buildNumber": 103,
  "files": [
    {
      "filename": "bin/mylib.dll",
      "fileDescription": "My Library - Core functionality",
      "fileVersion": "2.1.0",
      "productName": "My Library",
      "productVersion": "2.1.0",
      "copyright": "Copyright (c) 2026 Example Corp"
    },
    {
      "filename": "bin/helper.dll",
      "fileDescription": "Helper utilities library",
      "fileVersion": "1.5.3",
      "productName": "Helper",
      "productVersion": "1.5.3",
      "copyright": "Copyright (c) 2026 Example Corp"
    }
  ]
}
```

**Field Descriptions:**

- **`buildNumber`** (top-level): A monotonically increasing integer that is **automatically incremented** each time you regenerate the file using `update-version-info-json.ps1`. This is critical because some TechSmith installers have issues updating DLLs that have a different file hash but the same version number. The script increments this value automatically when:
  - Regenerating the version-info.json file
  - Updating any library versions
  - Rebuilding the package for any reason
  
- **`files`** (top-level): Array of DLL metadata objects

For each file entry:
- **`filename`**: Relative path to the DLL (usually `bin/<dllname>.dll`)
- **`fileDescription`**: Brief description of the library (automatically enriched from vcpkg metadata)
- **`fileVersion`**: The file version to stamp into the DLL (automatically extracted from vcpkg manifests)
- **`productName`**: Product name shown in Windows properties (automatically enriched from vcpkg metadata)
- **`productVersion`**: Product version shown in Windows properties (automatically extracted from vcpkg manifests)
- **`copyright`**: Copyright notice (automatically enriched from vcpkg copyright files)

### Creating or Updating a version-info.json File

When setting up a new package or updating an existing package that needs DLL version information on Windows, use the `update-version-info-json.ps1` script to generate or regenerate the `version-info.json` file:

**Prerequisites:**
1. **You must build the package locally on Windows first** to generate the DLLs and vcpkg metadata
2. The build process creates package metadata files in `vcpkg/installed/vcpkg/info/` that the script uses to map DLLs to their source ports

```powershell
# Step 1: Build your package locally on Windows to generate DLLs and metadata
./build-package.ps1 -PackageName mypackage

# Step 2: Generate or update the version-info.json from the built DLLs
# The script will automatically enrich metadata from vcpkg sources
./scripts/tools/update-version-info-json.ps1 `
    -InputDllDir "./vcpkg/installed/x64-windows-dynamic-release/bin" `
    -OutputJsonFile "./custom-steps/mypackage/version-info.json" `
    -VcpkgRoot "./vcpkg" `
    -Triplet "x64-windows-dynamic-release"
```

This script will:
1. Scan all DLL files in the input directory
2. Read vcpkg's package installation metadata (the `.list` files in `vcpkg/installed/vcpkg/info/`)
3. Map each DLL to its source vcpkg port
4. Enrich metadata by reading:
   - **Descriptions** from `vcpkg.json` files (in `custom-ports/` or `vcpkg/ports/`)
   - **Versions** from `vcpkg.json` files (supports `version`, `version-semver`, `version-string`)
   - **Product names** from port names
   - **Copyright information** from `vcpkg/installed/<triplet>/share/<portname>/copyright` files
5. **Automatically increment `buildNumber`** if the file already exists (reads existing value and adds 1)
6. Create or overwrite the `version-info.json` file with enriched metadata

**Key Features:**
- **No manual `versionSource` tracking**: The script directly reads vcpkg metadata at generation time
- **Automatic buildNumber increment**: Ensures proper versioning for TechSmith installers
- **Automatic metadata enrichment**: Pulls descriptions, versions, and copyright from vcpkg sources
- **Triplet auto-detection**: If `-Triplet` is omitted and only one triplet exists, it's auto-detected

After generation, you should:
1. Review the generated file to verify all metadata is correct
2. Manually update any fields that need correction (rare, as metadata comes from vcpkg)
3. Commit the `version-info.json` file to the repository

**Important Notes:**
- The script requires a local Windows build first to generate the vcpkg metadata it relies on
- If you're creating the file for the first time, `buildNumber` will start at 100
- If the file already exists, `buildNumber` will be automatically incremented
- The script works with both standard vcpkg ports and overlay ports in `custom-ports/`

### How version-info.json is Used

The `version-info.json` file is consumed by the post-build step for Windows builds:
- The `custom-steps/<port-name>/post-build.ps1` script calls `Update-VersionInfoForDlls`
- This function reads the `version-info.json` file and stamps each DLL with the specified version information
- This ensures that DLLs have proper metadata visible in Windows File Explorer and version resource tools