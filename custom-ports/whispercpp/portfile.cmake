# whispercpp
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggerganov/whisper.cpp
    REF "v${VERSION}"
    SHA512 7e0ec9d6afe234afaaa83d7d69051504252c27ecdacbedf3d70992429801bcd1078794a0bb76cf4dafb74131dd0f506bd24c3f3100815c35b8ac2b12336492ef
    HEAD_REF master
    PATCHES
        0001-tsc-override-whisper-shared.patch
)

set(VCPKG_POLICY_SKIP_MISPLACED_CMAKE_FILES_CHECK enabled)
set(VCPKG_POLICY_SKIP_LIB_CMAKE_MERGE_CHECK enabled)

# Specify configuration options
set(TSC_CMAKE_CONFIGURE_OPTIONS
    "-DCMAKE_TOOLCHAIN_FILE=${VCPKG_ROOT_DIR}/scripts/buildsystems/vcpkg.cmake"
    "-DCMAKE_INSTALL_PREFIX=${CURRENT_PACKAGES_DIR}"
    "-DCMAKE_BUILD_TYPE=RelWithDebInfo"
    -DBUILD_SHARED_LIBS=OFF
    -DWHISPER_BUILD_TESTS=OFF
    -DWHISPER_BUILD_EXAMPLES=OFF
)
if(VCPKG_HOST_IS_OSX)
    list(APPEND TSC_CMAKE_CONFIGURE_OPTIONS
        -DCMAKE_OSX_ARCHITECTURES=${VCPKG_OSX_ARCHITECTURES}
        -DGGML_METAL_EMBED_LIBRARY=ON
        -DGGML_METAL_NDEBUG=ON
    )
endif()

# Peform manaul cmake configure, build and install
#   We had some issues building this as a one-dll build, using the built-in vcpkg support
#   It passes in some stuff by default that we want to override, and it was too much of a hassle to deal with making it work with the build-in stuff
set(CMAKE_BUILD_DIR_RELEASE "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
file(MAKE_DIRECTORY "${CMAKE_BUILD_DIR_RELEASE}")

# Make git path available for the whispercpp project cmake files
vcpkg_find_acquire_program(GIT)
get_filename_component(GIT_DIR "${GIT}" DIRECTORY)
vcpkg_add_to_path("${GIT_DIR}")

message(STATUS ">> Configuring...")
set(CMAKE_C_FLAGS_INITIAL "${VCPKG_C_FLAGS}")
set(CMAKE_CXX_FLAGS_INITIAL "${VCPKG_CXX_FLAGS}")
set(CMAKE_LINKER_FLAGS_INITIAL "${VCPKG_LINKER_FLAGS}")
vcpkg_execute_build_process(
    COMMAND "${CMAKE_COMMAND}"
        -S "${SOURCE_PATH}"
        -B "${CMAKE_BUILD_DIR_RELEASE}"
        -DCMAKE_SYSTEM_NAME=${VCPKG_CMAKE_SYSTEM_NAME}
        -DCMAKE_C_FLAGS_INIT="${CMAKE_C_FLAGS_INITIAL}"
        -DCMAKE_CXX_FLAGS_INIT="${CMAKE_CXX_FLAGS_INITIAL}"
        -DCMAKE_EXE_LINKER_FLAGS_INIT="${CMAKE_LINKER_FLAGS_INITIAL}"
        -DCMAKE_SHARED_LINKER_FLAGS_INIT="${CMAKE_LINKER_FLAGS_INITIAL}"
        ${TSC_CMAKE_CONFIGURE_OPTIONS}
    WORKING_DIRECTORY "${CMAKE_BUILD_DIR_RELEASE}"
    LOGNAME "config-${TARGET_TRIPLET}-release"
)

message(STATUS ">> Building...")
vcpkg_execute_build_process(
    COMMAND "${CMAKE_COMMAND}"
        --build "${CMAKE_BUILD_DIR_RELEASE}"
        --config "RelWithDebInfo"
    WORKING_DIRECTORY "${CMAKE_BUILD_DIR_RELEASE}"
    LOGNAME "build-${TARGET_TRIPLET}-release"
)

message(STATUS ">> Installing...")
vcpkg_execute_build_process(
    COMMAND "${CMAKE_COMMAND}"
        --install "${CMAKE_BUILD_DIR_RELEASE}"
        --config "RelWithDebInfo"
    WORKING_DIRECTORY "${CMAKE_BUILD_DIR_RELEASE}"
    LOGNAME "install-${TARGET_TRIPLET}-release"
)

message(STATUS ">> Finishing packaging...")
vcpkg_copy_pdbs()
file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)
vcpkg_fixup_pkgconfig()
