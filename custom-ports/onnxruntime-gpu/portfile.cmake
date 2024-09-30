vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

set(PKG_NAME "")
if(VCPKG_HOST_IS_WINDOWS)
    set(PKG_NAME "onnxruntime-win-x64-gpu-${VERSION}")
    vcpkg_download_distfile(ARCHIVE
        URLS "https://github.com/microsoft/onnxruntime/releases/download/v${VERSION}/${PKG_NAME}.zip"
        FILENAME "${PKG_NAME}.zip"
        SHA512 9576eafca59fc7f2af9f62d7ee8aa31208ef965d17f3ad71747d5a9a46cdffd6b3958dc945109d82937555df8bb35319ce92925e66ab707f1ca8e7564ecb3ced
    )
elseif(VCPKG_HOST_IS_OSX)
    set(PKG_NAME "onnxruntime-osx-universal2-${VERSION}")
    vcpkg_download_distfile(ARCHIVE
        URLS "https://github.com/microsoft/onnxruntime/releases/download/v${VERSION}/${PKG_NAME}.zip"
        FILENAME "${PKG_NAME}.zip"
        SHA512 a4b233f5cb258624af4fa57c10c93010c01730d067809054846a7e9eec3f8d5025a52cc07f920258b0db5073a787d8fcffa5f627c0dd34c690900c836d797d49
    )
endif()

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    NO_REMOVE_ONE_LEVEL
)

# Download repo for experimental features
vcpkg_from_github(
    OUT_SOURCE_PATH REPO_PATH
    REPO microsoft/onnxruntime
    REF v${VERSION}
    SHA512 3bf25e431d175c61953d28b1bf8f6871376684263992451a5b2a66e670768fc66e7027f141c6e3f4d1eddeebeda51f31ea0adf4749e50d99ee89d0a26bec77ce
)

file(COPY
    ${REPO_PATH}/include/onnxruntime/core/session/experimental_onnxruntime_cxx_api.h 
    ${REPO_PATH}/include/onnxruntime/core/session/experimental_onnxruntime_cxx_inline.h
    DESTINATION ${CURRENT_PACKAGES_DIR}/include
)

file(MAKE_DIRECTORY
    ${CURRENT_PACKAGES_DIR}/include
    ${CURRENT_PACKAGES_DIR}/lib
)

if(VCPKG_HOST_IS_WINDOWS)
    file(MAKE_DIRECTORY
        ${CURRENT_PACKAGES_DIR}/bin
    )
endif()

file(COPY
    ${SOURCE_PATH}/${PKG_NAME}/include
    DESTINATION ${CURRENT_PACKAGES_DIR}
)

if(VCPKG_HOST_IS_OSX)
    file(GLOB LIB_FILES "${SOURCE_PATH}/${PKG_NAME}/*.lib")
    file(GLOB BIN_FILES "${SOURCE_PATH}/${PKG_NAME}/*.dll" "${SOURCE_PATH}/${PKG_NAME}/*.pdb")
elseif(VCPKG_HOST_IS_WINDOWS)
    file(GLOB LIB_FILES "${SOURCE_PATH}/${PKG_NAME}/*.dylib" "${SOURCE_PATH}/${PKG_NAME}/*.dSYM")
endif()

foreach(file ${LIB_FILES})
    file(COPY ${SOURCE_PATH}/${PKG_NAME}/lib/${file} DESTINATION ${CURRENT_PACKAGES_DIR}/lib)
endforeach()

foreach(file ${BIN_FILES})
    file(COPY ${SOURCE_PATH}/${PKG_NAME}/lib/${file} DESTINATION ${CURRENT_PACKAGES_DIR}/bin)
endforeach()

# Handle copyright
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/${PKG_NAME}/LICENSE")
