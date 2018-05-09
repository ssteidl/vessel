#include <cassert>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <getopt.h>
#include <iostream>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/stat.h>
#include <tcl.h>
#include <unistd.h>

namespace {
struct commandline
{
    static constexpr struct option long_options[] = {
        {"name", required_argument, nullptr, 'n'},
        {"image", required_argument, nullptr, 'i'},
        {nullptr, 0, nullptr, 0}
    };

public:
    std::string name;
    std::string container;
    
    static void usage()
    {
        std::cerr << "USAGE: appc --name=<app-name> --image=<image-name>"
                  << std::endl;
    }

    static std::unique_ptr<commandline> parse(int argc, char** argv)
    {
        std::unique_ptr<commandline> _this = std::make_unique<commandline>();
        int ch = 0;
        while((ch = getopt_long(argc, argv, "n:i:", long_options, nullptr)) != -1)
        {
            switch(ch)
            {
            case 'n':
                _this->name = optarg;
                break;
            case 'i':
                _this->container = optarg;
                break;
            default:
                usage();
            }
        }

        if(_this->name.empty())
        {
            std::cerr << "ERROR: 'name' is required" << std::endl;
            usage();
            return nullptr;
        }

        if(_this->container.empty())
        {
            std::cerr << "ERROR: 'image' is required" << std::endl;
            usage();
            return nullptr;
        }

        return _this;
    }
};

std::string get_env_required(const std::string& name)
{
    assert(!name.empty());

    char* value = getenv(name.c_str());

    if(value == nullptr)
    {
        std::ostringstream msg;
        msg << "'" << name << "' is a required environment variable";
        throw std::runtime_error(msg.str());
    }

    return std::string(value);
}

class path_stat
{
private:
    Tcl_StatBuf* m_stat_buf;

    friend class fs_path;

    void free_stat_buf(Tcl_StatBuf* stat_buf)
    {
        if(stat_buf)
        {
            ckfree(stat_buf);
        }
    }

    Tcl_StatBuf*
    create_stat_buf(Tcl_Obj* path)
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

    path_stat(Tcl_Obj* path)
        : m_stat_buf(create_stat_buf(path))
    {}

public:

    bool is_dir() const
    {
        unsigned mode = Tcl_GetModeFromStat(m_stat_buf);
        return S_ISDIR(mode);
    }

    ~path_stat()
    {
        free_stat_buf(m_stat_buf);
    }
};

class tcl_obj_list
{
    std::vector<Tcl_Obj*>
public:
}

class fs_path
{
private:
    Tcl_Obj* m_path;

    //TODO These can be implemented if needed
    fs_path(fs_path&& other) = delete;
    fs_path& operator=(const fs_path& rhs) = delete;
    fs_path& operator=(fs_path&& rhs) = delete;

public:

    fs_path(Tcl_Obj* path)
        : m_path(path)
    {
        Tcl_IncrRefCount(path);
    }
    fs_path(const std::string& path)
        : fs_path(Tcl_NewStringObj(path.data(), path.size()))
    {}

    fs_path(const fs_path& other)
    {
        m_path = other.m_path;
        Tcl_IncrRefCount(m_path);
    }

    bool exists() const
    {
        int access = Tcl_FSAccess(m_path, F_OK);

        return (access == 0);
    }

    bool is_dir() const
    {
        return path_stat(m_path).is_dir();
    }

    bool operator==(const fs_path& rhs) const
    {
        return Tcl_FSEqualPaths(m_path, rhs.m_path);
    }

    /*TODO: We need a common result struct that has code and message.*/
    bool copy_to(const fs_path& dest) const
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

    std::string str() const
    {
        return Tcl_GetStringFromObj(m_path, nullptr);
    }

    ~fs_path()
    {
        Tcl_DecrRefCount(m_path);
    }
};

void validate_directory(const fs_path& path)
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

/*NOTE: Ideally we support .iso, vnode backed images and tarballs (or any
 *file compression*/
class directory_image
{
    fs_path m_path;
    std::string m_name;
public:

    /*API:
     * -unpack(): Unzip to image directory
     */

