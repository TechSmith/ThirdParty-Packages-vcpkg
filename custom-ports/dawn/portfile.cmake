if (VCPKG_TARGET_IS_EMSCRIPTEN)
    vcpkg_download_distfile(ARCHIVE
        URLS "https://github.com/google/dawn/releases/download/v${VERSION}/emdawnwebgpu_pkg-v${VERSION}.zip"
        FILENAME "emdawnwebgpu_pkg-v${VERSION}.zip"
        SHA512 5fd1c1d29c6657ae9e33a0fe27e27e7fd0147591e43e506d00bcc5d75c70327b3e020c777c71b3421e0c7afc245b2807b247cbf59ea581083c47ac2b60b80d3e
    )
    vcpkg_extract_source_archive(
        SOURCE_PATH
        ARCHIVE ${ARCHIVE}
        PATCHES
            000-fix-emdawnwebgpu.patch
    )
    set(VCPKG_BUILD_TYPE release)
    file(INSTALL "${SOURCE_PATH}/webgpu/include" DESTINATION "${CURRENT_PACKAGES_DIR}")
    file(INSTALL "${SOURCE_PATH}/webgpu_cpp/include" DESTINATION "${CURRENT_PACKAGES_DIR}")
    file(INSTALL "${SOURCE_PATH}/webgpu/src" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" PATTERN "LICENSE" EXCLUDE)
    file(INSTALL "${SOURCE_PATH}/emdawnwebgpu.port.py" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

    # cmake config file
    file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/DawnConfig.cmake" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
    vcpkg_cmake_config_fixup()

    # pkgconfig file
    set(DAWN_PKGCONFIG_CFLAGS "--use-port=\${prefix}/share/${PORT}/emdawnwebgpu.port.py")
    set(DAWN_PKGCONFIG_LIBS "--use-port=\${prefix}/share/${PORT}/emdawnwebgpu.port.py")
    set(DAWN_PKGCONFIG_REQUIRES "")
    configure_file("${CMAKE_CURRENT_LIST_DIR}/unofficial_webgpu_dawn.pc.in" "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/unofficial_webgpu_dawn.pc" @ONLY)
    vcpkg_fixup_pkgconfig()

    vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/webgpu/src/LICENSE" "${SOURCE_PATH}/webgpu_cpp/LICENSE")
    file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
    return()
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/dawn
    REF "v${VERSION}"
    SHA512 59c398e3a218d3776dc258582d90f7ba0e95181fe049c2afdfc734d6c9edf3ba489b283db93a79e04fa3cf0a934a2c9cfbf3cb330b16fee08b343bc45d0a568d
    HEAD_REF master
    PATCHES
        001-fix-windows-build.patch
        002-fix-uwp.patch
        003-fix-d3d11.patch
        004-deps.patch
        005-bsd-support.patch
        # https://github.com/google/dawn/commit/fa4a364b9ff215f9fe95823ec89ccc922cf7b254 added a tint writer for the null backend.
        # When building dawn[core] which only enables dawns null backend and tints null writer, src/dawn/native/ShaderModule.cpp failed to compile
        # as it was expecting a transitive include of tint::Bindings from a shader language writer.
        007-fix-tint-null-only-writer.patch
        008-wrong-dxcapi-include.patch
        009-fix-tint-install.patch
        010-fix-glslang.patch
        011-fix-dxc.patch
        # https://github.com/google/dawn/commit/d0a283a7a5e6320ca919f9580590371086f41dd6
        012-fix-non-target-leaking.patch
        # Apple Clang does not support implicit CTAD for aggregates (P1816R0/P1021R4).
        # Add explicit deduction guide for the `overloaded` helper struct.
        1001-tsc-fix-overloaded-ctad-macos.patch
)

function(checkout_in_path PATH URL REF)
    cmake_parse_arguments(EXTERNAL "" "" "PATCHES" ${ARGN})
    if(EXISTS "${PATH}")
        file(GLOB_RECURSE subdirectory_children "${CURRENT_PACKAGES_DIR}/include/${directory_child}/*")
        if(NOT "${subdirectory_children}" STREQUAL "")
            return()
        else()
            file(REMOVE_RECURSE "${PATH}")
        endif()
    endif()

    vcpkg_from_git(
        OUT_SOURCE_PATH DEP_SOURCE_PATH
        URL "${URL}"
        REF "${REF}"
        PATCHES ${EXTERNAL_PATCHES}
    )
    file(RENAME "${DEP_SOURCE_PATH}" "${PATH}")
    file(REMOVE_RECURSE "${DEP_SOURCE_PATH}")
endfunction()

checkout_in_path(
    "${SOURCE_PATH}/third_party/jinja2"
    "https://chromium.googlesource.com/chromium/src/third_party/jinja2"
    "c3027d884967773057bf74b957e3fea87e5df4d7"
)

checkout_in_path(
    "${SOURCE_PATH}/third_party/markupsafe"
    "https://chromium.googlesource.com/chromium/src/third_party/markupsafe"
    "4256084ae14175d38a3ff7d739dca83ae49ccec6"
)

checkout_in_path(
    "${SOURCE_PATH}/third_party/spirv-headers/src"
    "https://github.com/KhronosGroup/SPIRV-Headers"
    "ce9dfb01496073a02d74581ae909384763b41ff8"
)

checkout_in_path(
    "${SOURCE_PATH}/third_party/spirv-tools/src"
    "https://github.com/KhronosGroup/SPIRV-Tools"
    "34bc8ea6f3f84d5ed7739daa66b01e7273aed458"
    PATCHES
        # Dawn sets SPIRV_WERROR to OFF when building SPIRV-Tools, but https://github.com/KhronosGroup/SPIRV-Tools/commit/337fdb6a284fe7f7e374a14271f8e20e579f3263 ignores that CMake variable and forces /WX
        006-msvc-spirv-tools-disable-warnaserror.patch
)

checkout_in_path(
    "${SOURCE_PATH}/third_party/webgpu-headers/src"
    "https://github.com/webgpu-native/webgpu-headers"
    "7d3186c3dd2c708703524027b46b8703534ab3cc"
)

vcpkg_find_acquire_program(PYTHON3)

# <TechSmith Customizations>
# Do NOT use DAWN_BUILD_MONOLITHIC_LIBRARY. Instead, build Dawn the classic way:
# - webgpu_dawn as a shared library (DLL/dylib) for the WebGPU C API
# - Individual tint libraries as static libs for direct C++ API usage
# This matches the old custom port behavior and allows CommonCpp to link
# individual tint libs (e.g. tint_lang_wgsl_writer for WgslFromIR).
# </TechSmith Customizations>

vcpkg_check_features(
    OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        d3d11       DAWN_ENABLE_D3D11
        d3d12       DAWN_ENABLE_D3D12
        gl          DAWN_ENABLE_DESKTOP_GL
        gles        DAWN_ENABLE_OPENGLES
        metal       DAWN_ENABLE_METAL
        vulkan      DAWN_ENABLE_VULKAN
        wayland     DAWN_USE_WAYLAND
        x11         DAWN_USE_X11
        tint-tools  TINT_BUILD_CMD_TOOLS
)

set(DAWN_USE_BUILT_DXC OFF)
if(DAWN_ENABLE_D3D11 OR DAWN_ENABLE_D3D12)
    set(DAWN_USE_BUILT_DXC ON)
endif()

# <TechSmith Customizations>
# Use DAWN_BUILD_MONOLITHIC_LIBRARY=SHARED to get webgpu_dawn.dll (WebGPU C API),
# while keeping BUILD_SHARED_LIBS=OFF so individual tint libraries are static.
# TINT_ENABLE_INSTALL=ON ensures the individual tint .lib files are installed
# alongside the monolithic DLL, allowing CommonCpp to link tint C++ symbols directly.
# </TechSmith Customizations>

# Keep linkage backup/restore for compatibility with downstream vcpkg logic
set(VCPKG_LIBRARY_LINKAGE_BACKUP ${VCPKG_LIBRARY_LINKAGE})
# DAWN_BUILD_MONOLITHIC_LIBRARY SHARED/STATIC requires BUILD_SHARED_LIBS=OFF
set(VCPKG_LIBRARY_LINKAGE static)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        "-DPython3_EXECUTABLE=${PYTHON3}"
        -DDAWN_BUILD_MONOLITHIC_LIBRARY=SHARED
        -DDAWN_FETCH_DEPENDENCIES=OFF
        -DDAWN_ENABLE_INSTALL=ON
        -DDAWN_USE_GLFW=OFF
        -DDAWN_BUILD_PROTOBUF=OFF
        -DDAWN_BUILD_SAMPLES=OFF
        -DDAWN_BUILD_TESTS=OFF
        -DTINT_BUILD_TESTS=OFF
        -DTINT_ENABLE_INSTALL=ON
        -DTINT_BUILD_WGSL_READER=ON
        -DTINT_BUILD_WGSL_WRITER=ON
        -DTINT_BUILD_SPV_READER=ON
        -DTINT_BUILD_SPV_WRITER=ON
        -DDAWN_ENABLE_NULL=ON
        -DDAWN_ENABLE_VULKAN=OFF
        -DDAWN_USE_BUILT_DXC=${DAWN_USE_BUILT_DXC}
)

