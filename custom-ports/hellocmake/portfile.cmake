# hellocmake
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mike-malburg/hellocmake
    REF master
    SHA512 abdf17c67b59daf64ba971294d67bf53d3380be01618eb42ed06fe1da206da7b9d4ce4662bf00abafc4c7098750f515c761ba1bbebad66c024caefe7c6b78041
    HEAD_REF master
)

set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)
set(VCPKG_POLICY_SKIP_COPYRIGHT_CHECK enabled)

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        --no-warn-unused-cli
)
vcpkg_install_cmake()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig()

# Move hellocmake exe to tools dir
vcpkg_copy_tools(
    TOOL_NAMES hellocmaketest
    SEARCH_DIR ${CURRENT_PACKAGES_DIR}/bin
    DESTINATION ${CURRENT_PACKAGES_DIR}/tools
    AUTO_CLEAN
)
