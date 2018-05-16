cmake_minimum_required (VERSION 3.10.1)
project (AppC)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(TCL)
include_directories(${TCL_INCLUDE_PATH})

add_subdirectory(src)
