# onnxruntime
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/onnxruntime
    REF "v${VERSION}"
    SHA512 32310215a3646c64ff5e0a309c3049dbe02ae9dd5bda8c89796bd9f86374d0f43443aed756b941d9af20ef1758bb465981ac517bbe8ac33661a292d81c59b152
    HEAD_REF main
)

# --- Find Python (Host Dependency) ---
# vcpkg_find_acquire_program(PYTHON3) ensures Python is found/acquired
# and its directory is added to the PATH for subsequent process execution.
# PYTHON3 will hold the full path to the Python executable.
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

# 1. --build_shared_lib / --build_static_lib (from vcpkg linkage)
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    list(APPEND ONNXRUNTIME_BUILD_ARGS --build_static_lib)
else()
    list(APPEND ONNXRUNTIME_BUILD_ARGS --build_shared_lib)
endif()

# 2. --parallel (from feature)
if(ENABLE_PARALLEL)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --parallel)
endif()

# 3. --use_dml (from feature)
if(ENABLE_DML)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --use_dml)
endif()

# 4. --use_cuda (from feature)
if(ENABLE_CUDA)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --use_cuda)
endif()

# 5. --use_openvino (from feature)
if(ENABLE_OPENVINO)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --use_openvino)
endif()

# 6. --use_coreml (from feature)
if(ENABLE_COREML)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --use_coreml)
endif()

# 7. --use_tensorrt (from feature)
if(ENABLE_TENSORRT)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --use_tensorrt)
endif()

# 8. --compile_no_warning_as_error (from feature)
if(ENABLE_COMPILE_NO_WARNING_AS_ERROR)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --compile_no_warning_as_error)
endif()

# 9. --skip_submodule_sync / --update (from feature)
if(ENABLE_SKIP_SUBMODULE_SYNC)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --skip_submodule_sync)
else()
    list(APPEND ONNXRUNTIME_BUILD_ARGS --update) # Ensure submodules are updated if not skipping sync
endif()

# 11. --skip_tests (from feature) - Note: build.py uses --skip_tests
if(ENABLE_SKIP_TESTS)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --skip_tests)
endif()

# --- Platform-specific CMake definitions for build.py's --cmake_extra_defines ---
set(CMAKE_EXTRA_DEFINES_STRING "")

# 10. macOS Universal Architecture
if(VCPKG_TARGET_IS_OSX)
    set(CMAKE_EXTRA_DEFINES_STRING "CMAKE_OSX_ARCHITECTURES=x86_64;arm64")
endif()

# Toolchain file for non-Windows (Linux, macOS, etc.)
if(NOT VCPKG_TARGET_IS_WINDOWS)
    if(CMAKE_EXTRA_DEFINES_STRING STREQUAL "")
        set(CMAKE_EXTRA_DEFINES_STRING "CMAKE_TOOLCHAIN_FILE=${VCPKG_CHAINLOAD_TOOLCHAIN_FILE}")
    else()
        string(APPEND CMAKE_EXTRA_DEFINES_STRING " CMAKE_TOOLCHAIN_FILE=${VCPKG_CHAINLOAD_TOOLCHAIN_FILE}")
    endif()
endif()

# Add the consolidated --cmake_extra_defines to ONNXRUNTIME_BUILD_ARGS if not empty
if(NOT CMAKE_EXTRA_DEFINES_STRING STREQUAL "")
    list(APPEND ONNXRUNTIME_BUILD_ARGS --cmake_extra_defines "${CMAKE_EXTRA_DEFINES_STRING}")
endif()

# Add --use_vcpkg for Windows (specific to onnxruntime's build.py)
if(VCPKG_TARGET_IS_WINDOWS)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --use_vcpkg)
endif()


# --- Add required general arguments for build.py and vcpkg integration ---
list(APPEND ONNXRUNTIME_BUILD_ARGS --build) # Trigger the build

# Determine the build configuration
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(ONNXRUNTIME_CONFIG Debug)
else()
    set(ONNXRUNTIME_CONFIG RelWithDebInfo) # Or Release, depending on preference
endif()
list(APPEND ONNXRUNTIME_BUILD_ARGS --config ${ONNXRUNTIME_CONFIG})
set(ONNXRUNTIME_BUILD_DIR_PATH "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}")

# Clean the directory before use to prevent stale cache issues
file(REMOVE_RECURSE "${ONNXRUNTIME_BUILD_DIR_PATH}")
list(APPEND ONNXRUNTIME_BUILD_ARGS --build_dir "${ONNXRUNTIME_BUILD_DIR_PATH}")

# --- Execute Build by calling build.py directly ---
set(PYTHON_BUILD_SCRIPT_PATH "${SOURCE_PATH}/tools/ci_build/build.py")

message(STATUS "ONNXRuntime build.py arguments: ${ONNXRUNTIME_BUILD_ARGS}")

vcpkg_execute_build_process(
    COMMAND "${PYTHON3}" "${PYTHON_BUILD_SCRIPT_PATH}" ${ONNXRUNTIME_BUILD_ARGS}
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME "build-py-${TARGET_TRIPLET}-${ONNXRUNTIME_CONFIG}"
)

# --- Post-Build Processing ---
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(PACKAGE_NAME onnxruntime CONFIG_PATH "lib/cmake/onnxruntime")
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")
vcpkg_install_copyright(FILE_PATH "${SOURCE_PATH}/LICENSE")

# Create a usage file
file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/usage"
    "To use onnxruntime in your CMake project, add the following to your CMakeLists.txt:\n"
    "    find_package(onnxruntime CONFIG REQUIRED)\n"
    "    target_link_libraries(your_target PRIVATE onnxruntime::onnxruntime)\n"
    "\n"
    "Replace 'your_target' with the name of your executable or library.\n"
)

message(STATUS "onnxruntime build and installation complete.")