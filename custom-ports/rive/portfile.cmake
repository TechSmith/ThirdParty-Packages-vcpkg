# rive portfile.cmake
# Wraps the upstream premake5 + gmake2 build system.
#
# NOTE: network access is required during build. The build script clones
# premake-core (v5.0.0-beta7) from GitHub and shallow-clones all C++
# dependencies (harfbuzz, sheenbidi, yoga, libpng, libjpeg, libwebp, etc.)
# into tests/dependencies/ at premake configure time.
#
# Produced static libs (macOS):
#   librive.a               - core animation runtime
#   librive_pls_renderer.a  - GPU renderer (Metal + OpenGL)
#   librive_cg_renderer.a   - CoreGraphics renderer
#   librive_decoders.a      - image decoder (PNG, JPEG, WebP)
#   librive_harfbuzz.a      - text shaping
#   librive_sheenbidi.a     - bidi text
#   librive_yoga.a          - layout
#   libminiaudio.a          - audio
#   liblibpng.a / libzlib.a / liblibjpeg.a / liblibwebp.a - image format libs

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO rive-app/rive-runtime
    REF runtime-v0.1.130
    SHA512 ffebad3c1231264389833ca49d72fac8419b5bdebff0684cc61bc0120c928887a9803533eeebaae8d59f6aac507b0db46e980180b868a78e0ef3c913118a93b5
    HEAD_REF main
)

# ── Map vcpkg target arch to rive build arch arg ──────────────────────────────
# build_rive.sh accepts "arm64" or "x64" as a positional arg, which sets
# -arch arm64 / -arch x86_64 in the compiler flags. This enables cross-
# compilation of x64 libs on an Apple Silicon host (and vice versa).
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(RIVE_ARCH_ARG "arm64")
    set(RIVE_OUTDIR "${SOURCE_PATH}/tests/out/arm64_release")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(RIVE_ARCH_ARG "x64")
    set(RIVE_OUTDIR "${SOURCE_PATH}/tests/out/x64_release")
else()
    message(FATAL_ERROR "rive: unsupported architecture '${VCPKG_TARGET_ARCHITECTURE}'")
endif()

# ── Build ─────────────────────────────────────────────────────────────────────
# build_rive.sh self-installs premake5 (builds from source at v5.0.0-beta7)
# into build/dependencies/premake-core/ and adds it to PATH.
# The "--" separator passes explicit make targets so the test/tool binaries
# (player, gms, goldens, bench) are NOT built, avoiding unneeded deps like GLFW.
#
# RIVE_PREMAKE_ARGS is set explicitly so the Metal backend is always included
# regardless of any ambient environment variable:
#   --with_rive_text    text/font rendering
#   --with_rive_layout  layout engine
#   --with_rive_canvas  ORE canvas layer; enables ORE_BACKEND_METAL on macOS,
#                       which compiles src/metal/*.mm and src/ore/metal/*.mm and
#                       embeds the compiled .metallib as a C byte array in the lib
set(ENV{RIVE_PREMAKE_ARGS} "--with_rive_text --with_rive_layout --with_rive_canvas")

message(STATUS "Building rive (${VCPKG_TARGET_ARCHITECTURE}): running premake5 + gmake2 (downloads dependencies on first run, ~5-10 min)")

vcpkg_execute_required_process(
    COMMAND bash "${SOURCE_PATH}/build/build_rive.sh" release ${RIVE_ARCH_ARG}
        --
        rive
        rive_pls_renderer
        rive_cg_renderer
        rive_decoders
        rive_harfbuzz
        rive_sheenbidi
        rive_yoga
        libpng
        zlib
        libjpeg
        libwebp
        miniaudio
    WORKING_DIRECTORY "${SOURCE_PATH}/tests"
    LOGNAME build-${TARGET_TRIPLET}
)

if(NOT EXISTS "${RIVE_OUTDIR}/librive.a")
    message(FATAL_ERROR
        "rive build failed: ${RIVE_OUTDIR}/librive.a not found.\n"
        "Check ${CURRENT_BUILDTREES_DIR}/build-${TARGET_TRIPLET}-out.log for details."
    )
endif()

# ── Install headers ───────────────────────────────────────────────────────────
file(COPY "${SOURCE_PATH}/include/"             DESTINATION "${CURRENT_PACKAGES_DIR}/include")
file(COPY "${SOURCE_PATH}/renderer/include/"    DESTINATION "${CURRENT_PACKAGES_DIR}/include")
file(COPY "${SOURCE_PATH}/cg_renderer/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

# ── Install static libs ───────────────────────────────────────────────────────
file(GLOB RIVE_STATIC_LIBS "${RIVE_OUTDIR}/*.a")
if(NOT RIVE_STATIC_LIBS)
    message(FATAL_ERROR "No .a files found in ${RIVE_OUTDIR}")
endif()
file(COPY ${RIVE_STATIC_LIBS} DESTINATION "${CURRENT_PACKAGES_DIR}/lib")

# ── CMake integration ─────────────────────────────────────────────────────────
configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/rive-config.cmake.in"
    "${CURRENT_PACKAGES_DIR}/share/rive/rive-config.cmake"
    COPYONLY
)

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/rive")

# ── License ───────────────────────────────────────────────────────────────────
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")

# This port only produces release static libs (the upstream premake build
# does not distinguish vcpkg debug/release; release-only is intentional).
set(VCPKG_POLICY_MISMATCHED_NUMBER_OF_BINARIES enabled)
