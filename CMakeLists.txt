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
install(FILES appc_file_commands.tcl
              appcd_client.tcl
              bsd.tcl
              build.tcl
              definition_file.tcl
              environment.tcl
              jail.tcl
	      name-gen.tcl
              pkgIndex.tcl
              pty_shell.tcl
              publish.tcl
              pull.tcl
              run.tcl
              zfs.tcl
        DESTINATION lib/tclappc)

install(DIRECTORY network
        DESTINATION lib/tclappc
        PATTERN *.md EXCLUDE)

install(PROGRAMS appcd DESTINATION sbin)
install(PROGRAMS appc DESTINATION bin)
