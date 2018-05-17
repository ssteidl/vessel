#include "cmdline.h"
#include <getopt.h>
#include <iostream>

using namespace appc;

namespace
{
    constexpr struct option long_options[] = {
        {"name", required_argument, nullptr, 'n'},
        {"image", required_argument, nullptr, 'i'},
        {nullptr, 0, nullptr, 0}
    };
}


void commandline::usage()
{
    std::cerr << "USAGE: appc --name=<container-name> --image=<image-name>"
              << std::endl;
}

std::unique_ptr<commandline> commandline::parse(int argc, char** argv)
{

    std::unique_ptr<commandline> _this = std::make_unique<commandline>();

    /*Capture all arguments after '--' to use as a container
     * command.  Update argc so those arguments are not passed
     * to getopt.
     */
    for(int i = 0; i < argc; i++)
    {
        std::string arg = argv[i];
        if(arg == "--")
        {
            for(int j = i + 1; j < argc; j++)
            {
                _this->container_cmd_args.push_back(argv[j]);
            }

            //Args needs to be null terminated to use with exec.
            _this->container_cmd_args.push_back(nullptr);
            argc = i;
            break;
        }
    }

    int ch = 0;
    while((ch = getopt_long(argc, argv, "n:i:", long_options, nullptr)) != -1)
    {
        switch(ch)
        {
        case 'n':
            _this->container = optarg;
            break;
        case 'i':
            _this->image = optarg;
            break;
        default:
            usage();
        }
    }

    if(_this->container.empty())
    {
        std::cerr << "ERROR: 'name' is required" << std::endl;
        usage();
        return nullptr;
    }

    if(_this->image.empty())
    {
        std::cerr << "ERROR: 'image' is required" << std::endl;
        usage();
        return nullptr;
    }

    return _this;
}
