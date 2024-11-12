# dawn
vcpkg_from_git(
   OUT_SOURCE_PATH SOURCE_PATH
   URL https://dawn.googlesource.com/dawn
   REF 615b5fd6606a4d2bed2dc13a95ea9f87b497dec4 # chromium/6740
   HEAD_REF main
)

# Call fetch_dawn_dependencies ourselves so we can pass the --git argument
vcpkg_find_acquire_program(GIT)
vcpkg_find_acquire_program(PYTHON3)
vcpkg_execute_required_process(
   COMMAND ${PYTHON3} ${SOURCE_PATH}/tools/fetch_dawn_dependencies.py --git ${GIT}
   WORKING_DIRECTORY ${SOURCE_PATH}
   LOGNAME fetch_dawn_dependencies
)

list(APPEND CONFIGURE_OPTIONS
   -DDAWN_FETCH_DEPENDENCIES=OFF
   -DDAWN_BUILD_SAMPLES=OFF
   -DDAWN_ENABLE_VULKAN=OFF
   -DDAWN_ENABLE_INSTALL=ON
   -DTINT_BUILD_SPV_READER=ON
   -DTINT_BUILD_TESTS=OFF
)

if(VCPKG_HOST_IS_WINDOWS)
   list(APPEND CONFIGURE_OPTIONS
      -DTINT_ENABLE_INSTALL=ON
   )
endif()

vcpkg_cmake_configure(
   SOURCE_PATH ${SOURCE_PATH}
   OPTIONS ${CONFIGURE_OPTIONS}
)

vcpkg_build_cmake()

# Tint's install doesn't seem to properly respond to the CMake options. It expects
# these files to exist after a build, but they don't.
#
# We'll just make some empty files so the CMake install process doesn't fail
set(PREFIX ${VCPKG_TARGET_STATIC_LIBRARY_PREFIX})
set(SUFFIX ${VCPKG_TARGET_STATIC_LIBRARY_SUFFIX})

if(VCPKG_BUILD_TYPE STREQUAL "Debug")
   list(APPEND BUILD_DIR_SUFFIXES "-dbg")
elseif(VCPKG_BUILD_TYPE STREQUAL "Release")
   list(APPEND BUILD_DIR_SUFFIXES "-rel")
else()
   list(APPEND BUILD_DIR_SUFFIXES "-dbg")
   list(APPEND BUILD_DIR_SUFFIXES "-rel")
endif()

foreach(BUILD_DIR_SUFFIX ${BUILD_DIR_SUFFIXES})
   set(BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}${BUILD_DIR_SUFFIX}")
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
      message("Creating empty file ${MISSING_FILE}")
      file(TOUCH ${MISSING_FILE})
   endforeach()
endforeach()

message("*** run CMake Install...")
vcpkg_install_cmake()

set(DST_DIR "${CURRENT_PACKAGES_DIR}/include/src/utils")
message("Copying from ${SOURCE_PATH}/src/utils/compiler.h to ${DST_DIR}")
if(NOT EXISTS ${DST_DIR})
   file(MAKE_DIRECTORY ${DST_DIR})
endif()
file(COPY "${SOURCE_PATH}/src/utils/compiler.h"
   DESTINATION ${DST_DIR})

if(VCPKG_HOST_IS_WINDOWS)
   # Copy over SPIRV-Tools and SPIRV-Tools-opt
   foreach(BUILD_DIR_SUFFIX ${BUILD_DIR_SUFFIXES})
      set(BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}${BUILD_DIR_SUFFIX}")
      if(BUILD_DIR_SUFFIX STREQUAL "-dbg")
         set(DST_DIR "${CURRENT_PACKAGES_DIR}/debug/lib")
      else()
         set(DST_DIR "${CURRENT_PACKAGES_DIR}/lib")
      endif()

      file(COPY ${BUILD_DIR}/third_party/spirv-tools/source/SPIRV-Tools.lib DESTINATION ${DST_DIR})
      file(COPY ${BUILD_DIR}/third_party/spirv-tools/source/opt/SPIRV-Tools-opt.lib DESTINATION ${DST_DIR})
   endforeach()
endif()

vcpkg_copy_pdbs()

# Remove debugging files we don't need
if(VCPKG_HOST_IS_OSX)
   file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/lib/libwebgpu_dawn.dylib.dSYM")
else()
   # Remove dlls and pdbs
   file(REMOVE "${CURRENT_PACKAGES_DIR}/bin/webgpu_dawn.pdb")
   file(REMOVE "${CURRENT_PACKAGES_DIR}/debug/bin/webgpu_dawn.pdb")
endif()

vcpkg_cmake_config_fixup()

