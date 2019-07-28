project(FBSDAppContainers)
cmake_minimum_required(VERSION 3.13)

set(CMAKE_CXX_STANDARD 17)

find_package(TCL)
find_package(CURL)
message("TCL ${TCL_LIBRARY}, ${TCL_INCLUDE_PATH}")
include_directories(${TCL_INCLUDE_PATH} ${CURL_INCLUDE_DIRS})

add_library(appctcl SHARED
    appc_native.cpp
    dns/embdns.cpp
    tcl_util.cpp
    url_cmd.cpp)

target_link_libraries(appctcl ${CURL_LIBRARIES})

add_executable(url_test url_test.cpp)
target_link_libraries(url_test ${CURL_LIBRARIES})
