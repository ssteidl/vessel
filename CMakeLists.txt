project(FBSDAppContainers)
cmake_minimum_required(VERSION 3.13)

set(CMAKE_CXX_STANDARD 17)

find_package(TCL)
find_package(CURL)
include_directories(${TCL_INCLUDE_PATH} ${CURL_INCLUDE_DIRS})

add_library(vesseltcl SHARED
    src/lib/native/vessel_native.cpp
    src/dns/embdns.cpp
    src/lib/native/tcl_util.cpp
    src/lib/native/url_cmd.cpp
    src/lib/native/pty.cpp
    src/lib/native/exec.cpp
    src/lib/native/devctl.cpp
    src/lib/native/tcl_kqueue.cpp
    src/lib/native/udp_tcl.c)

target_link_libraries(vesseltcl ${CURL_LIBRARIES})

add_executable(url_test util/native/url_test.cpp)
target_link_libraries(url_test ${CURL_LIBRARIES})

install(TARGETS vesseltcl
        LIBRARY
        DESTINATION lib/tclvessel)
install(FILES src/lib/tcl/vessel_file_commands.tcl
              src/lib/tcl/bsd.tcl
              src/lib/tcl/build.tcl
              src/lib/tcl/definition_file.tcl
	      src/lib/tcl/deploy.tcl
              src/lib/tcl/environment.tcl
              src/lib/tcl/export.tcl
              src/lib/tcl/import.tcl
              src/lib/tcl/jail.tcl
              src/lib/tcl/metadata_db.tcl
              src/lib/tcl/name-gen.tcl
              src/lib/tcl/pkgIndex.tcl
              src/lib/tcl/repos.tcl
              src/lib/tcl/run.tcl
              src/lib/tcl/syslog.tcl
              src/lib/tcl/zfs.tcl
        DESTINATION lib/tclvessel)
install(PROGRAMS src/rc.d/vessel
        DESTINATION etc/rc.d)
install(DIRECTORY src/network
        DESTINATION lib/tclvessel
        PATTERN *.md EXCLUDE)

install(PROGRAMS src/apps/vessel src/apps/vessel-supervisor
        DESTINATION bin)
