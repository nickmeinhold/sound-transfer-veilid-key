# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(ggwave_ffi_library VERSION 0.0.1 LANGUAGES C CXX)

# ggwave source files
set(GGWAVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/ggwave")

# Build ggwave as a static library
add_library(ggwave STATIC
  "${GGWAVE_DIR}/src/ggwave.cpp"
)

target_include_directories(ggwave PUBLIC
  "${GGWAVE_DIR}/include"
  "${GGWAVE_DIR}/src"
)

set_target_properties(ggwave PROPERTIES
  CXX_STANDARD 11
  CXX_STANDARD_REQUIRED ON
  POSITION_INDEPENDENT_CODE ON
)

# Build the FFI wrapper
add_library(ggwave_ffi SHARED
  "ggwave_ffi.c"
)

target_include_directories(ggwave_ffi PUBLIC
  "${GGWAVE_DIR}/include"
)

target_link_libraries(ggwave_ffi PRIVATE ggwave)

set_target_properties(ggwave_ffi PROPERTIES
  PUBLIC_HEADER ggwave_ffi.h
  OUTPUT_NAME "ggwave_ffi"
)

target_compile_definitions(ggwave_ffi PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(ggwave_ffi PRIVATE "-Wl,-z,max-page-size=16384")
endif()
