set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)

set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES arm64)

set(VCPKG_BUILD_TYPE release)

# Disable ARM NEON optimizations to fix fl16 build issues
set(VCPKG_C_FLAGS "-mmacosx-version-min=11.0 -g -gdwarf-2 -DCPU_BASELINE=NONE -DCPU_DISPATCH=NONE")
set(VCPKG_CXX_FLAGS "-mmacosx-version-min=11.0 -g -gdwarf-2 -DCPU_BASELINE=NONE -DCPU_DISPATCH=NONE")
set(VCPKG_LINKER_FLAGS -mmacosx-version-min=11.0)

# Additional OpenCV-specific flags to disable NEON
set(VCPKG_CMAKE_CONFIGURE_OPTIONS "-DCPU_BASELINE=NONE" "-DCPU_DISPATCH=NONE" "-DENABLE_NEON=OFF") 