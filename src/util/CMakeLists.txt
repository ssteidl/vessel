set(APP_DIR ${CMAKE_SOURCE_DIR}/src/app)
include_directories(${APP_DIR})

add_executable(appc_mount
  appc_mount.cpp
  ${APP_DIR}/app_functions.cpp
  ${APP_DIR}/cmdline.cpp
  ${APP_DIR}/environment.cpp
)
target_link_libraries(appc_mount appc-priv jail)
