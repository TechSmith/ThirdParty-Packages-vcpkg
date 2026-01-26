# Build the list of patches to apply
# Start with microsoft/vcpkg patches
set(WHISPER_PATCHES
    cmake-config.diff
    pkgconfig.diff
)

# TSC: Add patches for static ggml linking
list(APPEND WHISPER_PATCHES
    1001-tsc-cmake-main.diff
    1002-tsc-cmake-ggml.diff
)

# TSC: Add patches to control AVX-512 auto-vectorization
list(APPEND WHISPER_PATCHES
    1003-tsc-disable-auto-avx512.diff
    1004-tsc-respect-explicit-avx512-off.diff
)

# TSC: Conditionally add DLL renaming patches
if("rename-whisper-basic" IN_LIST FEATURES)
    list(APPEND WHISPER_PATCHES 1005-tsc-rename-target-whisper-basic.diff)
endif()

if("rename-whisper-vulkan" IN_LIST FEATURES)
    list(APPEND WHISPER_PATCHES 1006-tsc-rename-target-whisper-vulkan.diff)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggml-org/whisper.cpp
    REF v${VERSION}
    SHA512 d858509b22183b885735415959fc996f0f5ca315aaf40b8640593c4ce881c88fec3fcd16e9a3adda8d1177feed01947fb4c1beaf32d7e4385c5f35a024329ef5
    HEAD_REF master
    PATCHES ${WHISPER_PATCHES}
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
    metal GGML_METAL
    vulkan GGML_VULKAN
    cuda GGML_CUDA
    openblas GGML_BLAS
    avx GGML_AVX
    avx2 GGML_AVX2
    fma GGML_FMA
    f16c GGML_F16C
    avx512 GGML_AVX512
    avx512 GGML_AVX512_VBMI
    avx512 GGML_AVX512_VNNI
    avx512 GGML_AVX512_BF16
)

# vcpkg_check_features doesn't map this variant, so we handle it manually
if("openblas" IN_LIST FEATURES)
    list(APPEND FEATURE_OPTIONS -DGGML_BLAS_VENDOR=OpenBLAS)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    DISABLE_PARALLEL_CONFIGURE
    OPTIONS
        -DBUILD_SHARED_LIBS=ON
        ${FEATURE_OPTIONS}
        -DWHISPER_ALL_WARNINGS=OFF
        -DWHISPER_BUILD_EXAMPLES=OFF
        -DWHISPER_BUILD_SERVER=OFF
        -DWHISPER_BUILD_TESTS=OFF
        -DWHISPER_CCACHE=OFF
        -DWHISPER_USE_SYSTEM_GGML=OFF
        -DGGML_NATIVE=OFF
)

vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/whisper")

# TSC: Modify whisper.pc to not link ggml since it's statically embedded
# Also update library name if renamed
if("rename-whisper-basic" IN_LIST FEATURES)
    file(READ "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/whisper.pc" _contents)
    string(REPLACE "-lggml -lggml-base -lwhisper-basic" "-lwhisper-basic" _contents "${_contents}")
    file(WRITE "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/whisper.pc" "${_contents}")
elseif("rename-whisper-vulkan" IN_LIST FEATURES)
    file(READ "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/whisper.pc" _contents)
    string(REPLACE "-lggml -lggml-base -lwhisper-vulkan" "-lwhisper-vulkan" _contents "${_contents}")
    file(WRITE "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/whisper.pc" "${_contents}")
else()
    file(READ "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/whisper.pc" _contents)
    string(REPLACE "-lggml -lggml-base -lwhisper" "-lwhisper" _contents "${_contents}")
    file(WRITE "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/whisper.pc" "${_contents}")
endif()

vcpkg_fixup_pkgconfig()

file(INSTALL "${SOURCE_PATH}/models/convert-pt-to-ggml.py" DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
