vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO thorvg/thorvg
    REF "v${VERSION}"
    SHA512 a3a1e3c84c2a0f6ff174adccdd1d185b4433cd781fed22a0e6b07f1ee7f7402ed220bc92caade4faa872362e7319491e532485f37e62c00e15cee5c829914c48
    HEAD_REF master
    PATCHES
        harden-jerryscript.patch
        use-system-libwebp.patch
)

if ("tools" IN_LIST FEATURES)
    list(APPEND BUILD_OPTIONS -Dtools=all)
endif()

# Harden the bundled JerryScript used by Lottie expressions:
#   JERRY_VM_HALT=1       — compile in the VM halt callback mechanism so
#                           infinite loops can be terminated.
#   JERRY_STACK_LIMIT=96  — cap the JS native stack at 96 KB to prevent
#                           stack-overflow crashes from deeply recursive scripts.
string(APPEND JERRY_HARDENING_FLAGS " -DJERRY_VM_HALT=1 -DJERRY_STACK_LIMIT=96")

vcpkg_configure_meson(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${BUILD_OPTIONS}
        # see ${SOURCE_PATH}/meson_options.txt
        -Dstatic=true # Use static modules
        -Dengines=['cpu']
        -Dloaders=all
        -Dsavers=all
        -Dsimd=true
        -Dbindings=capi
        -Dtests=false
        -Dstrip=false
        -Dextra=['lottie_exp']
        -Dcpp_args=${JERRY_HARDENING_FLAGS}
    OPTIONS_DEBUG
        -Dlog=true
        -Dbindir=${CURRENT_PACKAGES_DIR}/debug/bin
    OPTIONS_RELEASE
        -Dbindir=${CURRENT_PACKAGES_DIR}/bin
)
vcpkg_install_meson()
vcpkg_fixup_pkgconfig()

if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/thorvg-1/thorvg.h" "#ifndef TVG_STATIC" "#if 0")
else()
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/thorvg-1/thorvg.h" "#ifndef TVG_STATIC" "#if 1")
endif()

if ("tools" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES tvg-svg2png tvg-lottie2gif AUTO_CLEAN)
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
