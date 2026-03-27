# ONNX Runtime Custom Port Development

## Project Overview
This repository is a collection of scripts, Azure DevOps pipeline configurations, and custom ports for vcpkg. Its purpose is to use vcpkg to build various ports of different libraries.

## Build Environments
- **Local builds**: Use `./build-package.ps1` script
- **CI/CD builds**: Use Azure DevOps pipelines defined in `.pipelines` folder

## Current Goal: ONNX Runtime Custom Port

### Objective
Create a custom port for ONNX Runtime with platform-specific GPU acceleration support.

### Requirements
1. **Base Setup**
   - Pull the latest onnxruntime port from microsoft/vcpkg (branch: 2026.03.18 as specified in preconfigured-packages.json)
   - Place it in `custom-ports/onnxruntime` directory
   - Initial commit: vanilla port from upstream

2. **Feature Enhancement**
   - Add support for all ONNX Runtime build flags
   - Expose these as vcpkg features in vcpkg.json
   - Modify portfile.cmake to handle feature flags
   - Second commit: enhanced feature support

3. **Platform-Specific Defaults**
   - **Windows**: Enable DirectML execution provider by default
   - **macOS**: Enable CoreML execution provider by default
   - **All platforms**: Enable parallel builds by default
   - Third commit: platform-specific defaults

### Technical Details
- **DirectML**: Windows GPU acceleration using DirectX 12
- **CoreML**: macOS GPU/Neural Engine acceleration
- **Parallel builds**: ONNX Runtime supports parallel compilation to speed up builds

### Branch
Working on a feature branch for onnxruntime development.

### Documentation
Track progress and learnings in `progress.md` after each significant step.
