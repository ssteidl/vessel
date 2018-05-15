#include <cassert>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include "fs.h"
#include <getopt.h>
#include <iostream>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/stat.h>
#include <unistd.h>

using namespace appc;

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

//class tcl_obj_list
//{
//    std::vector<Tcl_Obj*>
//public:
//}

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
 *
 * NOTE: Remote zfs support would be a killer feature.  i.e. using zsend
 * and zrecv to retrieve images.
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

class appc_environment
{
    fs_path m_image_dir;

public:

    appc_environment(const fs_path& image_dir)
        : m_image_dir(image_dir)
    {}

    fs_path find_image(const std::string& image_name)
    {
        return m_image_dir.find_dir(image_name);
    }
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

    /*APPC_REGISTRY is the url to the registry.  It could potentially
     * support multiple different protocols*/
    std::string registry_path_str = get_env_required("APPC_REGISTRY");
    fs_path registry_path(registry_path_str);
    validate_directory(registry_path);

    /*APPC_IMAGE_DIR is the directory where images are extracted to after
     * being downloaded from a registry*/
    std::string image_dir_path_str = get_env_required("APPC_IMAGE_DIR");
    fs_path image_dir(image_dir_path_str);
    validate_directory(image_dir);

    /*APPC_CONTAINER_DIR is where container directories are created.  Inside
     * container directories lives the mounted image(s).  The mount may be
     * a null mount from the image contained in APPC_IMAGE_DIR or it could be
     * vnode back mem disk, or zfs clone or any number of mount options.
     */
    std::string appc_container_dir_str = get_env_required("APPC_CONTAINER_DIR");
    fs_path appc_container_dir(appc_container_dir_str);
    validate_directory(appc_container_dir);

    appc_environment environment(image_dir);
    fs_path image = environment.find_image(cmdline->name);
    if(!image)
    {
        std::cerr << "Image not found: '" << cmdline->name << "'" << std::endl;
        return 1;
    }



    /*Next steps:
     * 1. bind the image to wherever it needs to go in the container
     * directory.
     * 2. Run tcl script to setup the jail (get script from command line.  can be empty)
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
