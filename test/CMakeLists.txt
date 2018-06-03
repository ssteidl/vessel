enable_testing()

add_executable(fs_path_test fs_path_test.cpp)
target_link_libraries(fs_path_test appc-priv)