# <TechSmith Customizations>
# Tint's install expects certain library files to exist that may not have been
# built (e.g. language backends we didn't enable, fuzz helpers, etc.).
# Instead of maintaining a hardcoded list, scan the generated cmake_install.cmake
# for all .lib references under src/tint/ and create empty placeholders for any
# that weren't actually built.
set(PREFIX ${VCPKG_TARGET_STATIC_LIBRARY_PREFIX})
set(SUFFIX ${VCPKG_TARGET_STATIC_LIBRARY_SUFFIX})

if(VCPKG_BUILD_TYPE STREQUAL "release")
    list(APPEND BUILD_DIR_SUFFIXES "-rel")
elseif(VCPKG_BUILD_TYPE STREQUAL "debug")
    list(APPEND BUILD_DIR_SUFFIXES "-dbg")
else()
    list(APPEND BUILD_DIR_SUFFIXES "-dbg")
    list(APPEND BUILD_DIR_SUFFIXES "-rel")
endif()

foreach(BUILD_DIR_SUFFIX ${BUILD_DIR_SUFFIXES})
    set(BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}${BUILD_DIR_SUFFIX}")
    set(TINT_INSTALL_FILE "${BUILD_DIR}/src/tint/cmake_install.cmake")
    if(EXISTS "${TINT_INSTALL_FILE}")
        file(READ "${TINT_INSTALL_FILE}" TINT_INSTALL_CONTENTS)
        # Match all .lib file paths referenced in the install script
        string(REGEX MATCHALL "${BUILD_DIR}/src/tint/[^ \"\n]*\\${SUFFIX}" EXPECTED_LIBS "${TINT_INSTALL_CONTENTS}")
        list(REMOVE_DUPLICATES EXPECTED_LIBS)
        foreach(LIB_PATH ${EXPECTED_LIBS})
            if(NOT EXISTS "${LIB_PATH}")
                get_filename_component(LIB_DIR "${LIB_PATH}" DIRECTORY)
                file(MAKE_DIRECTORY "${LIB_DIR}")
                file(TOUCH "${LIB_PATH}")
                message(STATUS "Created placeholder: ${LIB_PATH}")
            endif()
        endforeach()
    endif()
