#include "cmdline.h"
#include "environment.h"
#include <iostream>
#include <limits.h>
#include "mountpoint.h"
#include <unistd.h>

extern "C"
{
#include <sys/jail.h>
}
using namespace appc;

namespace
{
    void auto_unmount(mountpoint* mnt)
    {
        std::cerr << "Unmounting..." << std::endl;
        int err = mnt->unmount(MNT_WAIT);
        if(err)
        {
            std::cerr << "Error unmounting: " << strerror(errno) << std::endl;
        }
    }

    using auto_unmount_ptr = std::unique_ptr<mountpoint, decltype(&auto_unmount)>;
}

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

    auto_unmount_ptr mntpoint(create_nullfs_mount(image_path, container_dir, 0).release(),
                              auto_unmount);

    std::cerr << "Mounting" << std::endl;
    int error = mntpoint->mount();
    if(error)
    {
        std::cerr << "Mount failed: " << mntpoint->error_message() << std::endl
                  << "system error: " << strerror(errno) << std::endl;
        exit(1);
    }

    /*This belongs in a jail object that is destroyed when it goes out
     * of scope
     */
//    struct jail j;
//    memset(&j, 0, sizeof(j));
//    j.hostname = (char*)"ShaneJail";
//    j.jailname = (char*)cmdline->container.c_str();
//    j.version = JAIL_API_VERSION;
//    j.path = (char*)container_dir.str().c_str();

//    int jail_id = ::jail(&j);

//    if(jail_id != -1)
//    {
//        char hostname[_POSIX_HOST_NAME_MAX];
//        gethostname(hostname, sizeof(hostname));
//        std::cerr << "I'm in a jail!! " << jail_id << " Hostname: " << hostname << std::endl;
//        error = jail_remove(jail_id);
//        if(error)
//        {
//            std::cerr << "Error removing jail: " << strerror(errno) << std::endl;
//        }
//    }
//    else
//    {
//        std::cerr << "Jail error: " << strerror(errno) << std::endl;
//    }
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
