project(FBSDAppContainers)
cmake_minimum_required(VERSION 3.13)

set(CMAKE_CXX_STANDARD 17)

find_package(TCL)
message("TCL ${TCL_LIBRARY}, ${TCL_INCLUDE_PATH}")
include_directories(${TCL_INCLUDE_PATH})

add_library(appctcl SHARED appc_native.cpp prototype/embdns.cpp)
