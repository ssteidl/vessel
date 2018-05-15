add_library(appc-priv STATIC
  appc_tcl.cpp
  fs.cpp
  mountpoint.cpp)
target_link_libraries(appc-priv ${TCL_LIBRARY})
