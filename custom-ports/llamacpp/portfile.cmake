# llamacpp
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggml-org/llama.cpp
    REF 1920345c3bcec451421bb6abc4981678cc721154 # https://github.com/ggml-org/llama.cpp/releases/tag/b7097
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
            -DBUILD_SHARED_LIBS=ON
    )
else()
    vcpkg_cmake_configure(
        SOURCE_PATH ${SOURCE_PATH}
        OPTIONS
            -DBUILD_SHARED_LIBS=ON
            -DGGML_CUDA=ON
            -DGGML_CUDA_GRAPHS=ON
            -DLLAMA_BUILD_COMMON=ON
            -DLLAMA_BUILD_TOOLS=ON
            -DLLAMA_BUILD_SERVER=ON
            -DLLAMA_HTTPLIB=ON
            -DLLAMA_CURL=OFF
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
