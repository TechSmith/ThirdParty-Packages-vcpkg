# ONNX Runtime Port Analysis - Feature Discrepancies

**Date**: January 29, 2026
**Repository**: microsoft/vcpkg (master branch)
**Port**: onnxruntime
**Version**: 1.23.2 (vcpkg.json) / 1.22.1 (portfile.cmake reference)

## Summary

The onnxruntime port has significant discrepancies between features defined in `portfile.cmake` (implementation) and `vcpkg.json` (public interface). The portfile supports 16 features via `vcpkg_check_features()`, but only 4 are properly exposed in vcpkg.json.

## Features Currently in vcpkg.json ✅

1. **`cuda`** - CUDA GPU acceleration
   - Dependencies: cuda, cudnn, cudnn-frontend, nvidia-cutlass
   - Platform: `(x64 & windows & !static) | (x64 & linux)`

2. **`openvino`** - OpenVINO acceleration
   - Dependencies: openvino[cpu,gpu,onnx]
   - Platform: `!(osx | ios | android | emscripten)`

3. **`tensorrt`** - TensorRT acceleration
   - Dependencies: onnxruntime[cuda]
   - Requires TENSORRT_HOME environment variable

4. **`framework`** - macOS/iOS framework builds
   - Platform: `osx | ios`
   - Forces dynamic linkage when enabled

## Features in portfile.cmake but MISSING from vcpkg.json ❌

### High Priority (Platform Acceleration)

1. **`directml`** - DirectML GPU acceleration for Windows
   - CMake: `onnxruntime_USE_DML`, `onnxruntime_USE_CUSTOM_DIRECTML`
   - Platform: Windows only
   - Would need: DirectML SDK dependency

2. **`coreml`** - CoreML acceleration for macOS/iOS
   - CMake: `onnxruntime_USE_COREML`
   - Platform: macOS/iOS only
   - Native Apple ML acceleration

3. **`xnnpack`** - XNNPACK acceleration library
   - CMake: `onnxruntime_USE_XNNPACK`
   - Platform: Cross-platform CPU optimization
   - Would need: xnnpack port dependency

### Medium Priority (Developer/Integration Features)

4. **`python`** - Python bindings
   - CMake: `onnxruntime_ENABLE_PYTHON`
   - Would need: python3 dependency
   - Required for pip packages

5. **`training`** - Model training support
   - CMake: `onnxruntime_ENABLE_TRAINING`, `onnxruntime_ENABLE_TRAINING_APIS`
   - Enables training mode (vs inference-only)

6. **`mimalloc`** - mimalloc memory allocator
   - CMake: `onnxruntime_USE_MIMALLOC`
   - Would need: mimalloc port dependency
   - Performance optimization

### Lower Priority (Testing/Specialized)

7. **`test`** - Build unit tests and benchmarks
   - CMake: `onnxruntime_BUILD_UNIT_TESTS`, `onnxruntime_BUILD_BENCHMARKS`, `onnxruntime_RUN_ONNX_TESTS`
   - Development/CI use

8. **`valgrind`** - Valgrind memory checking
   - CMake: `onnxruntime_USE_VALGRIND`
   - Would need: valgrind dependency (Linux only)
   - Debugging/profiling

9. **`azure`** - Azure-specific integrations
   - CMake: `onnxruntime_USE_AZURE`
   - Azure ML scenarios

10. **`nccl`** - NVIDIA NCCL for multi-GPU training
    - CMake: `onnxruntime_USE_NCCL`
    - Would need: nccl dependency
    - Multi-GPU distributed training

11. **`nnapi`** - Android NNAPI support
    - CMake: `onnxruntime_USE_NNAPI_BUILTIN`
    - Platform: Android only
    - Native Android acceleration

12. **`winml`** - Windows ML integration
    - CMake: `onnxruntime_USE_WINML`
    - Platform: Windows only
    - Windows ML API support

## Impact of Missing Features

**What this means:**
- Users cannot request these features via `vcpkg install onnxruntime[feature]`
- vcpkg won't automatically resolve dependencies for these features
- Features exist in build system but are "hidden" from vcpkg's feature interface
- All missing features default to OFF in CMake configuration

**Example**: A Windows user wanting DirectML acceleration would have to:
- Manually modify portfile.cmake or pass CMake options
- Manually install DirectML SDK
- Cannot use standard vcpkg feature syntax

## Recommendations

### For TechSmith's Use Case

If planning to use onnxruntime in preconfigured-packages.json:

