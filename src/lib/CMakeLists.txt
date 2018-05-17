add_library(appc-priv STATIC
  appc_tcl.cpp
  container.cpp
  fs.cpp
  mountpoint.cpp)
target_link_libraries(appc-priv ${TCL_LIBRARY})
