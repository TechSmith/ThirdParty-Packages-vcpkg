# whispercpp-noavx
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggerganov/whisper.cpp
    REF "v${VERSION}"
    SHA512 7e0ec9d6afe234afaaa83d7d69051504252c27ecdacbedf3d70992429801bcd1078794a0bb76cf4dafb74131dd0f506bd24c3f3100815c35b8ac2b12336492ef
    HEAD_REF master
    PATCHES
        0001-BuildGgmlAsStatic.patch
)

set(VCPKG_POLICY_SKIP_MISPLACED_CMAKE_FILES_CHECK enabled)
set(VCPKG_POLICY_SKIP_LIB_CMAKE_MERGE_CHECK enabled)

# Make git path available for the whispercpp project cmake files
vcpkg_find_acquire_program(GIT)
get_filename_component(GIT_DIR "${GIT}" DIRECTORY)
vcpkg_add_to_path("${GIT_DIR}")

if(VCPKG_HOST_IS_OSX)
    vcpkg_cmake_configure(
        SOURCE_PATH ${SOURCE_PATH}
        OPTIONS
            -DGGML_AVX=OFF
            -DGGML_AVX2=OFF
            -DGGML_FMA=OFF
            -DGGML_F16C=OFF
            -DGGML_METAL=OFF
    )
else()
    vcpkg_cmake_configure(
        SOURCE_PATH ${SOURCE_PATH}
        OPTIONS
            -DWHISPER_AVX=OFF
            -DWHISPER_AVX2=OFF
            -DWHISPER_AVX512=OFF
            -DWHISPER_FMA=OFF
)
endif()

vcpkg_install_cmake()
vcpkg_copy_pdbs()

# Store all .libs in the root lib directory.  For Windows SHARED builds, these will be import libraries (not static libs).
file(GLOB_RECURSE LIB_FILES "${CURRENT_PACKAGES_DIR}/lib/static/*.lib")
foreach(LIB_FILE ${LIB_FILES})
    get_filename_component(LIB_NAME ${LIB_FILE} NAME)
    file(RENAME ${LIB_FILE} "${CURRENT_PACKAGES_DIR}/lib/${LIB_NAME}")
endforeach()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/lib/static")

# If debug build, move things up a level and remove debug folder
if(VCPKG_BUILD_TYPE STREQUAL "debug")
    if(EXISTS "${CURRENT_PACKAGES_DIR}/debug")
        file(COPY "${CURRENT_PACKAGES_DIR}/debug/" DESTINATION "${CURRENT_PACKAGES_DIR}")
        file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
    endif()
endif()

# Move tools to proper directory
vcpkg_copy_tools(
    TOOL_NAMES
        vad-speech-segments
        whisper-bench
        whisper-cli
        whisper-server
    AUTO_CLEAN
)

file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)

vcpkg_fixup_pkgconfig()
