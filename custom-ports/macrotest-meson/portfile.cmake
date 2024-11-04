# macrotest-meson
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mike-malburg/macrotest-meson
    REF main
    SHA512 54a3181f3ba1f80e211c5f1e99ef0bd72229459af2ccb1d821195f7dbe37008333ddd1674f44c16317a27eaae4c44e50ce0d36853bf3c295bfd5ec9a78eb01bb
    HEAD_REF main
)

set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

vcpkg_configure_meson(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_install_meson()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig()
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")

# Move main exe to tools dir
vcpkg_copy_tools(
    TOOL_NAMES macrotest-meson
    SEARCH_DIR ${CURRENT_PACKAGES_DIR}/bin
    DESTINATION ${CURRENT_PACKAGES_DIR}/tools
    AUTO_CLEAN
)
