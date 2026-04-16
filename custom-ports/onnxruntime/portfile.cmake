# onnxruntime
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/onnxruntime
    REF "v${VERSION}"
    SHA512 373c51575ada457b8aead5d195a5f3eba62fb747b6370a2a9889fff875c40ea30af8fd49104d58cc86f79247410e829086b0979f37ca8635c6dd34960e9cc424
    HEAD_REF main
    PATCHES
        "1000-tsc-accept-python-path.patch"
        "1002-tsc-accept-python-path-unix.patch"
        "1003-tsc-skip-emsdk-install-if-env-set.patch"
)

# --- Find Python (Host Dependency) ---
vcpkg_find_acquire_program(PYTHON3)
message(STATUS "Using Python3 from: ${PYTHON3}")


# --- Check for enabled features ---
vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        "build-parallel"                ENABLE_PARALLEL
        "ep-dml"                        ENABLE_DML
        "ep-cuda"                       ENABLE_CUDA
        "ep-openvino"                   ENABLE_OPENVINO
        "ep-coreml"                     ENABLE_COREML
        "ep-tensorrt"                   ENABLE_TENSORRT
        "compile-no-warning-as-error"   ENABLE_COMPILE_NO_WARNING_AS_ERROR
        "skip-submodule-sync"           ENABLE_SKIP_SUBMODULE_SYNC
        "skip-tests"                    ENABLE_SKIP_TESTS
)

# --- Assemble Build Arguments for build.py ---
set(ONNXRUNTIME_BUILD_ARGS)

# Platform-specific configurations
if(VCPKG_TARGET_IS_EMSCRIPTEN)
    # WASM-specific build arguments
    # Build static library first, then wrap it as SIDE_MODULE
    list(APPEND ONNXRUNTIME_BUILD_ARGS 
        --build_wasm
        --build_wasm_static_lib
        --skip_submodule_sync
        --disable_wasm_exception_catching
        --disable_rtti
    )
elseif(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    list(APPEND ONNXRUNTIME_BUILD_ARGS --build_static_lib)
else()
    list(APPEND ONNXRUNTIME_BUILD_ARGS --build_shared_lib)
endif()

if(ENABLE_PARALLEL)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --parallel)
endif()
if(ENABLE_DML)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --use_dml)
endif()
if(ENABLE_CUDA)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --use_cuda)
endif()
if(ENABLE_OPENVINO)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --use_openvino)
endif()
if(ENABLE_COREML)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --use_coreml)
endif()
if(ENABLE_TENSORRT)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --use_tensorrt)
endif()
if(ENABLE_COMPILE_NO_WARNING_AS_ERROR)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --compile_no_warning_as_error)
endif()
if(ENABLE_SKIP_SUBMODULE_SYNC)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --skip_submodule_sync)
else()
    list(APPEND ONNXRUNTIME_BUILD_ARGS --update)
endif()
if(ENABLE_SKIP_TESTS)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --skip_tests)
endif()

# Add macOS Universal Architecture if applicable
if(VCPKG_TARGET_IS_OSX)
    string(APPEND CMAKE_EXTRA_DEFINES_STRING " CMAKE_OSX_ARCHITECTURES=x86_64;arm64")
endif()

# Add WASM-specific CMake defines
if(VCPKG_TARGET_IS_EMSCRIPTEN)
    list(APPEND ONNXRUNTIME_BUILD_ARGS 
        --cmake_extra_defines
        CMAKE_TOOLCHAIN_FILE=${VCPKG_CHAINLOAD_TOOLCHAIN_FILE}
        onnxruntime_ENABLE_WEBASSEMBLY_SIMD=ON
        onnxruntime_ENABLE_WEBASSEMBLY_THREADS=ON
    )
endif()

# --- Add required general arguments for build.py ---
#list(APPEND ONNXRUNTIME_BUILD_ARGS --build)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(ONNXRUNTIME_CONFIG Debug)
else()
    set(ONNXRUNTIME_CONFIG RelWithDebInfo)
endif()
list(APPEND ONNXRUNTIME_BUILD_ARGS --config ${ONNXRUNTIME_CONFIG})

# # Define the build directory WITHOUT the config suffix. The script adds it.
# set(ONNXRUNTIME_BUILD_DIR_PATH "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}")

# # Clean the directory to prevent stale cache issues
# file(REMOVE_RECURSE "${ONNXRUNTIME_BUILD_DIR_PATH}")
# list(APPEND ONNXRUNTIME_BUILD_ARGS --build_dir "${ONNXRUNTIME_BUILD_DIR_PATH}")

# --- Execute Build ---
if(VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_EMSCRIPTEN)
    set(BUILD_SCRIPT_PATH "${SOURCE_PATH}/build.bat")
    message(STATUS ">>> ONNXRuntime build.bat arguments: ${ONNXRUNTIME_BUILD_ARGS}")
    message(STATUS ">>> SOURCE PATH: ${SOURCE_PATH}")
    
    vcpkg_execute_build_process(
        COMMAND "${BUILD_SCRIPT_PATH}" "${PYTHON3}" ${ONNXRUNTIME_BUILD_ARGS}
        WORKING_DIRECTORY "${SOURCE_PATH}"
        LOGNAME "build-${TARGET_TRIPLET}-${ONNXRUNTIME_CONFIG}"
    )
