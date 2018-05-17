add_executable(appc
  app_containers.cpp
  cmdline.cpp
  environment.cpp
)
target_link_libraries(appc appc-priv)
