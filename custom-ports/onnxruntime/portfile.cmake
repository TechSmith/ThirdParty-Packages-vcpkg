# onnxruntime
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/onnxruntime
    REF "v${VERSION}"
    SHA512 32310215a3646c64ff5e0a309c3049dbe02ae9dd5bda8c89796bd9f86374d0f43443aed756b941d9af20ef1758bb465981ac517bbe8ac33661a292d81c59b152
    HEAD_REF main
    PATCHES
        "1000-tsc-accept-python-path.patch"
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

if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
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
set(BUILD_SCRIPT_PATH "${SOURCE_PATH}/build.bat")
message(STATUS ">>> ONNXRuntime build.bat arguments: ${ONNXRUNTIME_BUILD_ARGS}")

message(STATUS ">>> SOURCE PATH: ${SOURCE_PATH}")

vcpkg_execute_build_process(
    COMMAND "${BUILD_SCRIPT_PATH}" "${PYTHON3}" ${ONNXRUNTIME_BUILD_ARGS}
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME "build-${TARGET_TRIPLET}-${ONNXRUNTIME_CONFIG}"
)

# # --- Post-Build Processing ---
# vcpkg_copy_pdbs()
# vcpkg_cmake_config_fixup(PACKAGE_NAME onnxruntime CONFIG_PATH "lib/cmake/onnxruntime")
# vcpkg_fixup_pkgconfig()
# file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")
# vcpkg_install_copyright(FILE_PATH "${SOURCE_PATH}/LICENSE")
# file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/usage"
#     "To use onnxruntime in your CMake project, add the following to your CMakeLists.txt:\n"
#     "    find_package(onnxruntime CONFIG REQUIRED)\n"
#     "    target_link_libraries(your_target PRIVATE onnxruntime::onnxruntime)\n"
# )

# message(STATUS "onnxruntime build and installation complete.")