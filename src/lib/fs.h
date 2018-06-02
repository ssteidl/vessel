#ifndef APPC_FS_H
#define APPC_FS_H

#include "appc_tcl.h"
#include <list>
#include <string>

namespace appc
{

class path_stat
{
    Tcl_StatBuf* m_stat_buf;

    friend class fs_path;

    void free_stat_buf(Tcl_StatBuf* stat_buf);

    Tcl_StatBuf* create_stat_buf(Tcl_Obj* path);

    path_stat(Tcl_Obj* path);

    path_stat(const path_stat& other) = delete;
    path_stat(path_stat&& other) = delete;
    path_stat& operator=(const path_stat& other) = delete;
    path_stat& operator=(path_stat&& other) = delete;

public:

    bool is_dir() const;

    ~path_stat();
};

class fs_path
{
private:
    tcl_obj_raii m_path;

    //NOTE: These can be implemented if needed
    fs_path(fs_path&& other) = delete;
    fs_path& operator=(const fs_path& rhs) = delete;
    fs_path& operator=(fs_path&& rhs) = delete;

public:

    fs_path();

    fs_path(Tcl_Obj* path);

    fs_path(const std::string& path);

    fs_path(const fs_path& other);

    bool exists() const;

    bool is_dir() const;

    bool is_readable() const;

    bool is_writable() const;

    bool is_executable() const;

    std::unique_ptr<path_stat> stat() const;

    bool operator==(const fs_path& rhs) const;

    fs_path& operator+=(const std::string& path_component);

    explicit operator bool() const;

    /*TODO: We need a common result struct that has code and message.*/
    bool copy_to(const fs_path& dest) const;

    std::string str() const;

    fs_path find_dir(const std::string& dir_name) const;

    ~fs_path();
};

/**
 * @brief validate_directory validates that the path exists and is
 * a directory.  Throws exception if either test failes.
 */
void validate_directory(const fs_path& path);

}
#endif // APPC_FS_H
