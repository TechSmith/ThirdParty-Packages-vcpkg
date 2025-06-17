vcpkg_from_gitlab(
    GITLAB_URL https://gitlab.com
    OUT_SOURCE_PATH SOURCE_PATH
    REPO bits-n-bites/buildcache
    REF v${VERSION}
    SHA512 cdd53fd829190e26bc0a9a4e2bd3e9cd39eb9abf98e621b07f4a749c24e7f1288d68dc1f2e550e49ebbf511a12b89d7c05b68e695510df881b54f54982879267
    HEAD_REF master
)

set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/src"
    OPTIONS 
        -DDISABLE_SSL=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME buildcache CONFIG_PATH share/buildcache)
vcpkg_copy_tools(TOOL_NAMES buildcache AUTO_CLEAN)
file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
