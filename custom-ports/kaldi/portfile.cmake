vcpkg_from_git(
   OUT_SOURCE_PATH SOURCE_PATH
   URL https://github.com/kaldi-asr/kaldi.git
   REF 4a8b7f673275597fef8a15b160124bd0985b59bd # latest as of October 4th
   HEAD_REF main
)
# Set this so it doesn't try and use git to find the version
# This is what get_version() inside of the kaldi CMakelists.txt calculated
set(KALDI_VERSION 5.5)

set(VCPKG_CMAKE_CONFIGURE_OPTIONS "-DFETCHCONTENT_FULLY_DISCONNECTED=FALSE")

vcpkg_cmake_configure(
   SOURCE_PATH ${SOURCE_PATH}
   OPTIONS
   -DKALDI_BUILD_TEST=OFF
   -DKALDI_BUILD_EXE=OFF
   -DKALDI_VERSION=${KALDI_VERSION}
)
vcpkg_cmake_build()
vcpkg_cmake_install()

# Remove files:
# 1. "bin" files (ex. .dll files) from static builds
# 2. cmake files we don't want to publish
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
   set(DIRS_TO_REMOVE
      ${CURRENT_PACKAGES_DIR}/bin
      ${CURRENT_PACKAGES_DIR}/lib/fst
      ${CURRENT_PACKAGES_DIR}/lib/cmake
   )
   foreach(DIR ${DIRS_TO_REMOVE})
      if(EXISTS ${DIR})
         file(REMOVE_RECURSE ${DIR})
      endif()
   endforeach()
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
