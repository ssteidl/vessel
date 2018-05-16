#include <cassert>
#include "environment.h"
#include <sstream>

using namespace appc;

namespace
{
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

    fs_path get_env_required_dir(const std::string& name)
    {
        fs_path dir_path = get_env_required(name);
        validate_directory(dir_path);
        return dir_path;
    }
}

environment::environment()
    : m_image_dir(get_env_required_dir("APPC_IMAGE_DIR")),
      m_container_dir(get_env_required_dir("APPC_CONTAINER_DIR"))
{}

fs_path environment::find_image(const std::string& image_name)
{
    return m_image_dir.find_dir(image_name);
}
