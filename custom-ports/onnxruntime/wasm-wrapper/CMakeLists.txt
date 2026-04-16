cmake_minimum_required(VERSION 3.27)

project(onnxruntime_side_module)

set_property(GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS ON)
SET(CMAKE_SHARED_LIBRARY_SUFFIX ".so")
SET(CMAKE_STRIP OFF)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
   set(OPTIMIZE_OR_DEBUG "-g")
else()
   set(OPTIMIZE_OR_DEBUG "-O3")
endif()

add_library(onnxruntime SHARED dummy.c)

# This needs to be set to the bundled static library location
if(NOT DEFINED ONNX_BUILD_DIR)
   message(FATAL_ERROR "ONNX_BUILD_DIR not defined. It should point to the ONNX Runtime build output directory")
endif()

target_link_options(onnxruntime PRIVATE
   ${OPTIMIZE_OR_DEBUG}
   -sWASM_BIGINT
   -fPIC
   -sSIDE_MODULE=1
   -pthread
   -sINITIAL_MEMORY=33554432
)

# Link the bundled static library created by ONNX Runtime
target_link_libraries(onnxruntime 
   PRIVATE 
   ${ONNX_BUILD_DIR}/libonnxruntime_webassembly.a
)
