set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE static)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES arm64)

set(VCPKG_BUILD_TYPE release)

set(VCPKG_C_FLAGS -mmacosx-version-min=11.0)
set(VCPKG_CXX_FLAGS "-mmacosx-version-min=11.0 -g2 -gdwarf-2")
set(VCPKG_LINKER_FLAGS -mmacosx-version-min=11.0)