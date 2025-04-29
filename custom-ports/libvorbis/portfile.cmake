vcpkg_from_gitlab(
    OUT_SOURCE_PATH SOURCE_PATH
    GITLAB_URL https://gitlab.xiph.org
    REPO xiph/vorbis
    REF 2eac96b03ff67953354cb0a649c08aa3a23267ef
    SHA512 e0b6ad9ae1216702232124028db8e4a0c049494a118a885b8db815314dd652b53c749e48f7bd8bddd04c01bef4f94574b26e1423d1be0b6bf9ff1f2e8f36ae9d
    HEAD_REF master
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DCMAKE_POLICY_VERSION_MINIMUM=3.6 # https://github.com/xiph/vorbis/issues/113
    MAYBE_UNUSED_VARIABLES
        CMAKE_POLICY_VERSION_MINIMUM
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME Vorbis CONFIG_PATH "lib/cmake/Vorbis")
vcpkg_fixup_pkgconfig()
vcpkg_copy_pdbs()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
file(INSTALL "${SOURCE_PATH}/COPYING" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)