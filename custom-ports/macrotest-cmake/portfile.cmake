# macrotest-cmake
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mike-malburg/macrotest-cmake
    REF main
    SHA512 40baa81ab881794b4f94c894c985fb03c3a6478043b9ded4de840ce0f9121ae45e6f9bd18b533e205d86f4ff8d4ddaf1d0e5e27c6cb4aaea5e4cf69c9829173e
    HEAD_REF main
)

set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

vcpkg_configure_cmake(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_install_cmake()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig()
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")

# Move main exe to tools dir
vcpkg_copy_tools(
    TOOL_NAMES macrotest-cmake
    SEARCH_DIR ${CURRENT_PACKAGES_DIR}/bin
    DESTINATION ${CURRENT_PACKAGES_DIR}/tools
    AUTO_CLEAN
)
