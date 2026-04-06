# CoreML Support for onnxruntime on macOS

## Current Status

CoreML has been **disabled as a default feature** due to conflicts between onnxruntime's FetchContent-based build system and vcpkg's dependency management.

## The Problem

When CoreML is enabled on macOS, the build fails with:
```
CMake Error at external/protobuf_function.cmake:95 (message):
  Error: onnxruntime_protobuf_generate could not find any .proto files
Call Stack (most recent call first):
  onnxruntime_providers_coreml.cmake:36 (onnxruntime_protobuf_generate)
```

### Root Cause Analysis

1. **CoreML Provider Needs Protobuf Code Generation**
   - CoreML execution provider uses `onnxruntime_protobuf_generate()` at cmake configure time
   - This function is defined in `external/protobuf_function.cmake`
   - It expects to find `.proto` files to generate C++ code for CoreML model definitions

2. **FetchContent vs vcpkg Conflict**
   - onnxruntime uses CMake FetchContent to download and configure dependencies
   - vcpkg sets `FETCHCONTENT_FULLY_DISCONNECTED=ON` by default to prevent downloads
   - With disconnected mode, FetchContent cmake files don't set up necessary variables
   - Without these variables, `onnxruntime_protobuf_generate()` can't locate proto files

3. **Attempted Fix #1: FETCHCONTENT_FULLY_DISCONNECTED=OFF**
   - Setting this to OFF allows FetchContent cmake setup to run
   - **Result**: Windows build fails with "Some targets already defined" error
   - **Cause**: FetchContent tries to define abseil targets that vcpkg already defined
   - **Conclusion**: This approach creates more problems than it solves

4. **Current Fix: Disable CoreML Default Feature**
   - Removes CoreML from default-features for macOS in vcpkg.json
   - Allows Windows, Linux, and WASM builds to succeed
   - Users can still explicitly enable CoreML, but build will fail without additional patches

## What Would Be Needed to Enable CoreML

To properly support CoreML with vcpkg, the following changes are required:

### Option 1: Patch CoreML Provider (Recommended)

Create a patch that modifies `onnxruntime_providers_coreml.cmake` to work with vcpkg:

1. **Skip FetchContent Dependencies**
   - Add early return when `onnxruntime_USE_VCPKG=ON`
   - Similar to what we did for abseil (but we removed that patch)

2. **Provide Proto Files Directly**
   - Identify which `.proto` files CoreML needs
   - Locate them in the onnxruntime source tree
   - Pass absolute paths to `onnxruntime_protobuf_generate()`
   - Example:
     ```cmake
     if(onnxruntime_USE_VCPKG)
       # When using vcpkg, provide proto files directly
       set(COREML_PROTO_FILES
         "${CMAKE_CURRENT_SOURCE_DIR}/../onnxruntime/core/providers/coreml/model.proto"
       )
       onnxruntime_protobuf_generate(
         TARGET coreml_proto
         PROTOS ${COREML_PROTO_FILES}
         # ... other arguments
       )
     else()
       # Original FetchContent-based approach
       # ... existing code
     endif()
     ```

3. **Fix Protobuf Dependencies**
   - Ensure vcpkg's protobuf package provides all needed components
   - May need to add protobuf compiler (protoc) paths explicitly

### Option 2: Conditional FetchContent (Complex)

Create a more sophisticated patch that:

1. **Prevents Duplicate Target Definitions**
   - Patch all `external/*.cmake` files to check if targets already exist
   - Only define targets if they don't exist from vcpkg
   - Example:
     ```cmake
     if(onnxruntime_USE_VCPKG AND TARGET absl::strings)
       # Target already exists from vcpkg, skip FetchContent
       return()
     endif()
     ```

2. **Allow Selective FetchContent**
   - Keep `FETCHCONTENT_FULLY_DISCONNECTED=OFF`
   - But patch each external dependency to use vcpkg's version
   - Let only the setup/configuration code run, not the actual downloads

3. **Coordinate with vcpkg**
   - Ensure all FetchContent dependencies have vcpkg equivalents
   - Map FetchContent target names to vcpkg target names

**Challenges**:
- Requires patching many cmake files (abseil, protobuf, re2, etc.)
- High maintenance burden when updating onnxruntime versions
- Risk of subtle bugs from FetchContent/vcpkg interactions

### Option 3: Disable Protobuf Generation (Simplest, Limited)

If CoreML proto files are optional or have pregenerated versions:

1. Check if onnxruntime ships pregenerated protobuf C++ files
2. Patch CoreML cmake to use pregenerated files when using vcpkg
3. Skip the `onnxruntime_protobuf_generate()` call entirely

**Note**: This likely won't work because CoreML probably requires runtime protobuf generation.

## Investigation Steps

To implement Option 1 (recommended), investigate:

1. **Find Proto Files**:
   ```bash
   # In onnxruntime source tree
   find . -name "*.proto" -path "*/coreml/*"
   ```

2. **Understand onnxruntime_protobuf_generate()**:
   ```bash
   # Read the function implementation
   cat external/protobuf_function.cmake
   ```

3. **Check What Variables Are Missing**:
   - Add debug output in protobuf_function.cmake
   - Run build with CoreML enabled
   - See what variables need to be set

4. **Test Minimal Patch**:
   - Create patch with vcpkg-specific proto file paths
   - Test on macOS build agent
   - Verify CoreML functionality works at runtime

## Recommendation

**For now**: Keep CoreML disabled as a default feature. The current onnxruntime port configuration is correct (`coreml onnxruntime_USE_COREML` mapping in portfile.cmake), but the upstream build system isn't vcpkg-friendly.

**Future work**: If CoreML support is needed:
1. Investigate onnxruntime source to find exact proto files needed
2. Create comprehensive patch for `onnxruntime_providers_coreml.cmake`
3. Test thoroughly on macOS with real CoreML workloads
4. Consider upstreaming fixes to onnxruntime project (add `-DONNXRUNTIME_USE_SYSTEM_DEPENDENCIES=ON` support)

## Related Files

- `custom-ports/onnxruntime/vcpkg.json` - Feature definitions
- `custom-ports/onnxruntime/portfile.cmake` - Build configuration
- `custom-ports/onnxruntime/fix-cmake.patch` - Current patches
- Upstream: `cmake/onnxruntime_providers_coreml.cmake` - CoreML provider cmake
- Upstream: `cmake/external/protobuf_function.cmake` - Protobuf generation function
