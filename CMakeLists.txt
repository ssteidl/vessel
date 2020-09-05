project(FBSDAppContainers)
cmake_minimum_required(VERSION 3.13)

set(CMAKE_CXX_STANDARD 17)

find_package(TCL)
find_package(CURL)
include_directories(${TCL_INCLUDE_PATH} ${CURL_INCLUDE_DIRS})

add_library(appctcl SHARED
    appc_native.cpp
    dns/embdns.cpp
    tcl_util.cpp
    url_cmd.cpp
    pty.cpp
    exec.cpp
    udp_tcl.c)

target_link_libraries(appctcl ${CURL_LIBRARIES})

add_executable(url_test url_test.cpp)
target_link_libraries(url_test ${CURL_LIBRARIES})

install(TARGETS appctcl
        LIBRARY
        DESTINATION lib/tclappc)
install(FILES appc
              appc_file_commands.tcl
              bsd.tcl
              build.tcl
              definition_file.tcl
              environment.tcl
              export.tcl
              import.tcl
              jail.tcl
              metadata_db.tcl
	      name-gen.tcl
              pkgIndex.tcl
              repos.tcl
              run.tcl
              zfs.tcl
        DESTINATION lib/tclappc)

install(DIRECTORY network
        DESTINATION lib/tclappc
        PATTERN *.md EXCLUDE)

install(PROGRAMS appc DESTINATION bin)