1. **Identify required features** for your use case:
   - CPU-only inference? (base port is sufficient)
   - GPU acceleration? (cuda, directml, coreml depending on platform)
   - Python bindings? (python feature)
   - Training workloads? (training feature)

2. **Consider creating custom port** if needed features are missing:
   - Copy from microsoft/vcpkg baseline (vcpkgHash: "2026.03.18")
   - Add missing features to `custom-ports/onnxruntime/vcpkg.json`
   - Add any required patches

3. **Popular combinations** to consider exposing:
   - `onnxruntime` - Base (CPU-only)
   - `onnxruntime[cuda]` - NVIDIA GPU (already exposed)
   - `onnxruntime[directml]` - Windows GPU (missing)
   - `onnxruntime[coreml]` - Apple GPU (missing)
   - `onnxruntime[xnnpack]` - Optimized CPU (missing)

### For Upstream Contribution

Consider submitting PR to microsoft/vcpkg to add missing features, particularly:
- directml (Windows GPU users)
- coreml (Apple users)
- xnnpack (CPU optimization for mobile/embedded)
- python (Python users)

## File Locations

**Upstream (microsoft/vcpkg):**
- portfile.cmake: `https://github.com/microsoft/vcpkg/blob/master/ports/onnxruntime/portfile.cmake`
- vcpkg.json: `https://github.com/microsoft/vcpkg/blob/master/ports/onnxruntime/vcpkg.json`

**Referenced in preconfigured-packages.json:**
- Line 453: `onnxruntime` - vcpkgHash: "2026.03.18"
- Line 459: `onnxruntime-winml` - vcpkgHash: "2026.03.18"

## Next Steps

1. ✅ Document analysis (this file)
2. ✅ Determine which features TechSmith needs (DirectML + CoreML)
3. ✅ Create custom port with DirectML and CoreML features
4. ⏳ Test builds with required feature combinations
5. ⏳ Update preconfigured-packages.json if needed

## Custom Port Implementation (January 29, 2026)

### Status: ✅ COMPLETED

Created custom onnxruntime port in `custom-ports/onnxruntime/` based on microsoft/vcpkg tag **2026.03.18**.

**Files created:**
- `vcpkg.json` - Added `directml` and `coreml` features to public interface
- `portfile.cmake` - Unchanged from upstream (already has feature support in vcpkg_check_features)
- `fix-cmake.patch` - Framework install location, abseil-cpp compatibility, webassembly fixes
- `fix-cmake-cuda.patch` - CUDA/cuDNN/cutlass integration fixes

**Key findings:**
- **DirectML**: No separate SDK needed! DirectML is built into Windows. The portfile already has `directml` and `winml` support via `onnxruntime_USE_DML` and `onnxruntime_USE_CUSTOM_DIRECTML` CMake flags (lines 53-54).
- **CoreML**: Native macOS/iOS support via `onnxruntime_USE_COREML` CMake flag (line 58). No external dependencies required.
- **No pre-build scripts needed**: Unlike Vulkan SDK for whisper-cpp, DirectML and CoreML are platform-native.

**Features added to vcpkg.json:**

```json
"default-features": [
  {
    "name": "directml",
    "platform": "windows & !static"
  },
  {
    "name": "coreml",
    "platform": "osx | ios"
  }
]
```

```json
"directml": {
  "description": "Build with DirectML GPU acceleration support (Windows only)",
  "supports": "windows & !static"
}
```

```json
"coreml": {
  "description": "Build with CoreML acceleration support (macOS/iOS only)",
  "supports": "osx | ios"
}
```

**Platform-specific default features:**
- **Windows (dynamic linkage)**: DirectML automatically enabled
- **macOS/iOS**: CoreML automatically enabled
- **Linux/other platforms**: CPU-only (no GPU acceleration by default)

**Platform constraints:**
- DirectML: `windows & !static` (Windows only, dynamic linkage required)
- CoreML: `osx | ios` (macOS/iOS only)

**Parallel builds:**
- Parallel building is controlled by vcpkg's build system (`--parallel` flag in build commands)
- No additional port-level configuration needed

**Next steps:**
1. Test build `onnxruntime[directml]` on Windows
2. Test build `onnxruntime[coreml]` on macOS
3. Add variants to preconfigured-packages.json:
   - `onnxruntime` - Base (CPU-only)
   - `onnxruntime-directml` - Windows GPU
   - `onnxruntime-coreml` - macOS GPU

---

**Notes:**
- This analysis is based on current master branch (January 2026)
- vcpkg baseline "2026.03.18" in preconfigured-packages.json is in the future
- Actual port contents may differ at that baseline date
