# helloworld-meson
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mike-malburg/helloworld-meson
    REF "d8f1be526a4116d889bf7b60841d878d961cb851"
    SHA512 f8bf85e4a42ed30208632be1457bc3bf03bcafe6d77680362f8d36b6f49c538f1b95b0ffb4e0f847c4285b77d1ba1dc0989bc450cdec38ac0dd23e22ce51928b
    HEAD_REF main
)

vcpkg_configure_meson(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${OPTIONS}
)
vcpkg_install_meson()

# For some reason, the meson install is not copying the files to the package directory
set(HELLOWORLD_MESON_BUILDTREE_DIR_RELEASE "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
if(VCPKG_TARGET_IS_WINDOWS)
    file(GLOB BIN_FILES "${HELLOWORLD_MESON_BUILDTREE_DIR_RELEASE}/*.dll" "${HELLOWORLD_MESON_BUILDTREE_DIR_RELEASE}/*.pdb")
    foreach(BIN_FILE ${BIN_FILES})
        file(COPY "${BIN_FILE}" DESTINATION "${CURRENT_PACKAGES_DIR}/bin/")
    endforeach()
endif()

file(GLOB LIB_FILES "${HELLOWORLD_MESON_BUILDTREE_DIR_RELEASE}/*.lib" "${HELLOWORLD_MESON_BUILDTREE_DIR_RELEASE}/*.dylib" "${HELLOWORLD_MESON_BUILDTREE_DIR_RELEASE}/*.a")
foreach(LIB_FILE ${LIB_FILES})
    file(COPY "${LIB_FILE}" DESTINATION "${CURRENT_PACKAGES_DIR}/lib/")
endforeach()

vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig()
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
