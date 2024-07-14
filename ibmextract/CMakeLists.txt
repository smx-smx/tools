project(ibmextract)
set(CMAKE_BUILD_TYPE Debug)
include_directories(${CMAKE_SOURCE_DIR})
add_executable(ibmextract ibmextract.c)
