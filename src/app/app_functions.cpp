#include "app_functions.h"
#include "fs.h"
#include <iostream>

using namespace appc::funcs;

void appc::funcs::auto_unmount(appc::mountpoint* mnt)
{
    if(mnt == nullptr)
    {
        return;
    }

    int err = mnt->unmount(MNT_WAIT);
    if(err)
    {
        std::cerr << "Error unmounting: " << strerror(errno) << std::endl;
    }
}

auto_unmount_ptr
appc::funcs::mount_container_image(commandline &cmdline, environment& env)
{
    fs_path image_path = env.find_image(cmdline.image);
    if(image_path)
    {
        std::cerr << "Image found: " << image_path.str() << std::endl;
    }
    else
    {
        std::cerr << "No image found" << std::endl;
    }

    std::cerr << "container: " << cmdline.container << std::endl;
    fs_path container_dir = env.find_container(cmdline.container);
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

    return mntpoint;
}
