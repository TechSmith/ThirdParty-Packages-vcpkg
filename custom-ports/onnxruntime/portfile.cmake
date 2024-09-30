# onnxruntime
vcpkg_from_git(
    OUT_SOURCE_PATH SOURCE_PATH
    URL https://github.com/microsoft/onnxruntime
    REF "f217402897f40ebba457e2421bc0a4702771968e"
    HEAD_REF master
)

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}/cmake
    OPTIONS
        # This tells vcpkg to NOT set FETCHCONTENT_FULLY_DISCONNECTED,
        # allowing ONNX Runtime's build system to download its dependencies.
        "-DCMAKE_POLICY_DEFAULT_CMP0135=NEW" # Often needed with modern FetchContent
    DISABLE_PARALLEL_CONFIGURE # ONNX Runtime's configure step can be resource intensive
                               # and sometimes has issues with parallel FetchContent downloads.
                               # Try removing this if configure times are too long and it seems stable.
)


vcpkg_install_cmake()
vcpkg_copy_pdbs()
file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)
vcpkg_fixup_pkgconfig()