include_directories(${CMAKE_SOURCE_DIR}/src/lib)

add_executable(appc app_containers.cpp)
target_link_libraries(appc appc-priv)
