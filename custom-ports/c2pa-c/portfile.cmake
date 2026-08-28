vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO contentauth/c2pa-rs
    REF da39d448f1aa24af2afe43eabf135c77acb43934
    SHA512 91a23a61ce7dbf710b3a2326c88bd547d2fb6eac9149e9319427b70a96a39540214ed07e02ecf76f26b5c5edc098a6df34b8587216db3cecfd9acc2820084495
)

if(VCPKG_TARGET_IS_OSX AND VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(C2PA_ARCHIVE_NAME "c2pa-v${VERSION}-aarch64-apple-darwin.zip")
    set(C2PA_ARCHIVE_SHA512 8a59f7438ef1c66d375a7e0f0fd7433d7df4b9d9199fc77ab7206894d8b0137473161d463f98f26bd5d649760dfacea394a9df0c163306cc10e44ad64592a976)
elseif(VCPKG_TARGET_IS_OSX AND VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(C2PA_ARCHIVE_NAME "c2pa-v${VERSION}-x86_64-apple-darwin.zip")
    set(C2PA_ARCHIVE_SHA512 b6b7d6ddf14d1944c7dfb63bb28a7be059e8de74b3f73726cb67207419e2d7d6fa9a3effb8caa03b86b965dc4b3f3cf62131bba87e2f065cd44a62142fc9e6d8)
elseif(VCPKG_TARGET_IS_WINDOWS AND VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(C2PA_ARCHIVE_NAME "c2pa-v${VERSION}-x86_64-pc-windows-msvc.zip")
    set(C2PA_ARCHIVE_SHA512 2664f92cdc0ad3f0889b6fc26af7724f1464c8a7bc394208202691c6be1850027025fc19caae6ea60321d3bc4d0ff585a710c651ce28a31e14e49b781d76f2ae)
else()
    message(FATAL_ERROR "c2pa-c does not provide a prebuilt binary for this platform and architecture")
endif()

vcpkg_download_distfile(C2PA_ARCHIVE
    URLS "https://github.com/contentauth/c2pa-rs/releases/download/c2pa-v${VERSION}/${C2PA_ARCHIVE_NAME}"
    FILENAME "${C2PA_ARCHIVE_NAME}"
    SHA512 "${C2PA_ARCHIVE_SHA512}"
)
vcpkg_extract_source_archive(
    C2PA_BINARY_PATH
    ARCHIVE "${C2PA_ARCHIVE}"
    NO_REMOVE_ONE_LEVEL
)

file(INSTALL "${C2PA_BINARY_PATH}/include/c2pa.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
if(VCPKG_TARGET_IS_WINDOWS)
    file(INSTALL "${C2PA_BINARY_PATH}/lib/c2pa_c.dll" DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
    file(INSTALL "${C2PA_BINARY_PATH}/lib/c2pa_c.dll.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
else()
    file(INSTALL "${C2PA_BINARY_PATH}/lib/libc2pa_c.dylib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
endif()

vcpkg_install_copyright(
    FILE_LIST
        "${SOURCE_PATH}/LICENSE-APACHE"
        "${SOURCE_PATH}/LICENSE-MIT"
)
