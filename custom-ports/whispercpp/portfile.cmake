# whispercpp
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggerganov/whisper.cpp
    REF e72e4158debb04126a0fabedf0452a5551780ea0
    SHA512 67939e665542931a75a5ea05a873e5e0a73fc18b443720bcfeb340eb7e39818937c0078976320d9799f0643d8759a64adcb2da371e072f1053232802c1c107af
    HEAD_REF master
)

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}
    PREFER_NINJA
)

vcpkg_install_cmake()
vcpkg_copy_pdbs()

# Store all .libs in the root lib directory.  For Windows SHARED builds, these will be import libraries (not static libs).
file(GLOB_RECURSE LIB_FILES "${CURRENT_PACKAGES_DIR}/lib/static/*.lib")
foreach(LIB_FILE ${LIB_FILES})
    get_filename_component(LIB_NAME ${LIB_FILE} NAME)
    file(RENAME ${LIB_FILE} "${CURRENT_PACKAGES_DIR}/lib/${LIB_NAME}")
endforeach()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/lib/static")

file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)