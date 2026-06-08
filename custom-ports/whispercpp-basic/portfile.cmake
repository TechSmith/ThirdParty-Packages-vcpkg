# whispercpp-noavx
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggerganov/whisper.cpp
    REF "v${VERSION}"
    SHA512 f686f7e4cb7a0c8d5734c21bbe7ba5225c559007a8ab91a14a140e22f9fbe2353ae19df6a4306fb85737ff2dc698804e4c626085bf951cde60123cfd2d0ae8a1
    HEAD_REF master
    PATCHES
        0001-BuildGgmlAsStatic.patch
        0002-UpdateTargetName.patch
)

set(VCPKG_POLICY_SKIP_MISPLACED_CMAKE_FILES_CHECK enabled)
set(VCPKG_POLICY_SKIP_LIB_CMAKE_MERGE_CHECK enabled)

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
            -DGGML_AVX=OFF
            -DGGML_AVX2=OFF
            -DGGML_FMA=OFF
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

file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)

vcpkg_fixup_pkgconfig()
