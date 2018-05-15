#include <cassert>
#include "fs.h"
#include <iostream>
#include <sys/stat.h>
#include <sstream>
#include <unistd.h>

using namespace appc;

/**************path_stat****************************/

void path_stat::free_stat_buf(Tcl_StatBuf* stat_buf)
{
    if(stat_buf)
    {
        ckfree(stat_buf);
    }
}

Tcl_StatBuf*
path_stat::create_stat_buf(Tcl_Obj* path)
{
    assert(path);
    Tcl_StatBuf* stat_buf = Tcl_AllocStatBuf();
    int tcl_ret = Tcl_FSStat(path, stat_buf);

    if(tcl_ret)
    {
        free_stat_buf(stat_buf);

        std::ostringstream msg;
        msg << "stat(" << Tcl_GetStringFromObj(path, nullptr)<< "): " << strerror(errno);
        throw std::runtime_error(msg.str());
    }

    return stat_buf;
}

path_stat::path_stat(Tcl_Obj* path)
    : m_stat_buf(create_stat_buf(path))
{}

bool path_stat::is_dir() const
{
    unsigned mode = Tcl_GetModeFromStat(m_stat_buf);
    return S_ISDIR(mode);
}

path_stat::~path_stat()
{
    free_stat_buf(m_stat_buf);
}

/**************fs_path******************************/
fs_path::fs_path(Tcl_Obj* path)
    : m_path(path)
{
    if(path == nullptr)
    {
        throw std::logic_error("null path");
    }
    Tcl_IncrRefCount(path);
}
fs_path::fs_path(const std::string& path)
    : fs_path(Tcl_NewStringObj(path.data(), path.size()))
{}

fs_path::fs_path(const fs_path& other)
{
    m_path = other.m_path;
    Tcl_IncrRefCount(m_path);
}

bool fs_path::exists() const
{
    int access = Tcl_FSAccess(m_path, F_OK);

    return (access == 0);
}

bool fs_path::is_dir() const
{
    return path_stat(m_path).is_dir();
}

bool fs_path::operator==(const fs_path& rhs) const
{
    return Tcl_FSEqualPaths(m_path, rhs.m_path);
}

fs_path::operator bool() const
{
    int length = 0;
    (void)Tcl_GetStringFromObj(m_path, &length);

    return (length > 0);
}

/*TODO: We need a common result struct that has code and message.*/
bool fs_path::copy_to(const fs_path& dest) const
{
    if(is_dir())
    {
        if(!dest.is_dir())
        {
            Tcl_Obj* error = nullptr;
            int tcl_ret = Tcl_FSCopyDirectory(m_path, dest.m_path, &error);
            if(tcl_ret == -1)
            {
                std::cerr << "Error copying directory: " << str() << "->" << dest.str() << std::endl;
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
    return Tcl_GetStringFromObj(m_path, nullptr);
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
    int tcl_error = Tcl_FSMatchInDirectory(interp.get(), result_list.obj, m_path,
                                            dir_name.c_str(), &globtype);

    if(tcl_error)
    {
        //log debug
        const char* result_str = Tcl_GetStringResult(interp.get());
        std::cerr << "Failed to find image '" << dir_name << "': " << result_str << std::endl;
        return nullptr;
    }

    int length = 0;
    tcl_error = Tcl_ListObjLength(interp.get(), result_list.obj, &length);
    if(!tcl_error && length > 1)
    {
        std::ostringstream msg;
        msg << "Multiple images found for name: " << dir_name;
        throw std::runtime_error(msg.str());
    }

    Tcl_Obj* image_path = nullptr;
    tcl_error = Tcl_ListObjIndex(interp.get(), result_list.obj, 0, &image_path);
    assert(!tcl_error);
    assert(image_path);

    if(image_path)
    {
        return fs_path(image_path);
    }
    else
    {
        return fs_path("");
    }
}

fs_path::~fs_path()
{
    Tcl_DecrRefCount(m_path);
}

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
