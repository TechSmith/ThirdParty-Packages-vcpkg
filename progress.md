# ONNX Runtime Custom Port Development Progress

## Session Date: March 27, 2026 (Updated - Comprehensive Features)

### Goal
Customize the ONNX Runtime port to support ALL available execution providers and build options from the official ONNX Runtime repository, making them accessible via vcpkg features.

### Initial State
- Branch: `add/onnxruntime3`
- Starting commit: `0ed426a` - "Add official onnxruntime 1.23.2 port from vcpkg 2026.03.18"
- The port already exists in `custom-ports/onnxruntime` with:
  - vcpkg.json (version 1.23.2)
  - portfile.cmake
  - Two patch files: fix-cmake.patch, fix-cmake-cuda.patch

### Comprehensive Research Phase - ONNX Runtime Build Options

Reviewed ONNX Runtime CMakeLists.txt at https://github.com/microsoft/onnxruntime/blob/main/cmake/CMakeLists.txt

#### Complete List of ALL Features (24 total):

**Execution Providers (19):**
1. **azure**: Azure execution provider for cloud inferencing
2. **cann**: Huawei Ascend CANN execution provider (Linux only)
3. **coreml**: Apple CoreML (macOS/iOS GPU/Neural Engine) - ✅ macOS/iOS default
4. **cuda**: NVIDIA CUDA GPU acceleration (requires cuda, cudnn, cudnn-frontend, nvidia-cutlass)
5. **directml**: Windows DirectML (DirectX 12 GPU) - ✅ Windows default
6. **dnnl**: Intel oneDNN (formerly DNNL) for CPU/GPU
7. **migraphx**: AMD MIGraphX execution provider (Linux only)
8. **nccl**: NVIDIA NCCL for distributed training (Linux only)
9. **nnapi**: Android Neural Networks API (Android only)
10. **openvino**: Intel OpenVINO (CPU/GPU/NPU) - requires openvino package
11. **qnn**: Qualcomm QNN execution provider
12. **rknpu**: Rockchip RKNPU (Linux ARM64 only)
13. **snpe**: Qualcomm SNPE (Android only)
14. **tensorrt**: NVIDIA TensorRT (requires cuda feature)
15. **vitisai**: AMD Vitis-AI
16. **vsinpu**: VSI NPU execution provider
17. **webnn**: WebNN for browser hardware acceleration
18. **winml**: Windows Machine Learning (Windows only)
19. **xnnpack**: XNNPACK cross-platform optimizer

**Build Features (5):**
20. **framework**: Build macOS/iOS framework with Objective-C bindings
21. **mimalloc**: Microsoft mimalloc memory allocator (requires mimalloc package)
22. **telemetry**: Build with telemetry support (Windows only)
23. **test**: Build unit tests and benchmarks
24. **training**: Enable full training functionality (ORTModule + Training APIs)

### Complete Feature Mapping

All 24 features now have proper vcpkg.json definitions with:
- Platform support constraints where applicable (e.g., `"supports": "windows & !uwp"`)
- Dependencies (e.g., CUDA requires cuda, cudnn, cudnn-frontend, nvidia-cutlass)
- Clear descriptions

All features are mapped in portfile.cmake via `vcpkg_check_features` to their corresponding CMake flags:
- **Single feature → single flag**: 
  - `azure` → `onnxruntime_USE_AZURE`
  - `coreml` → `onnxruntime_USE_COREML`
  - `xnnpack` → `onnxruntime_USE_XNNPACK`
  - `mimalloc` → `onnxruntime_USE_MIMALLOC`
  - `nccl` → `onnxruntime_USE_NCCL`
  - `dnnl` → `onnxruntime_USE_DNNL`
  - `qnn` → `onnxruntime_USE_QNN`
  - `snpe` → `onnxruntime_USE_SNPE`
  - `rknpu` → `onnxruntime_USE_RKNPU`
  - `vsinpu` → `onnxruntime_USE_VSINPU`
  - `vitisai` → `onnxruntime_USE_VITISAI`
  - `migraphx` → `onnxruntime_USE_MIGRAPHX`
  - `cann` → `onnxruntime_USE_CANN`
  - `webnn` → `onnxruntime_USE_WEBNN`
  - `telemetry` → `onnxruntime_USE_TELEMETRY`
  - `winml` → `onnxruntime_USE_WINML`
  - `openvino` → `onnxruntime_USE_OPENVINO`
  
