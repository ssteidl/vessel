#ifndef CMDLINE_H
#define CMDLINE_H

#include <string>
#include <vector>

namespace appc
{

struct commandline
{
public:
    std::string image;
    std::string container;
    std::vector<char*> container_cmd_args;

    static void usage();

    static std::unique_ptr<commandline> parse(int argc, char** argv);
};
}
#endif // CMDLINE_H
