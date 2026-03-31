set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_BUILD_TYPE release)

# Special handling for ONNX Runtime dependencies
# Force these dependencies to be static so they're embedded into onnxruntime.dll
# This avoids shipping separate protobuf.dll, re2.dll, abseil_dll.dll, etc.
if(PORT MATCHES "^(protobuf|abseil|re2|date|onnx|utf8-range)$")
    set(VCPKG_LIBRARY_LINKAGE static)
endif()
