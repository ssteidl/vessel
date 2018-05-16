#include "environment.h"
#include <iostream>
#include "mountpoint.h"

using namespace appc;

int run_main(int argc, char** argv)
{
    Tcl_FindExecutable(argv[0]);

    environment env;
    fs_path image_path = env.find_image("shane*");
    if(image_path)
    {
        std::cerr << "Image found: " << image_path.str() << std::endl;
    }
    else
    {
        std::cerr << "No image found" << std::endl;
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
