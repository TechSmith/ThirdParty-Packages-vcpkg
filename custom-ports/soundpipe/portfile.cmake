vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO shybyte/soundpipe
    REF 7384294519b250c68a94804c9d79901b73941824
    SHA512 06e8b330f410d668f935d2858a1360430f9da0b9345615aab53e3593c2f36fd43af4eb0b164c2531d9d16d1b9f564d2db307f9d46304d072fe84dce96e447fad
    HEAD_REF master
    PATCHES
        include-spa-header.patch
)

# Generate soundpipe.h by concatenating all module headers
set(ALL_MODULES
    base ftbl tevent adsr allpass atone autowah bal bar biquad biscale blsaw
    blsquare bltriangle fold bitcrush brown butbp butbr buthp butlp clip clock
    comb compressor count conv crossfade dcblock delay diode dist dmetro drip
    dtrig dust eqfil expon fof fog fofilt foo fosc gbuzz hilbert in incr jcrev
    jitter line lpf18 maygate metro mincer mode moogladder noise nsmp osc oscmorph
    pan2 panst pareq paulstretch pdhalf peaklim phaser phasor pinknoise pitchamdf
    pluck port posc3 progress prop pshift ptrack randh randi randmt random reverse
    reson revsc rms rpt rspline saturator samphold scale scrambler sdelay slice
    smoothdelay spa sparec streson switch tabread tadsr talkbox tblrec tbvcf tdiv
    tenv tenv2 tenvx tgate thresh timer tin tone trand tseg tseq vdelay voc
    vocoder waveset wpkorg35 zitarev fftwrapper padsynth
)

file(WRITE "${SOURCE_PATH}/h/soundpipe.h" "#ifndef SOUNDPIPE_H\n#define SOUNDPIPE_H\n")
foreach(MODULE ${ALL_MODULES})
    if(EXISTS "${SOURCE_PATH}/h/${MODULE}.h")
        file(READ "${SOURCE_PATH}/h/${MODULE}.h" MODULE_HEADER_CONTENT)
        file(APPEND "${SOURCE_PATH}/h/soundpipe.h" "${MODULE_HEADER_CONTENT}")
    endif()
endforeach()
file(APPEND "${SOURCE_PATH}/h/soundpipe.h" "#endif\n")

# Platform-specific build
if(VCPKG_TARGET_IS_WINDOWS)
    # Windows uses custom build script due to MSVC C99 limitations
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/build-soundpipe-windows.cmake" DESTINATION "${SOURCE_PATH}")

    # Check if clang-cl exists and prefer it over cl.exe for C99 support
    find_program(CLANG_CL_EXECUTABLE NAMES clang-cl PATHS "C:/Program Files/LLVM/bin" NO_DEFAULT_PATH)
    if(NOT CLANG_CL_EXECUTABLE)
        find_program(CLANG_CL_EXECUTABLE NAMES clang-cl)
    endif()

    if(CLANG_CL_EXECUTABLE)
        message(STATUS "Found clang-cl for soundpipe: ${CLANG_CL_EXECUTABLE}")
    endif()

    vcpkg_execute_build_process(
        COMMAND "${CMAKE_COMMAND}" 
            -DSOUNDPIPE_SOURCE_DIR="${SOURCE_PATH}"
            -DCMAKE_C_COMPILER=cl.exe
            -DCMAKE_AR=lib.exe
            -DCLANG_CL_HINT="${CLANG_CL_EXECUTABLE}"
            -DCMAKE_BUILD_TYPE=Release
            -P "${SOURCE_PATH}/build-soundpipe-windows.cmake"
        WORKING_DIRECTORY "${SOURCE_PATH}"
        LOGNAME build
    )

    file(INSTALL "${SOURCE_PATH}/soundpipe.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
        file(INSTALL "${SOURCE_PATH}/soundpipe.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
    endif()
else()
    # Mac/Linux/WASM use standard CMake build with proper C99 compiler support
    file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")
    
    vcpkg_cmake_configure(
        SOURCE_PATH "${SOURCE_PATH}"
    )
    
    vcpkg_cmake_install()
    vcpkg_cmake_config_fixup(PACKAGE_NAME soundpipe CONFIG_PATH lib/cmake/soundpipe)
    
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
endif()

# Install headers (common for all platforms)
file(INSTALL "${SOURCE_PATH}/h/soundpipe.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

vcpkg_copy_pdbs()

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
