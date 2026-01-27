# <TechSmith Customizations>
# Original Microsoft/vcpkg patches
set(WHISPER_PATCHES
    cmake-config.diff
    pkgconfig.diff
)

# TSC Patches for static ggml linking
list(APPEND WHISPER_PATCHES
    1001-tsc-cmake-main.diff
    1002-tsc-cmake-ggml.diff
)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggml-org/whisper.cpp
    REF v${VERSION}
    SHA512 d858509b22183b885735415959fc996f0f5ca315aaf40b8640593c4ce881c88fec3fcd16e9a3adda8d1177feed01947fb4c1beaf32d7e4385c5f35a024329ef5
    HEAD_REF master
    PATCHES ${WHISPER_PATCHES}
)

# Link options
if(VCPKG_TARGET_IS_WINDOWS)
    # Statically link the vc runtime for windows
    set(OSSPEC_WHISPER_LINK_OPTIONS -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded)
endif()
set(WHISPER_LINK_OPTIONS -DGGML_NATIVE=OFF -DBUILD_SHARED_LIBS=ON ${OSSPEC_WHISPER_LINK_OPTIONS})

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    DISABLE_PARALLEL_CONFIGURE # updating bindings/javascript/package.json
    OPTIONS
        -DWHISPER_ALL_WARNINGS=OFF
        -DWHISPER_BUILD_EXAMPLES=OFF
        -DWHISPER_BUILD_SERVER=OFF
        -DWHISPER_BUILD_TESTS=OFF
        -DWHISPER_CCACHE=OFF
        -DWHISPER_USE_SYSTEM_GGML=OFF
        ${WHISPER_LINK_OPTIONS}
)
# </TechSmith Customizations>

vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/whisper")

# <TechSmith Customizations>
# Modify whisper.pc to not link ggml since it's statically embedded
if(EXISTS "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/whisper.pc")
    file(READ "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/whisper.pc" _contents)
    # Remove ggml from Requires field (it's statically embedded, not a separate dependency)
    string(REGEX REPLACE "Requires:[^\n]*ggml[^\n]*\n" "" _contents "${_contents}")
    string(REGEX REPLACE "Requires\\.private:[^\n]*ggml[^\n]*\n" "" _contents "${_contents}")
    # Fix Libs field to only reference whisper library
    string(REPLACE "-lggml -lggml-base -lwhisper" "-lwhisper" _contents "${_contents}")
    string(REPLACE "-lggml-base -lggml -lwhisper" "-lwhisper" _contents "${_contents}")
    string(REPLACE "-lggml -lwhisper" "-lwhisper" _contents "${_contents}")
    string(REPLACE "-lggml-base -lwhisper" "-lwhisper" _contents "${_contents}")
    file(WRITE "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/whisper.pc" "${_contents}")
endif()
# </TechSmith Customizations>

vcpkg_fixup_pkgconfig()

file(INSTALL "${SOURCE_PATH}/models/convert-pt-to-ggml.py" DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
