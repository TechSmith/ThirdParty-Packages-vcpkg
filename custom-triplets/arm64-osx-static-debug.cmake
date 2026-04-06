set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE static)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES arm64)

set(VCPKG_BUILD_TYPE debug)
set(VCPKG_OSX_DEPLOYMENT_TARGET 13.0)

set(VCPKG_C_FLAGS "-mmacosx-version-min=13.0 -g -gdwarf-2 -fvisibility=hidden")
set(VCPKG_CXX_FLAGS "-mmacosx-version-min=13.0 -g -gdwarf-2 -fvisibility=hidden -fvisibility-inlines-hidden")
set(VCPKG_LINKER_FLAGS -mmacosx-version-min=13.0)

# C++20 for ABI consistency (esp. abseil inline namespace) — matches ORT's CMakeLists.txt for Apple
set(VCPKG_CMAKE_CONFIGURE_OPTIONS "-DCMAKE_CXX_STANDARD=20")