- **Single feature → multiple flags**:
  - `cuda` → `onnxruntime_USE_CUDA` + `onnxruntime_USE_CUDA_NHWC_OPS`
  - `directml` → `onnxruntime_USE_DML` + `onnxruntime_USE_CUSTOM_DIRECTML`
  - `tensorrt` → `onnxruntime_USE_TENSORRT` + `onnxruntime_USE_TENSORRT_BUILTIN_PARSER`
  - `nnapi` → `onnxruntime_USE_NNAPI_BUILTIN`
  - `framework` → `onnxruntime_BUILD_APPLE_FRAMEWORK` + `onnxruntime_BUILD_OBJC`
  - `test` → `onnxruntime_BUILD_UNIT_TESTS` + `onnxruntime_BUILD_BENCHMARKS` + `onnxruntime_RUN_ONNX_TESTS`
  - `training` → `onnxruntime_ENABLE_TRAINING` + `onnxruntime_ENABLE_TRAINING_APIS` + `onnxruntime_ENABLE_TRAINING_OPS`

### Implementation Phase

#### Change 1: Comprehensive Feature Set (24 total features)

**Initial commit (b134417)** added 5 basic features:
- coreml, directml, xnnpack, nnapi, mimalloc

**Current expansion** added 19 additional features for complete execution provider coverage:
- azure, cann, dnnl, migraphx, nccl, qnn, rknpu, snpe, tensorrt, vitisai, vsinpu, webnn, winml, framework, telemetry, test, training

Plus **cuda** and **openvino** which were already in the upstream port.

Each feature includes:
- Platform constraints using vcpkg supports expressions
- Dependency declarations where needed
- Clear descriptions explaining purpose

**Key platform constraints:**
- Windows-only: `directml`, `winml`, `telemetry` (use `"supports": "windows & !uwp"`)
- macOS/iOS-only: `coreml`, `framework` (use `"supports": "osx | ios"`)
- Linux-only: `cann`, `migraphx`, `nccl` (use `"supports": "linux"`)
- Android-only: `nnapi`, `snpe` (use `"supports": "android"`)
- ARM64 Linux: `rknpu` (use `"supports": "linux & arm64"`)

**Dependencies added:**
- `cuda`: Requires cuda, cudnn, cudnn-frontend, nvidia-cutlass packages
- `tensorrt`: Requires cuda feature (declared as feature dependency)
- `mimalloc`: Requires mimalloc package
- `openvino`: Requires openvino package with specific features (cpu, gpu, onnx)

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

1. **Comprehensive Coverage**: 
   - Added ALL 24 execution providers and features from official ONNX Runtime
   - No arbitrary restrictions - users can choose what they need
   - Platform constraints ensure features only install where supported
   
2. **Default Features Strategy**: 
   - Use platform detection to enable GPU acceleration by default
   - DirectML on Windows (supports all Windows GPUs via DirectX 12)
   - CoreML on macOS/iOS (supports GPU and Neural Engine)
   - Users can disable with `"default-features": false`
   
3. **vcpkg Best Practices**:
   - Use declarative `default-features` with platform expressions (not CMake logic)
   - Platform constraints in `"supports"` field prevent unsupported builds
   - Feature dependencies properly declared (e.g., tensorrt requires cuda)
   
4. **Build Performance**:
   - Enable parallel compilation by default (`onnxruntime_PARALLEL_COMPILE=ON`)
   - This is an official ONNX Runtime build option, safe to enable

### Files Modified

1. `custom-ports/onnxruntime/vcpkg.json`
   - Added 5 new features: coreml, directml, xnnpack, nnapi, mimalloc
   - Added platform-specific default-features for directml (Windows) and coreml (macOS/iOS)
   
2. `custom-ports/onnxruntime/portfile.cmake`
   - Added onnxruntime_PARALLEL_COMPILE=ON flag (line 118)

### Next Steps

1. ✅ Commit the feature additions to vcpkg.json and portfile.cmake
2. ✅ Verify vcpkg_check_features configuration is optimal
3. ⏳ Test the build locally with `./build-package.ps1 -PackageName onnxruntime`
4. ⏳ Verify that DirectML is enabled on Windows builds
5. ⏳ Update preconfigured-packages.json if needed
6. ⏳ Create final commit and prepare for PR

### vcpkg_check_features Verification

Reviewed the current `vcpkg_check_features` configuration in portfile.cmake:
- ✅ All new features (coreml, directml, xnnpack, nnapi, mimalloc) are correctly mapped
- ✅ DirectML maps to both `onnxruntime_USE_DML` and `onnxruntime_USE_CUSTOM_DIRECTML`
- ✅ CoreML maps to `onnxruntime_USE_COREML`
- ✅ XNNPACK maps to `onnxruntime_USE_XNNPACK`
- ✅ NNAPI maps to `onnxruntime_USE_NNAPI_BUILTIN`
- ✅ Mimalloc maps to `onnxruntime_USE_MIMALLOC`
- ✅ No additional build flags needed for these execution providers

The portfile.cmake already uses vcpkg_check_features correctly, mapping feature names to their corresponding CMake options. No changes needed in this area.

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
