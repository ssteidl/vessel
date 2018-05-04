#include <cassert>
#include <cstdlib>
#include <getopt.h>
#include <iostream>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>

namespace {
struct commandline
{
    static constexpr struct option long_options[] = {
        {"name", required_argument, nullptr, 'n'},
        {"container", required_argument, nullptr, 'c'},
        {nullptr, 0, nullptr, 0}
    };

public:
    std::string name;
    std::string container;
    
    static void usage()
    {
        std::cerr << "USAGE: appc --name=<app-name> --container=<container-name>"
                  << std::endl;
    }

    static std::unique_ptr<commandline> parse(int argc, char** argv)
    {
        std::unique_ptr<commandline> _this = std::make_unique<commandline>();
        int ch = 0;
        while((ch = getopt_long(argc, argv, "n:c:", long_options, nullptr)) != -1)
        {
            switch(ch)
            {
            case 'n':
                _this->name = optarg;
                break;
            case 'c':
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
            std::cerr << "ERROR: 'container' is required" << std::endl;
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

}

int run_main(int argc, char** argv)
{
    /*Process commandline arguments
     * - name: name of the container
     * - container: Name of the filesystem container in the registry
     */
    std::unique_ptr<commandline> cmdline = commandline::parse(argc, argv);
    if(!cmdline)
    {
        exit(1);
    }

    std::cerr << "Name: " << cmdline->name << ", Container: " << cmdline->container << std::endl;

    /*Registry path is in the environment APPC_REGISTRY_PATH,
     * top level directory where container folders are created is
     * in APPC_CONTAINER_DIR*/
    std::string registry_path = get_env_required("APPC_REGISTRY_PATH");

    return 0;
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
