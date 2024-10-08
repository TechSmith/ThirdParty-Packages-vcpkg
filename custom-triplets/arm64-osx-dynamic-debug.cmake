set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)

set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES arm64)

set(VCPKG_BUILD_TYPE debug)

set(VCPKG_C_FLAGS "-mmacosx-version-min=11.0 -g -gdwarf-2")
set(VCPKG_CXX_FLAGS "-mmacosx-version-min=11.0 -g -gdwarf-2")
set(VCPKG_LINKER_FLAGS -mmacosx-version-min=11.0)