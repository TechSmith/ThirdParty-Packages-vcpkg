vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

set(PKG_NAME "")
if(VCPKG_HOST_IS_WINDOWS)
    set(PKG_NAME "onnxruntime-win-x64-gpu-${VERSION}")
    vcpkg_download_distfile(ARCHIVE
        URLS "https://github.com/microsoft/onnxruntime/releases/download/v${VERSION}/${PKG_NAME}.zip"
        FILENAME "${PKG_NAME}.zip"
        SHA512 1a7f5c1ca0cecb50505e0f33fd5b485b557c8930c79869b25acab036683c376d8e5e429f46cd30cbb592456203eca791948a7bcf1b730685c45196e85300c95e
    )
elseif(VCPKG_HOST_IS_OSX)
    set(PKG_NAME "onnxruntime-osx-universal2-${VERSION}")
    vcpkg_download_distfile(ARCHIVE
        URLS "https://github.com/microsoft/onnxruntime/releases/download/v${VERSION}/${PKG_NAME}.tgz"
        FILENAME "${PKG_NAME}.tgz"
        SHA512 5a59c36a683aed3c984e2eb97d91a50923f906ff5969edeeb941659a395411dd6f0f36d87f51e170f2fda70b2381a1afe3b40ef0c4395f393e50981e227cdbc5
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
    SHA512 192cb95e131d7a7796f29556355d0c9055c05723e1120e21155ed21e05301d862f2ba3fd613d8f9289b61577f64cc4b406db7bb25d1bd666b75c29a0f29cc9d8
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

if(VCPKG_HOST_IS_WINDOWS)
    file(GLOB LIB_FILES "${SOURCE_PATH}/${PKG_NAME}/lib/*.lib")
    file(GLOB BIN_FILES "${SOURCE_PATH}/${PKG_NAME}/lib/*.dll" "${SOURCE_PATH}/${PKG_NAME}/lib/*.pdb")
elseif(VCPKG_HOST_IS_OSX)
    file(GLOB LIB_FILES "${SOURCE_PATH}/${PKG_NAME}/lib/*.dylib" "${SOURCE_PATH}/${PKG_NAME}/lib/*.dSYM")
endif()

foreach(file ${LIB_FILES})
    file(COPY ${file} DESTINATION ${CURRENT_PACKAGES_DIR}/lib)
endforeach()

foreach(file ${BIN_FILES})
    file(COPY ${file} DESTINATION ${CURRENT_PACKAGES_DIR}/bin)
endforeach()

# Handle copyright
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/${PKG_NAME}/LICENSE")
