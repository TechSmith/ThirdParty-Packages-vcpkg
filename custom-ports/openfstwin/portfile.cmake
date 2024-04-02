# openfstwin
vcpkg_download_distfile(ARCHIVE
    URLS "http://www.openfst.org/twiki/pub/FST/FstDownload/openfst-${VERSION}.tar.gz"
    FILENAME "openfstwin-src-${VERSION}.tar.gz"
    SHA512 26717ee019a05412d29ea611af651a443823999aab4e9834d2da7ce67d9aa1434ccacbcd19c0247386129272ddaec286f608be4d118ebef68d74c29a3b861d54
) 
vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
)
# Patches originally from: https://github.com/conda-forge/openfst-feedstock/tree/b1e10e692d802cc31f90b28ae31a5f3df18391b9/recipe/patches
vcpkg_apply_patches(
    SOURCE_PATH ${SOURCE_PATH}
    PATCHES 
        0001-Add-CMake-files.patch
        0002-Windows-compatibility.patch
)

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}
    PREFER_NINJA
)

vcpkg_install_cmake()
vcpkg_copy_pdbs()
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
