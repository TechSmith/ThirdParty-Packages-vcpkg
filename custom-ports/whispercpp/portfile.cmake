if("cpu-acceleration" IN_LIST FEATURES)
    SET(FEATURE_CPU_ACCELERATION ON)
endif()

if(FEATURE_CPU_ACCELERATION)
    list(APPEND FEATURE_PATCH_LIST "0001-UpdateTargetName-whisper-cpuaccel.patch")
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggerganov/whisper.cpp
    REF "v${VERSION}"
    SHA512 7e0ec9d6afe234afaaa83d7d69051504252c27ecdacbedf3d70992429801bcd1078794a0bb76cf4dafb74131dd0f506bd24c3f3100815c35b8ac2b12336492ef
    HEAD_REF master
    PATCHES
        ${FEATURE_PATCH_LIST}
)

set(VCPKG_POLICY_SKIP_MISPLACED_CMAKE_FILES_CHECK enabled)

# Make git path available for the whispercpp project cmake files
vcpkg_find_acquire_program(GIT)
get_filename_component(GIT_DIR "${GIT}" DIRECTORY)
vcpkg_add_to_path("${GIT_DIR}")

# CMake configure
# set(CONFIG_OPTIONS
#     -DWHISPER_BUILD_EXAMPLES=OFF
#     -DWHISPER_BUILD_TESTS=OFF
#     -DWHISPER_BUILD_SERVER=OFF
# )
if(VCPKG_HOST_IS_OSX)
    list(APPEND CONFIG_OPTIONS
        -DGGML_METAL_EMBED_LIBRARY=ON
        -DGGML_METAL_NDEBUG=ON
        -DGGML_METAL=${FEATURE_CPU_ACCELERATION}
    )
endif()
list(APPEND CONFIG_OPTIONS
    -DGGML_AVX=${FEATURE_CPU_ACCELERATION}
    -DGGML_AVX2=${FEATURE_CPU_ACCELERATION}
    -DGGML_FMA=${FEATURE_CPU_ACCELERATION}
    -DGGML_F16C=${FEATURE_CPU_ACCELERATION}
)
message(STATUS ">> Using CONFIG_OPTIONS: ${CONFIG_OPTIONS}")
vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        ${CONFIG_OPTIONS}
)

# CMake Build & install
vcpkg_cmake_install()

# Other packaging steps
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/whisper)
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/ggml)
vcpkg_fixup_pkgconfig()
vcpkg_copy_pdbs()
vcpkg_install_copyright(FILE_LIST ${SOURCE_PATH}/LICENSE)
