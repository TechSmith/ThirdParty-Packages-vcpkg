# dawn
vcpkg_from_git(
   OUT_SOURCE_PATH SOURCE_PATH
   URL https://dawn.googlesource.com/dawn
   REF 615b5fd6606a4d2bed2dc13a95ea9f87b497dec4 # chromium/6740
   HEAD_REF main
)

#set(VCPKG_POLICY_SKIP_MISPLACED_CMAKE_FILES_CHECK enabled)
#set(VCPKG_POLICY_SKIP_LIB_CMAKE_MERGE_CHECK enabled)

message("hello from dawn's vcpkg portfile")
set(BUILD_DIR ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel) # Fragile! Not sure why there's a -rel suffix
message("*** Add some files that are missing that install expects. BUILD_DIR = ${BUILD_DIR}")

if(VCPKG_HOST_IS_OSX)
   vcpkg_cmake_configure(
      SOURCE_PATH ${SOURCE_PATH}
      OPTIONS
      -DDAWN_FETCH_DEPENDENCIES=ON
      -DDAWN_BUILD_SAMPLES=OFF
      -DDAWN_ENABLE_VULKAN=OFF
      -DDAWN_ENABLE_INSTALL=ON
      -DTINT_BUILD_SPV_READER=ON
      -DTINT_ENABLE_INSTALL=ON
      -DTINT_BUILD_TESTS=OFF
      -DBUILD_SHARED_LIBS=OFF
      -DCMAKE_OSX_ARCHITECTURES=arm64;x86_64
   )
else()
   vcpkg_cmake_configure(
      SOURCE_PATH ${SOURCE_PATH}
      OPTIONS
      -DDAWN_FETCH_DEPENDENCIES=ON
      -DDAWN_BUILD_SAMPLES=OFF
      -DDAWN_ENABLE_VULKAN=OFF
      -DDAWN_ENABLE_INSTALL=ON
      -DTINT_BUILD_SPV_READER=ON
      -DTINT_ENABLE_INSTALL=ON
      -DTINT_BUILD_TESTS=OFF
      -DBUILD_SHARED_LIBS=OFF
   )
endif()

message("*** Building with cmake")
vcpkg_build_cmake()

message("*** Add some files that are missing that install expects. BUILD_DIR = ${BUILD_DIR}")

set(PREFIX ${VCPKG_TARGET_STATIC_LIBRARY_PREFIX})
set(SUFFIX ${VCPKG_TARGET_STATIC_LIBRARY_SUFFIX})
set(MISSING_FILES
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_glsl_intrinsic${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_glsl_ir${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_glsl${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_msl_intrinsic${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_msl_ir${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_msl_type${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_msl${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_hlsl_intrinsic${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_hlsl_ir${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_hlsl_type${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_hlsl_writer_printer${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_hlsl_writer_raise${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_hlsl${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_spirv_intrinsic${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_spirv_ir${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_spirv_type${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_lang_spirv${SUFFIX}
   ${BUILD_DIR}/src/tint/${PREFIX}tint_utils_bytes${SUFFIX}
)

file(MAKE_DIRECTORY ${BUILD_DIR}/src/tint)
foreach(MISSING_FILE ${MISSING_FILES})
   message("- creating missing file ${MISSING_FILE}")
   file(TOUCH ${MISSING_FILE})
endforeach()

message("*** run CMake Install...")
vcpkg_install_cmake()
vcpkg_copy_pdbs()
