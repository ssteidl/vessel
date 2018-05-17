#ifndef ENVIRONMENT_H
#define ENVIRONMENT_H

#include "fs.h"

namespace appc
{
    class environment
    {
        fs_path m_image_dir;
        fs_path m_container_dir;

        environment(environment&& other) = delete;
        environment& operator=(environment&& other) = delete;
    public:

        environment();

        fs_path find_image(const std::string& image_name);
        fs_path find_container(const std::string& container_name);

    };

}
#endif // ENVIRONMENT_H