endforeach()
# </TechSmith Customizations>

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/Dawn)

# <TechSmith Customizations>
# Install tint public headers manually.
file(GLOB TINT_PUBLIC_HEADERS "${SOURCE_PATH}/include/tint/*.h")
if(TINT_PUBLIC_HEADERS)
    file(INSTALL ${TINT_PUBLIC_HEADERS} DESTINATION "${CURRENT_PACKAGES_DIR}/include/tint")
endif()

# Install tint source headers (needed for some internal includes)
file(GLOB_RECURSE TINT_SRC_HEADERS "${SOURCE_PATH}/src/tint/*.h")
foreach(HEADER_FILE ${TINT_SRC_HEADERS})
    file(RELATIVE_PATH REL_PATH "${SOURCE_PATH}" "${HEADER_FILE}")
    get_filename_component(REL_DIR "${REL_PATH}" DIRECTORY)
    file(INSTALL "${HEADER_FILE}" DESTINATION "${CURRENT_PACKAGES_DIR}/include/${REL_DIR}")
endforeach()

# Install src/utils headers required by tint internal headers.
file(GLOB UTILS_SRC_HEADERS "${SOURCE_PATH}/src/utils/*.h")
if(UTILS_SRC_HEADERS)
    file(INSTALL ${UTILS_SRC_HEADERS} DESTINATION "${CURRENT_PACKAGES_DIR}/include/src/utils")