else()
    # Use build.sh for Unix-like systems (macOS, Linux, WASM)
    set(BUILD_SCRIPT_PATH "${SOURCE_PATH}/build.sh")
    message(STATUS ">>> ONNXRuntime build.sh arguments: ${PYTHON3} ${ONNXRUNTIME_BUILD_ARGS}")
    message(STATUS ">>> SOURCE PATH: ${SOURCE_PATH}")
    
    vcpkg_execute_build_process(
        COMMAND ${BUILD_SCRIPT_PATH} ${PYTHON3} ${ONNXRUNTIME_BUILD_ARGS}
        WORKING_DIRECTORY "${SOURCE_PATH}"
        LOGNAME "build-${TARGET_TRIPLET}-${ONNXRUNTIME_CONFIG}"
    )
endif()

# --- Build SIDE_MODULE Wrapper for WASM ---
if(VCPKG_TARGET_IS_EMSCRIPTEN)
    message(STATUS "Building SIDE_MODULE wrapper for ONNX Runtime WASM")
    
    # Determine build output directory for the static lib
    # Note: ONNX Runtime uses the host OS name (MacOS/Linux) even for WASM builds
    if(VCPKG_HOST_IS_WINDOWS)
        set(BUILD_OUTPUT_DIR "${SOURCE_PATH}/build/Windows/${ONNXRUNTIME_CONFIG}")
    elseif(VCPKG_HOST_IS_OSX)
        set(BUILD_OUTPUT_DIR "${SOURCE_PATH}/build/MacOS/${ONNXRUNTIME_CONFIG}")
    else()
        set(BUILD_OUTPUT_DIR "${SOURCE_PATH}/build/Linux/${ONNXRUNTIME_CONFIG}")
    endif()
    message(STATUS "ONNX Runtime static lib location: ${BUILD_OUTPUT_DIR}/libonnxruntime_webassembly.a")
    
    # Verify the static library was built
    if(NOT EXISTS "${BUILD_OUTPUT_DIR}/libonnxruntime_webassembly.a")
        message(FATAL_ERROR "ONNX Runtime static library not found at: ${BUILD_OUTPUT_DIR}/libonnxruntime_webassembly.a")
    endif()
    
    # Deduplicate the static library archive (ONNX Runtime's bundle creates duplicates)
    message(STATUS "Deduplicating static library archive...")
    
    # Use Emscripten's emar for LLVM-format archives (system ar cannot handle them)
    set(EMAR "$ENV{EMSDK}/upstream/emscripten/emar")
    
    set(TEMP_EXTRACT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}/temp-extract")
    file(REMOVE_RECURSE "${TEMP_EXTRACT_DIR}")
    file(MAKE_DIRECTORY "${TEMP_EXTRACT_DIR}")
    
    # Extract all object files
    execute_process(
        COMMAND "${EMAR}" x "${BUILD_OUTPUT_DIR}/libonnxruntime_webassembly.a"
        WORKING_DIRECTORY "${TEMP_EXTRACT_DIR}"
        RESULT_VARIABLE AR_EXTRACT_RESULT
    )
    if(NOT AR_EXTRACT_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to extract static library")
    endif()
    
    # Get unique list of object files
    file(GLOB_RECURSE OBJECT_FILES "${TEMP_EXTRACT_DIR}/*.o")
    list(REMOVE_DUPLICATES OBJECT_FILES)
    
    # Create new archive with deduplicated objects
    set(DEDUP_LIBRARY "${BUILD_OUTPUT_DIR}/libonnxruntime_webassembly_dedup.a")
    execute_process(
        COMMAND "${EMAR}" rcs "${DEDUP_LIBRARY}" ${OBJECT_FILES}
        WORKING_DIRECTORY "${TEMP_EXTRACT_DIR}"
        RESULT_VARIABLE AR_CREATE_RESULT
    )
    if(NOT AR_CREATE_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to create deduplicated static library")
    endif()
    
    # Replace original with deduplicated version
    file(REMOVE "${BUILD_OUTPUT_DIR}/libonnxruntime_webassembly.a")
    file(RENAME "${DEDUP_LIBRARY}" "${BUILD_OUTPUT_DIR}/libonnxruntime_webassembly.a")
    message(STATUS "✓ Static library deduplicated")
    
    # Copy wrapper files to build directory
    set(WRAPPER_SOURCE_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}/wrapper-src")
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/wasm-wrapper/" DESTINATION "${WRAPPER_SOURCE_DIR}/")
    
    # Configure wrapper build
    set(WRAPPER_BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}/wrapper-build")
    
    vcpkg_cmake_configure(
        SOURCE_PATH "${WRAPPER_SOURCE_DIR}"
        OPTIONS
            -DONNX_BUILD_DIR=${BUILD_OUTPUT_DIR}
            -DCMAKE_BUILD_TYPE=${ONNXRUNTIME_CONFIG}
    )
    
    vcpkg_cmake_build()
    
    # The .so file should be in the wrapper build directory
    set(SIDE_MODULE_LIB "${WRAPPER_BUILD_DIR}/libonnxruntime.so")
    if(NOT EXISTS "${SIDE_MODULE_LIB}")
        message(FATAL_ERROR "SIDE_MODULE library not created at: ${SIDE_MODULE_LIB}")
    endif()
    
    message(STATUS "✓ SIDE_MODULE built successfully: ${SIDE_MODULE_LIB}")
endif()

# --- Post-Build Processing ---

# Determine build output directory (unless already set by wrapper build for WASM)
if(NOT DEFINED BUILD_OUTPUT_DIR)
    if(VCPKG_TARGET_IS_WINDOWS)
        set(BUILD_OUTPUT_DIR "${SOURCE_PATH}/build/Windows/${ONNXRUNTIME_CONFIG}")
    elseif(VCPKG_TARGET_IS_OSX)
        set(BUILD_OUTPUT_DIR "${SOURCE_PATH}/build/MacOS/${ONNXRUNTIME_CONFIG}")
    else()
        set(BUILD_OUTPUT_DIR "${SOURCE_PATH}/build/Linux/${ONNXRUNTIME_CONFIG}")
    endif()
endif()

message(STATUS "Looking for build artifacts in: ${BUILD_OUTPUT_DIR}")

# Install libraries
if(VCPKG_TARGET_IS_EMSCRIPTEN)
    # Install the SIDE_MODULE .so file (primary output for dynamic linking)
    if(NOT EXISTS "${SIDE_MODULE_LIB}")
        message(FATAL_ERROR "SIDE_MODULE library not found: ${SIDE_MODULE_LIB}")
    endif()
    file(INSTALL "${SIDE_MODULE_LIB}" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
    message(STATUS "Installed SIDE_MODULE: libonnxruntime.so")
    
    # Also install the bundled static library (for potential static builds or debugging)
    set(STATIC_LIB "${BUILD_OUTPUT_DIR}/libonnxruntime_webassembly.a")
    if(EXISTS "${STATIC_LIB}")
        file(INSTALL "${STATIC_LIB}" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
        message(STATUS "Installed static library: libonnxruntime_webassembly.a")
    else()
        message(WARNING "Static library not found at: ${STATIC_LIB}")
    endif()
else()
    # Desktop platforms: Install appropriate library types
    if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
        file(GLOB LIBS "${BUILD_OUTPUT_DIR}/*.lib" "${BUILD_OUTPUT_DIR}/*.a")
    else()
        file(GLOB LIBS 
            "${BUILD_OUTPUT_DIR}/*.lib"
            "${BUILD_OUTPUT_DIR}/*.so"
            "${BUILD_OUTPUT_DIR}/*.dylib"
            "${BUILD_OUTPUT_DIR}/*.dll"
        )
    endif()
    
    if(LIBS)
        file(INSTALL ${LIBS} DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
    endif()
    
    # Install debug libraries if building debug
    if(EXISTS "${BUILD_OUTPUT_DIR}/Debug")
        file(GLOB DEBUG_LIBS "${BUILD_OUTPUT_DIR}/Debug/*")
        if(DEBUG_LIBS)
            file(INSTALL ${DEBUG_LIBS} DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
        endif()
    endif()
endif()

# Install headers
file(INSTALL 
    "${SOURCE_PATH}/include/onnxruntime/core/session/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include/onnxruntime/core"
    FILES_MATCHING PATTERN "*.h"
)

# Install additional required headers
if(EXISTS "${SOURCE_PATH}/include/onnxruntime/core/providers")
    file(INSTALL 
        "${SOURCE_PATH}/include/onnxruntime/core/providers/"
        DESTINATION "${CURRENT_PACKAGES_DIR}/include/onnxruntime/core/providers"
        FILES_MATCHING PATTERN "*.h"
    )
endif()

# Install CMake config if available
if(EXISTS "${BUILD_OUTPUT_DIR}/onnxruntime-config.cmake")
    file(INSTALL 
        "${BUILD_OUTPUT_DIR}/onnxruntime-config.cmake"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
    )
    vcpkg_cmake_config_fixup(PACKAGE_NAME onnxruntime CONFIG_PATH "share/${PORT}")
endif()

# Install license
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")

# Remove debug headers (not needed)
if(EXISTS "${CURRENT_PACKAGES_DIR}/debug/include")
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
endif()

# Copy PDBs for Windows debugging
if(VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_EMSCRIPTEN)
    vcpkg_copy_pdbs()
endif()

message(STATUS "✓ onnxruntime ${VERSION} installation complete for ${TARGET_TRIPLET}")