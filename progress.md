# ONNX Runtime Custom Port Development Progress

## Session Date: March 27, 2026

### Goal
Customize the ONNX Runtime port to support platform-specific GPU acceleration (DirectML on Windows, CoreML on macOS) with parallel builds enabled by default.

### Initial State
- Branch: `add/onnxruntime3`
- Starting commit: `0ed426a` - "Add official onnxruntime 1.23.2 port from vcpkg 2026.03.18"
- The port already exists in `custom-ports/onnxruntime` with:
  - vcpkg.json (version 1.23.2)
  - portfile.cmake
  - Two patch files: fix-cmake.patch, fix-cmake-cuda.patch

### Research Phase - ONNX Runtime Execution Providers

Reviewed ONNX Runtime documentation at https://onnxruntime.ai/docs/build/eps.html

#### Available Execution Providers:
1. **CPU-based**:
   - Default CPU provider (built-in)
   - oneDNN (Intel CPU/GPU)
   
2. **NVIDIA GPUs**:
   - CUDA
   - TensorRT
   - TensorRT RTX
   
3. **Intel Hardware**:
   - OpenVINO (CPU, GPU, NPU)
   - oneDNN
   
4. **Windows**:
   - DirectML (DirectX 12 GPU acceleration)
   
5. **Apple**:
   - CoreML (GPU/Neural Engine acceleration)
   
6. **Mobile**:
   - NNAPI (Android)
   - XNNPACK (Cross-platform, optimized for ARM)
   
7. **AMD**:
   - ROCm
   - MIGraphX
   - Vitis AI
   
8. **Qualcomm**:
   - QNN
   
9. **Other**:
   - Azure (cloud)
   - ACL (Arm Compute Library)
   - Arm NN
   - RKNPU (Rockchip)
   - CANN (Huawei)

#### Build Flags Discovered:
- **Execution Providers**: `onnxruntime_USE_DML`, `onnxruntime_USE_COREML`, `onnxruntime_USE_XNNPACK`, etc.
- **Parallel Compilation**: `onnxruntime_PARALLEL_COMPILE=ON` (enables parallel builds)
- **Training**: `onnxruntime_ENABLE_TRAINING`, `onnxruntime_ENABLE_TRAINING_APIS`
- **Memory Allocator**: `onnxruntime_USE_MIMALLOC`

### Implementation Phase

#### Change 1: Enhanced vcpkg.json Features

Added the following features to vcpkg.json:

1. **coreml**: CoreML execution provider (macOS/iOS only)
   - Platform support: `osx | ios`
   
2. **directml**: DirectML execution provider (Windows only)
   - Platform support: `windows & !uwp`
   
3. **xnnpack**: XNNPACK execution provider (cross-platform)
   - No dependencies, lightweight
   
4. **nnapi**: NNAPI execution provider (Android only)
   - Platform support: `android`
   
5. **mimalloc**: Microsoft's memory allocator
   - Dependency: mimalloc package

**Existing features** (already in upstream port):
- cuda: CUDA support with cuDNN, CUDA frontend, CUTLASS
- openvino: OpenVINO support
- tensorrt: TensorRT support (requires CUDA)
- framework: macOS/iOS framework build

#### Change 2: Platform-Specific Defaults in vcpkg.json

Added platform-specific default features directly in vcpkg.json using Feature Objects with platform expressions:

```json
"default-features": [
  {
    "name": "directml",
    "platform": "windows"
  },
  {
    "name": "coreml",
    "platform": "osx | ios"
  }
]
```

This is the proper vcpkg way to handle platform-specific defaults:
- **Windows builds**: Will automatically include DirectML support
- **macOS/iOS builds**: Will automatically include CoreML support
- Users can still explicitly disable these by setting `"default-features": false` in their dependency declaration

**Note**: This is superior to the portfile.cmake approach because:
1. It's declarative and follows vcpkg conventions
2. It's visible in the vcpkg.json manifest
3. It integrates properly with vcpkg's dependency resolution
4. Users can override it using standard vcpkg mechanisms

#### Change 3: Enable Parallel Compilation

Added to vcpkg_cmake_configure OPTIONS section:
```cmake
-Donnxruntime_PARALLEL_COMPILE=ON
```

This enables ONNX Runtime's parallel compilation feature which speeds up builds by compiling operators in parallel.

### Key Decisions Made

1. **Default Features Strategy**: 
   - Use platform detection to enable GPU acceleration by default
   - DirectML on Windows (supports all Windows GPUs via DirectX 12)
   - CoreML on macOS (supports GPU and Neural Engine)
   
2. **Feature Scope**:
   - Added commonly used execution providers (DirectML, CoreML, XNNPACK, NNAPI)
   - Did NOT add specialized providers requiring external SDKs (ROCm, CANN, Vitis AI, etc.)
   - These can be added later if needed
   
3. **Build Performance**:
   - Enable parallel compilation by default for faster builds
   - This is safe as it's an official ONNX Runtime build option

### Files Modified

1. `custom-ports/onnxruntime/vcpkg.json`
   - Added 5 new features: coreml, directml, xnnpack, nnapi, mimalloc
   - Added platform-specific default-features for directml (Windows) and coreml (macOS/iOS)
   
2. `custom-ports/onnxruntime/portfile.cmake`
   - Added onnxruntime_PARALLEL_COMPILE=ON flag (line 118)

### Next Steps

1. ✅ Commit the feature additions to vcpkg.json and portfile.cmake
2. ⏳ Test the build locally with `./build-package.ps1 -PackageName onnxruntime`
3. ⏳ Verify that DirectML is enabled on Windows builds
4. ⏳ Update preconfigured-packages.json if needed
5. ⏳ Create final commit and prepare for PR

### Potential Issues to Watch

1. **DirectML Dependencies**: DirectML should be included in Windows SDK, but verify it builds correctly
2. **CoreML on macOS**: Requires macOS SDK, should be available on Mac build machines
3. **Feature Conflicts**: Some features may be mutually exclusive (e.g., can't use both CUDA and DirectML simultaneously in practice)
4. **Build Time**: Even with parallel compilation, ONNX Runtime is a large project - expect longer build times

### References

- ONNX Runtime Build Documentation: https://onnxruntime.ai/docs/build/eps.html
- DirectML EP: https://onnxruntime.ai/docs/execution-providers/DirectML-ExecutionProvider.html
- CoreML EP: https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html
- XNNPACK EP: https://onnxruntime.ai/docs/execution-providers/Xnnpack-ExecutionProvider.html
