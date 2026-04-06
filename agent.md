# Agent: Onnxruntime Mac Build Troubleshooting

## Problem Statement
Building onnxruntime on macOS using `pwsh ./build-package.ps1 onnxruntime` fails. The same build works on Windows. The task is to identify and fix the Mac build errors until we have a successful build.

## Build System Overview

### Build Pipeline
```
build-package.ps1 onnxruntime
  -> reads preconfigured-packages.json for "onnxruntime" -> "mac" config
  -> invoke-build.ps1
     -> Run-CleanupStep (wipes vcpkg/, cache, StagedArtifacts/)
     -> Run-SetupVcPkgStep (git clone vcpkg, checkout 2026.03.18, bootstrap)
     -> Run-PreBuildStep (no custom-steps/onnxruntime/ exists)
     -> Get-Triplets -> ["x64-osx-dynamic-release", "arm64-osx-dynamic-release"]
     -> Run-InstallPackageStep (vcpkg install for each triplet)
     -> Run-PrestageAndFinalizeBuildArtifactsStep (lipo universal binary)
     -> Run-PostBuildStep (no custom-steps/onnxruntime/ exists)
     -> Run-StageBuildArtifactsStep (tar.gz)
```

### Mac Configuration (preconfigured-packages.json)
```json
{
  "name": "onnxruntime",
  "mac": {
    "package": "onnxruntime",
    "linkType": "dynamic",
    "buildType": "release",
    "vcpkgHash": "2026.03.18"
  }
}
```

### What Gets Built on Mac
- **Package**: `onnxruntime` (no explicit features)
- **Default features for macOS**: `coreml` (CoreML execution provider)
- **Triplets**: `x64-osx-dynamic-release` + `arm64-osx-dynamic-release` (universal binary)
- **Dependencies**: abseil, protobuf, flatbuffers, onnx, re2, eigen3, cpuinfo, etc.
- **Version**: 1.23.2

### Custom Port Files
- `custom-ports/onnxruntime/portfile.cmake` - Build configuration
- `custom-ports/onnxruntime/vcpkg.json` - Package manifest with dependencies  
- `custom-ports/onnxruntime/fix-cmake.patch` - Patches for framework install, abseil compat, CoreML proto download
- `custom-ports/onnxruntime/fix-cmake-cuda.patch` - CUDA patches (not relevant for Mac)

### Key Patches Applied (Mac-relevant)
1. **Framework install path**: `FRAMEWORK DESTINATION` changed from `BINDIR` to `LIBDIR`
2. **Abseil compatibility**: `absl::low_level_hash` commented out for newer abseil versions
3. **CoreML proto files**: FetchContent block downloads coremltools 7.1 from Apple GitHub for proto files

## Development Loop Strategy

### Full Build (First Time Only)
```bash
pwsh ./build-package.ps1 onnxruntime
# Takes 1-2 hours - builds all dependencies from scratch
```

### Incremental Rebuild (After First Build - PREFERRED)
Run vcpkg directly, bypassing the cleanup step:

```bash
# For arm64 (native on Apple Silicon):
./vcpkg/vcpkg install "onnxruntime:arm64-osx-dynamic-release" \
  --overlay-triplets="custom-triplets" \
  --overlay-ports="custom-ports"

# For x64 (cross-compile on Apple Silicon):
./vcpkg/vcpkg install "onnxruntime:x64-osx-dynamic-release" \
  --overlay-triplets="custom-triplets" \
  --overlay-ports="custom-ports"
```

### Even Faster: Remove + Reinstall Just onnxruntime
```bash
# Remove just the onnxruntime package, keeping dependencies cached:
./vcpkg/vcpkg remove onnxruntime:arm64-osx-dynamic-release
# Then reinstall:
./vcpkg/vcpkg install "onnxruntime:arm64-osx-dynamic-release" \
  --overlay-triplets="custom-triplets" \
  --overlay-ports="custom-ports"
```

## Build Logs Location
- vcpkg build logs: `./vcpkg/buildtrees/onnxruntime/*.log`
- Dependency build logs: `./vcpkg/buildtrees/<dep-name>/*.log`

## Current Status
- **Windows**: Working
- **Mac**: Failing (investigating errors)
