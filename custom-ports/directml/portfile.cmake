# Download DirectML from NuGet package
vcpkg_download_distfile(
    ARCHIVE
    URLS "https://www.nuget.org/api/v2/package/Microsoft.AI.DirectML/${VERSION}"
    FILENAME "Microsoft.AI.DirectML.${VERSION}.nupkg"
    SHA512 fde767f56904abc90fd53f65d8729c918ab7f6e3c5e1ecdd479908fc02b4535cf2b0860f7ab2acb9b731d6cb809b72c3d5d4d02853fb8f5ea022a47bc44ef285
)

# Extract the NuGet package (it's just a zip file)
vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    NO_REMOVE_ONE_LEVEL
)

# Install headers
file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include" FILES_MATCHING PATTERN "*.h")

# Install libraries based on architecture
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(DML_ARCH_PATH "bin/x64-win")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
    set(DML_ARCH_PATH "bin/x86-win")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(DML_ARCH_PATH "bin/arm64-win")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
    set(DML_ARCH_PATH "bin/arm-win")
else()
    message(FATAL_ERROR "Unsupported architecture: ${VCPKG_TARGET_ARCHITECTURE}")
endif()

# Install DLLs and LIBs
file(INSTALL "${SOURCE_PATH}/${DML_ARCH_PATH}/DirectML.dll" DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
file(INSTALL "${SOURCE_PATH}/${DML_ARCH_PATH}/DirectML.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")

if(NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
    file(INSTALL "${SOURCE_PATH}/${DML_ARCH_PATH}/DirectML.dll" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/bin")
    file(INSTALL "${SOURCE_PATH}/${DML_ARCH_PATH}/DirectML.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
endif()

# Create a simple CMake config file
file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/DirectMLConfig.cmake" "
include(CMakeFindDependencyMacro)

if(NOT TARGET DirectML::DirectML)
    add_library(DirectML::DirectML SHARED IMPORTED)
    set_target_properties(DirectML::DirectML PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES \"\${CMAKE_CURRENT_LIST_DIR}/../../include\"
    )
    
    if(EXISTS \"\${CMAKE_CURRENT_LIST_DIR}/../../bin/DirectML.dll\")
        set_target_properties(DirectML::DirectML PROPERTIES
            IMPORTED_LOCATION \"\${CMAKE_CURRENT_LIST_DIR}/../../bin/DirectML.dll\"
            IMPORTED_IMPLIB \"\${CMAKE_CURRENT_LIST_DIR}/../../lib/DirectML.lib\"
        )
    endif()
    
    if(EXISTS \"\${CMAKE_CURRENT_LIST_DIR}/../../debug/bin/DirectML.dll\")
        set_target_properties(DirectML::DirectML PROPERTIES
            IMPORTED_LOCATION_DEBUG \"\${CMAKE_CURRENT_LIST_DIR}/../../debug/bin/DirectML.dll\"
            IMPORTED_IMPLIB_DEBUG \"\${CMAKE_CURRENT_LIST_DIR}/../../debug/lib/DirectML.lib\"
        )
    endif()
endif()

set(DirectML_FOUND TRUE)
")

# Install copyright
file(INSTALL "${SOURCE_PATH}/LICENSE.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