    void unpack(const fs_path& destination)
    {
        //For now, a directory image is just copied to the appc_image_dir.

    }
};

/**
 * @brief The registry class is responsible for fetching the
 * image stack from some source.  That source may be filesystem,
 * ftp, https or some other source.
 */
class registry
{

};

/**
 * @brief The image_stack class represents a stack of images
 * that need to be mounted ontop of each other.
 */
class image_stack
{
    /* - stack of images that will be mounted
     * - mount(): mount the image stack using unionfs
     */
};

struct tcl_obj_raii
{
    Tcl_Obj* obj;

    tcl_obj_raii(Tcl_Obj* obj)
        : obj(obj)
    {
        if(obj)
        {
            Tcl_IncrRefCount(obj);
        }
    }

    ~tcl_obj_raii()
    {
        if(obj)
        {
            Tcl_DecrRefCount(obj);
        }
    }

private:
    tcl_obj_raii(const tcl_obj_raii&) = delete;
    tcl_obj_raii(tcl_obj_raii&&) = delete;
    tcl_obj_raii operator=(const tcl_obj_raii&) = delete;
    tcl_obj_raii operator=(tcl_obj_raii&&) = delete;
};

class appc_environment
{
    fs_path m_image_dir;

public:

    appc_environment(const fs_path& image_dir)
        : m_image_dir(image_dir)
    {}

    std::unique_ptr<fs_path>
    find_image(const std::string& image)
    {
        std::unique_ptr<Tcl_Interp, decltype(Tcl_DeleteInterp)>
                interp(Tcl_CreateInterp(), Tcl_DeleteInterp);

        tcl_obj_raii result_list = Tcl_NewListObj(0, nullptr);

        //Search for a folder with the image name in the appc_image_dir
        int tcl_error = Tcl_FSMatchInDirectory(interp.get(), result_list.obj, m_image_dir.m_path,
                                                image.c_str(), TCL_GLOB_TYPE_DIR);

        if(tcl_error)
        {
            //log debug
            const char* result_str = Tcl_GetStringResult(interp.get());
            std::cerr << "Failed to find image '" << image << "': " << result_str << std::endl;
            return nullptr;
        }

        int length = 0;
        tcl_error = Tcl_ListObjLength(interp.get(), result_list.obj, &length);
        if(!tcl_error && length > 1)
        {
            std::ostringstream msg;
            msg << "Multiple images found for name: " << image;
            throw std::runtime_error(msg.str());
        }

        Tcl_Obj* image_path = nullptr;
        tcl_error = Tcl_ListObjIndex(interp.get(), result_list.obj, 0, &image_path);
        assert(!tcl_error);
        assert(image_path);

        return std::make_unique<fs_path>(image_path);
    }

    /*API:
     * -find_image(name)
     * -create_image_obj(name)
     */
};

int run_main(int argc, char** argv)
{
    /*Process commandline arguments
     * - name: name of the container
     * - image: Name of the filesystem image in the registry
     */
    std::unique_ptr<commandline> cmdline = commandline::parse(argc, argv);
    if(!cmdline)
    {
        exit(1);
    }

    std::cerr << "Name: " << cmdline->name << ", Image: " << cmdline->container << std::endl;

    /*Registry path is in the environment APPC_REGISTRY,
     * top level directory where container folders are created is
     * in APPC_IMAGE_DIR*/
    std::string registry_path_str = get_env_required("APPC_REGISTRY");
    fs_path registry_path(registry_path_str);
    validate_directory(registry_path);

    std::string image_dir_path_str = get_env_required("APPC_IMAGE_DIR");
    fs_path image_dir(image_dir_path_str);
    validate_directory(image_dir);

    /*TODO: We probably need an APPC_CONTAINER_DIR which is where images are
     * unpacked and containers get run using those images.*/

    appc_environment environment(image_dir);
    std::unique_ptr<fs_path> image = environment.find_image(cmdline->name);
    if(!image)
    {
        std::cerr << "Image not found: '" << cmdline->name << "'" << std::endl;
        return 1;
    }

    /*Next steps:
     * 1. bind the image to wherever it needs to go in the container
     * directory.
     * 2. Run tcl script to setup the jail
     * 3. Start the jail
     */

    return 0;
}
}

int main(int argc, char** argv)
{
    int exit_code = 1;
    try
    {
        exit_code = run_main(argc, argv);
    }
    catch(std::exception& e)
    {
        std::cerr << "Fatal Error: " << e.what() << std::endl;
    }
    catch(...)
    {
        std::cerr << "Fatal Error: " << "Unspecified" << std::endl;
    }

    exit(exit_code);
}
