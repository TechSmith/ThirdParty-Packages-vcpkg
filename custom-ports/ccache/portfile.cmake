# ccache
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ccache/ccache
    REF "v${VERSION}"
    SHA512 d5ce788370ae3fc96a2d4c2158715b9aeb766e7d9fcd8504cd19da1f402d5ed73a712d598b98c13c2fe0a7bac8a0bd2922f04be4eb96a963f985f236fa80d1a6
    HEAD_REF master
)

set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)
vcpkg_cmake_configure(SOURCE_PATH ${SOURCE_PATH})
vcpkg_cmake_install()
vcpkg_copy_tools(TOOL_NAMES ccache AUTO_CLEAN)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.adoc")
