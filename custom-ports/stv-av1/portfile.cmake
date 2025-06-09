# stv-av1
vcpkg_from_gitlab(
    OUT_SOURCE_PATH SOURCE_PATH
    GITLAB_URL https://gitlab.com
    REPO AOMediaCodec/SVT-AV1
    REF "v${VERSION}"
    SHA512 bec9d0ff1428e87e3926b4fd1e184a02a08865bef6b205674c24c9e242fd85796153a8e9c5f4907116fde4f361432f1246d1ccee6390d9bbf0ff243dfdd39ce7
    HEAD_REF master
)

# --- Execute Build ---
message(STATUS ">>> SOURCE PATH: ${SOURCE_PATH}")

if (NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
    SET(APPEND BUILD_SCRIPT_ARGS debug)
else()
    SET(APPEND BUILD_SCRIPT_ARGS release) # TODO: Add RelWithDebInfo support
endif()

if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    set(APPEND BUILD_SCRIPT_ARGS shared)
else()
    set(APPEND BUILD_SCRIPT_ARGS static)
endif()

if(VCPKG_HOST_IS_WINDOWS)
    SET(BUILD_SCRIPT_PATH "Build/windows/build.bat")
    SET(APPEND BUILD_SCRIPT_ARGS 2022)
elseif(VCPKG_HOST_IS_OSX)
    SET(BUILD_SCRIPT_PATH "Build/linux/build.sh")
else()
    message(FATAL_ERROR "This port only supports Windows and macOS.")
endif()

string(REPLACE ";" " " BUILD_SCRIPT_ARGS "${BUILD_SCRIPT_ARGS}")
vcpkg_execute_build_process(
    COMMAND "${BUILD_SCRIPT_PATH}" ${BUILD_SCRIPT_ARGS}
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME "build-${TARGET_TRIPLET}-${VCPKG_BUILD_TYPE}"
)