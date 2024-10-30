# macrotest-meson
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mike-malburg/macrotest-meson
    REF main
    SHA512 291f6d4a1d98f87123322fb4e60072df600bd7f7f3f344bc7f294e6ce91958ea36be98d40afecdab647b03ad1723a213db12b40d9f192041784a9d026bd9bc03
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
