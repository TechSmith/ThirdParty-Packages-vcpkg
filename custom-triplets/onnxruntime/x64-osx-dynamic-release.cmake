set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)

set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES x86_64)
set(VCPKG_BUILD_TYPE release)

# BinSkim-compliant security hardening flags (matches Microsoft's official onnxruntime build)
set(VCPKG_C_FLAGS "-mmacosx-version-min=11.0 -g -gdwarf-2 -fvisibility=hidden -Wp,-D_FORTIFY_SOURCE=2 -fstack-protector-strong -O3 -pipe")
set(VCPKG_CXX_FLAGS "-mmacosx-version-min=11.0 -g -gdwarf-2 -fvisibility=hidden -fvisibility-inlines-hidden -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fstack-protector-strong -O3 -pipe")
set(VCPKG_LINKER_FLAGS -mmacosx-version-min=11.0)

# C++20 for ABI consistency (esp. abseil inline namespace) — matches ORT's CMakeLists.txt for Apple
set(VCPKG_CMAKE_CONFIGURE_OPTIONS "-DCMAKE_CXX_STANDARD=20")

# Force ORT dependencies to static linkage so they're embedded into libonnxruntime.dylib.
# This avoids shipping separate libprotobuf.dylib, libre2.dylib, etc.
# Matches the pattern used in onnxruntime/x64-windows-dynamic-release.cmake.
if(PORT MATCHES "^(protobuf|abseil|re2|date|onnx|utf8-range|cpuinfo)$")
    set(VCPKG_LIBRARY_LINKAGE static)
endif()
