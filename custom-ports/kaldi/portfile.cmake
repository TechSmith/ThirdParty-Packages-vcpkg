# kaldi
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO kaldi-asr/kaldi
    REF 8c451e28582f5d91f84ea3d64bb76c794c3b1683
    SHA512 d7aec4228dc9222ef5ef55d0c7f3cb677c9cb59eaa0fa8042a0257d39273febba26f80b576985f94b27963399509d29a9d04c46237a55f7288a4429dc8b6e11e
    HEAD_REF master
    PATCHES
        0001-Support-openfst-1.7.6.patch
        0002-Support-openfst-1.8.0.patch
        0003-Support-openfst-1.8.1.patch
        0004-Support-openfst-1.8.2.patch
        0005-Shared-libraries-on-windows.patch
        0006-Cuda-12-support.patch
)

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}
    PREFER_NINJA
)

vcpkg_install_cmake()
vcpkg_copy_pdbs()

file(INSTALL ${SOURCE_PATH}/COPYING DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)