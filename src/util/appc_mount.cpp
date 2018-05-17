#include "cmdline.h"
#include "environment.h"
#include <iostream>
#include "mountpoint.h"

using namespace appc;

int run_main(int argc, char** argv)
{
    Tcl_FindExecutable(argv[0]);

    environment env;
    std::unique_ptr<commandline> cmdline = commandline::parse(argc, argv);

    if(!cmdline)
    {
        exit(1);
    }

    fs_path image_path = env.find_image(cmdline->image);
    if(image_path)
    {
        std::cerr << "Image found: " << image_path.str() << std::endl;
    }
    else
    {
        std::cerr << "No image found" << std::endl;
    }

    std::cerr << "container: " << cmdline->container << std::endl;
    fs_path container_dir = env.find_container(cmdline->container);
    if(container_dir)
    {
        std::cerr << "Container dir exists: " << container_dir.str() << std::endl;
    }
    else
    {
        throw std::runtime_error("NYI: Create container directory if it doesn't exist");
    }

    std::unique_ptr<mountpoint> mntpoint = create_nullfs_mount(image_path, container_dir,
                                                               0);

    std::cerr << "Mounting" << std::endl;
    int error = mntpoint->mount();
    if(error)
    {
        std::cerr << "Mount failed: " << mntpoint->error_message() << std::endl
                  << "system error: " << strerror(errno) << std::endl;
        exit(1);
    }

    return 0;
}

int main(int argc, char** argv)
{

    /*
     * Arguments:
     * --image: Name of the image.  appc_mount will look in APPC_IMAGE_DIR
     * to find the image, then nullfs mount the image to --name folder
     * in APPC_CONTAINER_DIR.
     */

    int exit_code = 1;
    try
    {
        exit_code = run_main(argc, argv);
    }
    catch(std::exception& ex)
    {
        std::cerr << ex.what() << std::endl;
    }
    catch(...)
    {
        std::cerr << "Unknown error occurred" << std::endl;
    }

    exit(exit_code);
}
