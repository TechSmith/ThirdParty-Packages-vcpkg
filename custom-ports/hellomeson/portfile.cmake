# hellomeson
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mike-malburg/hellomeson
    REF master
    SHA512 189ed23f4e944225d49d85920556480edf2305e141c24d70345532c1cc2ed754af8f03c266ab8d22f99c5bb59c1b2b5aca3796c21bd186917bbc8f6c55c131ee
    HEAD_REF master
)

set(VCPKG_POLICY_SKIP_COPYRIGHT_CHECK enabled)
set(VCPKG_POLICY_ALLOW_EXES_IN_BIN enabled)

vcpkg_configure_meson(
    SOURCE_PATH "${SOURCE_PATH}"
)

vcpkg_install_meson()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig()

# # Move hellomesontest exe to tools dir
vcpkg_copy_tools(
    TOOL_NAMES hellomesontest
    SEARCH_DIR ${CURRENT_PACKAGES_DIR}/bin
    DESTINATION ${CURRENT_PACKAGES_DIR}/tools
    AUTO_CLEAN
)
