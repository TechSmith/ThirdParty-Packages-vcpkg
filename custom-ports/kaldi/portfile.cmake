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
vcpkg_build_cmake()
vcpkg_install_cmake()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/bin" "${CURRENT_PACKAGES_DIR}/debug/bin")