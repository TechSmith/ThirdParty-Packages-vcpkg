# onnxruntime
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/onnxruntime
    REF "v${VERSION}"
    SHA512 32310215a3646c64ff5e0a309c3049dbe02ae9dd5bda8c89796bd9f86374d0f43443aed756b941d9af20ef1758bb465981ac517bbe8ac33661a292d81c59b152
    HEAD_REF main
)

# --- Check for enabled features ---
# These variables will be set to ON if the corresponding feature is enabled in vcpkg.json
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

# --- Assemble Build Arguments based on features and vcpkg settings ---
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

# 3. --use_directml (from feature, note: script uses --use_directml, not --use_dml)
if(ENABLE_DML)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --use_directml)
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

# 9. --skip_submodule_sync (from feature)
if(ENABLE_SKIP_SUBMODULE_SYNC)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --skip_submodule_sync)
else()
    # The --update flag in the build script ensures submodules are initialized.
    # We only add it if we are NOT skipping the sync.
    list(APPEND ONNXRUNTIME_BUILD_ARGS --update)
endif()

# 10. macOS Universal Architecture defines
if(VCPKG_TARGET_IS_OSX)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --cmake_extra_defines "CMAKE_OSX_ARCHITECTURES=x86_64;arm64")
endif()

# 11. --skip_tests (from feature, mapped to correct flag)
if(ENABLE_SKIP_TESTS)
    list(APPEND ONNXRUNTIME_BUILD_ARGS --skip_tests)
endif()

# --- Add required arguments for vcpkg integration ---

# The --build flag is required to trigger the build step in the script.
list(APPEND ONNXRUNTIME_BUILD_ARGS --build)

# Determine build configuration (Debug/Release)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(ONNXRUNTIME_CONFIG Debug)
else()
    set(ONNXRUNTIME_CONFIG RelWithDebInfo)
endif()
list(APPEND ONNXRUNTIME_BUILD_ARGS --config ${ONNXRUNTIME_CONFIG})

# Define a build directory for intermediate files
set(ONNXRUNTIME_BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-${ONNXRUNTIME_CONFIG}")
list(APPEND ONNXRUNTIME_BUILD_ARGS --build_dir "${ONNXRUNTIME_BUILD_DIR}")

# Set the final installation prefix
list(APPEND ONNXRUNTIME_BUILD_ARGS --cmake_install_prefix "${CURRENT_PACKAGES_DIR}")


# --- Select Script and Execute Build ---
if(VCPKG_TARGET_IS_WINDOWS)
    set(BUILD_SCRIPT "${SOURCE_PATH}/build.bat")
    # Tell onnxruntime to use dependencies from vcpkg
    list(APPEND ONNXRUNTIME_BUILD_ARGS --use_vcpkg)
else() # Linux or macOS
    set(BUILD_SCRIPT "${SOURCE_PATH}/build.sh")
    # Pass the vcpkg toolchain file to ensure correct compiler and flags are used
    list(APPEND ONNXRUNTIME_BUILD_ARGS --cmake_extra_defines "CMAKE_TOOLCHAIN_FILE=${VCPKG_CHAINLOAD_TOOLCHAIN_FILE}")
endif()

# Execute the build script with all configured arguments
vcpkg_execute_build_process(
    COMMAND "${BUILD_SCRIPT}" ${ONNXRUNTIME_BUILD_ARGS}
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME "build-${TARGET_TRIPLET}-${ONNXRUNTIME_CONFIG}"
)

# --- Post-Build Processing ---
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(PACKAGE_NAME onnxruntime CONFIG_PATH "lib/cmake/onnxruntime")
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")
vcpkg_install_copyright(FILE_PATH "${SOURCE_PATH}/LICENSE")
