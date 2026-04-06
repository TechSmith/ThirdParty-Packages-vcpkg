set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_BUILD_TYPE release)

# Define BOOST_ALL_STATIC_LINK for Boost static linking
# This triplet is specifically used for Boost packages
set(VCPKG_CXX_FLAGS "/DBOOST_ALL_STATIC_LINK")
set(VCPKG_C_FLAGS "/DBOOST_ALL_STATIC_LINK")
