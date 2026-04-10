# vcpkg Native Library Build System

Build system for FFmpeg, Whisper.cpp, OpenBLAS, etc. with custom patches via vcpkg.

## Structure

- `custom-ports/` - vcpkg ports (portfile.cmake, vcpkg.json, patches)
- `custom-steps/` - Pre/post-build scripts, tests (PowerShell)
- `custom-triplets/` - Platform configs (Windows, macOS, Emscripten)
- `.pipelines/` - Azure DevOps YAML
- `scripts/ps-modules/` - Build logic (Build.psm1, WinBuild.psm1, MacBuild.psm1, Util.psm1)
- `preconfigured-packages.json` - Package variants

## Build Flow

1. Parse package config from `preconfigured-packages.json` or CLI
2. Run `custom-steps/{package}/pre-build.ps1` (if exists)
3. Invoke vcpkg with custom ports/triplets
4. Run `custom-steps/{package}/post-build.ps1` (if exists)
5. Stage artifacts to `_out/`

## Key Packages

- **whisper-cpp** - Speech-to-text (variants: basic, full+AVX2+OpenBLAS, vulkan)
- **ffmpeg** - Video/audio codecs with TSC patches (GPL/non-GPL variants)
- **openblas** - BLAS/LAPACK math library

## Coding Patterns

**PowerShell:**
- Import modules via `$PSScriptRoot`
- Use cmdlet naming (Verb-Noun)
- `try/catch/finally` with resource cleanup

**vcpkg:**
- Custom ports via `VCPKG_OVERLAY_PORTS`
- Triplets define compiler flags, linkage, build type
- Features via `vcpkg_check_features()` in portfile.cmake
- Patches via `vcpkg_from_github(PATCHES ...)`

**Testing:**
- Post-build validation in `custom-steps/{package}/test*.ps1`