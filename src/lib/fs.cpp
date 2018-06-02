#include <appc_tcl.h>
#include <cassert>
#include <cstdlib>
#include "fs.h"
#include <iostream>
#include <sys/stat.h>
#include <sstream>
#include <unistd.h>
#include <vector>

using namespace appc;

/**************path_stat****************************/


path_stat::path_stat(const std::string& path)
    : m_stat_buf()
{
    int error = ::stat(path.c_str(), &m_stat_buf);
    if(error)
    {
        std::ostringstream msg;
        msg << "Error stat'ing path '" << path << "': " << strerror(errno);
        throw std::runtime_error(msg.str());
    }
}

bool path_stat::is_dir() const
{
    return S_ISDIR(m_stat_buf.st_mode);
}

/**************resource-fd***************************/
void resource_fd::do_close()
{
    if(m_fd != -1)
    {
        (void)::close(m_fd);
    }
}

int resource_fd::validate_fd(int fd)
{
    if(fd < -1)
    {
        throw std::invalid_argument("Illegal fd provided to resource_fd");
    }

    return fd;
}

resource_fd::resource_fd(int fd)
    : m_fd(validate_fd(fd))
{}

resource_fd::resource_fd(resource_fd&& other)
{
    do_close();

    m_fd = validate_fd(other.m_fd);
    other.m_fd = -1;
}

resource_fd& resource_fd::operator=(int fd)
{
    do_close();

    m_fd = validate_fd(fd);

    return *this;
}

resource_fd& resource_fd::operator=(resource_fd&& other)
{
    do_close();

    m_fd = validate_fd(other.m_fd);

    return *this;
}

resource_fd::operator int()
{
    return m_fd;
}

resource_fd::~resource_fd()
{
    do_close();
}

/**************fs_path******************************/
namespace
{
    void safe_free(char* ptr)
    {
        if(ptr)
        {
            ::free(ptr);
        }
    }

    std::string make_realpath(const std::string& _path)
    {
        std::unique_ptr<char, decltype(&safe_free)> path(
                    ::realpath(_path.c_str(), nullptr), safe_free);

        return path.get();
    }
}

fs_path::fs_path(const std::string& path)
    : m_path(make_realpath(path))
{}

fs_path::fs_path()
    : fs_path(std::string())
{}

fs_path::fs_path(const fs_path& other)
    : m_path(other.m_path)
{}

bool fs_path::exists() const
{
    int result = ::access(m_path.c_str(), F_OK);
    return (result == 0);
}

bool fs_path::is_readable() const
{
    int result = ::access(m_path.c_str(), R_OK);
    return (result == 0);
}

bool fs_path::is_writable() const
{
    int result = ::access(m_path.c_str(), W_OK);
    return (result == 0);
}

bool fs_path::is_executable() const
{
    int result = ::access(m_path.c_str(), X_OK);
    return (result == 0);
}

std::unique_ptr<path_stat> fs_path::stat() const
{
    return std::unique_ptr<path_stat>(new path_stat(m_path));
}

bool fs_path::is_dir() const
{
    return path_stat(m_path).is_dir();
}

bool fs_path::operator==(const fs_path& rhs) const
{
    //TODO: Write tests.  Maybe remove trailing slashes and duplicate slashes
    return m_path == rhs.m_path;
}

fs_path& fs_path::operator+=(const std::string& path_component)
{
    std::string new_path_str = m_path + "/" + path_component;
    this->m_path = fs_path(new_path_str).m_path;
    return *this;
}

fs_path::operator bool() const
{
    return (!m_path.empty());
}

/*TODO: We need a common result struct that has code and message.*/
bool fs_path::copy_to(const fs_path& dest) const
{
    if(is_dir())
    {
        if(!dest.is_dir())
        {
            Tcl_Obj* error = nullptr;
            tcl_obj_raii source_obj = Tcl_NewStringObj(m_path.c_str(), m_path.size());
            tcl_obj_raii dest_obj = Tcl_NewStringObj(dest.m_path.c_str(), dest.m_path.size());
            int tcl_ret = Tcl_FSCopyDirectory(source_obj, dest_obj, &error);
            if(tcl_ret == -1)
            {
                std::cerr << "Error copying directory: " << str() << "->" << dest.m_path << std::endl;
                return false;
            }
        }
    }
    else
    {
        throw std::runtime_error("Copy file not yet implemented");
    }

    return true;
}

std::string fs_path::str() const
{
    return m_path;
}

fs_path fs_path::find_dir(const std::string& dir_name) const
{
    if(!is_dir())
    {
        std::ostringstream msg;
        msg << "Attempted to find directory in path which is not a directory: search="
            << dir_name << "directory: " << str();
        throw std::logic_error(msg.str());
    }

    std::unique_ptr<Tcl_Interp, decltype(&Tcl_DeleteInterp)>
                    interp(Tcl_CreateInterp(), Tcl_DeleteInterp);

    tcl_obj_raii result_list = Tcl_NewListObj(0, nullptr);

    Tcl_GlobTypeData globtype;
    memset(&globtype, 0, sizeof(globtype));

    globtype.type = TCL_GLOB_TYPE_DIR;

    //Search for a folder with the image name in the appc_image_dir
    tcl_obj_raii path_obj = Tcl_NewStringObj(m_path.c_str(), m_path.size());
    int tcl_error = Tcl_FSMatchInDirectory(interp.get(), result_list, path_obj,
                                            dir_name.c_str(), &globtype);

    if(tcl_error)
    {
        //log debug
        const char* result_str = Tcl_GetStringResult(interp.get());
        std::cerr << "Failed to find image '" << dir_name << "': " << result_str << std::endl;
        return fs_path();
    }

    int length = 0;
    tcl_error = Tcl_ListObjLength(interp.get(), result_list, &length);
    if(!tcl_error && length > 1)
    {
        std::ostringstream msg;
        msg << "Multiple images found for name: " << dir_name;
        throw std::runtime_error(msg.str());
    }

    if(length == 0)
    {
        return fs_path();
    }

    Tcl_Obj* image_path = nullptr;
    tcl_error = Tcl_ListObjIndex(interp.get(), result_list, 0, &image_path);
    assert(!tcl_error);
    assert(image_path);

    if(image_path)
    {
        return fs_path(Tcl_GetStringFromObj(image_path, nullptr));
    }
    else
    {
        return fs_path();
    }
}

fs_path::~fs_path()
{}

/*****************functions************************************/
void appc::validate_directory(const fs_path& path)
{
    if(!path.exists())
    {
        std::cerr << path.str() << " does not exist" << std::endl;
        exit(1);
    }

    if(!path.is_dir())
    {
        std::cerr << path.str() << " is not a directory" << std::endl;
        exit(1);
    }
}
