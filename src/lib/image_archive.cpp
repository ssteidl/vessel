#include "image_archive.h"

#include "fs.h"
#include <paths.h>
#include <sstream>
#include <unistd.h>
#include <vector>
using namespace appc;

namespace
{
    enum makefs_type
    {
        UFS,
        CD9660
    };

    int run_makefs(makefs_type fstype,
                   fs_path source,
                   fs_path dest)
    {
        std::vector<char*> args;
        args.push_back("makefs");
        args.push_back("-t");
        args.push_back("ffs");
        args.push_back(dest.str().c_str());
        args.push_back(source.str().c_str());

        interp_ptr interp = create_tcl_interp();
        pid_t child_pid = fork();

        //TODO: Implement details.
        switch(child_pid)
        {
        case -1:

            break;
        case 0:
            //child
            //exec makefs
            break;
        default:
            //wait child
            break;
        }
    }
}

void appc::create_image_archive(const fs_path &source, const fs_path &dest)
{
    if(!source.exists())
    {
        std::ostringstream msg;
        msg << "Image source does not exist: " << source.str();
        throw std::runtime_error(msg.str());
    }

    if(!source.is_dir() || !source.is_readable())
    {
        std::ostringstream msg;
        msg << "Source of image archive is not a readable directory: " << source.str();
        throw std::runtime_error(msg.str());
    }

    if(dest.exists())
    {
        std::ostringstream msg;
        msg << "Destination for archive already exists: " << dest.str();
        throw std::runtime_error(msg.str());
    }


}
