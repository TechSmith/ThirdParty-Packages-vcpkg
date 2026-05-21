set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE static)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES x86_64)
# VCPKG_BUILD_TYPE intentionally omitted - builds both debug+release
# to avoid abseil pkgconfig fixup failures with debug-only builds.
# Only debug artifacts are published (controlled by preconfigured-packages.json).

set(VCPKG_C_FLAGS "-mmacosx-version-min=11.0 -g -gdwarf-2")
set(VCPKG_CXX_FLAGS "-mmacosx-version-min=11.0 -g -gdwarf-2")
set(VCPKG_LINKER_FLAGS -mmacosx-version-min=11.0)

# Enable Objective-C and Objective-C++ compiler detection for meson builds
set(VCPKG_ENABLE_OBJC ON)
