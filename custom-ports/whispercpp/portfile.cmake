# whispercpp
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggerganov/whisper.cpp
    REF "v${VERSION}"
    SHA512 35efd976f60261e108972e3af7b322d723e36be30f5265db3be63752caaed0b52b9da3ece02975da2b83ff30f1eb32663e77fbaaf15f3037e35a525939071c0b
    HEAD_REF master
)

set(VCPKG_POLICY_SKIP_MISPLACED_CMAKE_FILES_CHECK enabled)
set(VCPKG_POLICY_SKIP_LIB_CMAKE_MERGE_CHECK enabled)

if(VCPKG_HOST_IS_OSX)
    vcpkg_cmake_configure(
        SOURCE_PATH ${SOURCE_PATH}
        OPTIONS
            -DGGML_METAL_EMBED_LIBRARY=ON
            -DGGML_METAL_NDEBUG=ON
    )
else()
    vcpkg_cmake_configure(
        SOURCE_PATH ${SOURCE_PATH}
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