endif()

# Copy SPIRV-Tools libraries that Dawn builds internally
foreach(BUILD_DIR_SUFFIX ${BUILD_DIR_SUFFIXES})
    set(BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}${BUILD_DIR_SUFFIX}")
    if(BUILD_DIR_SUFFIX STREQUAL "-dbg")
        set(DST_DIR "${CURRENT_PACKAGES_DIR}/debug/lib")
    else()
        set(DST_DIR "${CURRENT_PACKAGES_DIR}/lib")
    endif()
    if(EXISTS "${BUILD_DIR}/third_party/spirv-tools/source/${PREFIX}SPIRV-Tools${SUFFIX}")
        file(COPY "${BUILD_DIR}/third_party/spirv-tools/source/${PREFIX}SPIRV-Tools${SUFFIX}" DESTINATION "${DST_DIR}")
    endif()
    if(EXISTS "${BUILD_DIR}/third_party/spirv-tools/source/opt/${PREFIX}SPIRV-Tools-opt${SUFFIX}")
        file(COPY "${BUILD_DIR}/third_party/spirv-tools/source/opt/${PREFIX}SPIRV-Tools-opt${SUFFIX}" DESTINATION "${DST_DIR}")
    endif()
endforeach()

# Allow bin/webgpu_dawn.dll to be in the package even though this is a static build
set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled)
# </TechSmith Customizations>

# Restore the original library linkage
set(VCPKG_LIBRARY_LINKAGE ${VCPKG_LIBRARY_LINKAGE_BACKUP})

list(APPEND DAWN_ABSL_REQUIRES
    absl_flat_hash_set
    absl_flat_hash_map
    absl_inlined_vector
    absl_no_destructor
    absl_overload
    absl_strings
    absl_span
    absl_string_view
)
list(JOIN DAWN_ABSL_REQUIRES ", " DAWN_ABSL_REQUIRES)

set(DAWN_PKGCONFIG_CFLAGS "")
set(DAWN_PKGCONFIG_REQUIRES "${DAWN_ABSL_REQUIRES}")
set(DAWN_PKGCONFIG_LIBS "-lwebgpu_dawn")

if (VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_MINGW AND NOT VCPKG_TARGET_IS_UWP)
    set(DAWN_PKGCONFIG_LIBS "${DAWN_PKGCONFIG_LIBS} -lonecore -luser32 -ldelayimp")
endif()
if (DAWN_ENABLE_D3D11 OR DAWN_ENABLE_D3D12)
    set(DAWN_PKGCONFIG_LIBS "${DAWN_PKGCONFIG_LIBS} -ldxguid")
endif()
if (DAWN_ENABLE_METAL)
    set(DAWN_PKGCONFIG_LIBS "${DAWN_PKGCONFIG_LIBS} -framework IOSurface -framework Metal -framework QuartzCore")
    if (VCPKG_TARGET_IS_OSX)
        set(DAWN_PKGCONFIG_LIBS "${DAWN_PKGCONFIG_LIBS} -framework Cocoa -framework IOKit")
    endif()
endif()

if (EXISTS "${CURRENT_PACKAGES_DIR}/debug/lib")
    configure_file("${CMAKE_CURRENT_LIST_DIR}/unofficial_webgpu_dawn.pc.in" "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/unofficial_webgpu_dawn.pc" @ONLY)
endif()
if (EXISTS "${CURRENT_PACKAGES_DIR}/lib")
    configure_file("${CMAKE_CURRENT_LIST_DIR}/unofficial_webgpu_dawn.pc.in" "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/unofficial_webgpu_dawn.pc" @ONLY)
endif()
vcpkg_fixup_pkgconfig()

if(TINT_BUILD_CMD_TOOLS)
    vcpkg_copy_tools(TOOL_NAMES tint AUTO_CLEAN)
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
