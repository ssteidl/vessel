#include "image_archive.h"

#include <archive.h>
#include <archive_entry.h>
#include <cassert>
#include <fcntl.h>
#include "fs.h"
#include <iostream>
#include <paths.h>
#include <signal.h>
#include <sstream>
#include <sys/resource.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>
using namespace appc;

namespace
{
    void compress_image(fs_path image)
    {
        //TODO: Fix this up
        struct archive *image_archive = archive_write_new();

        (void)archive_write_set_format_pax(image_archive);
        (void)archive_write_add_filter_xz(image_archive);
        archive_write_set_bytes_per_block(image_archive, 10);

        //TODO: use image + .xz
        int archive_error = archive_write_open_filename(image_archive,
                                                        "/usr/home/shane/compresstest.xz");
        if(archive_error)
        {
            //TODO: Throw exception
            std::cerr << "Error opening file for write: " << archive_error_string(image_archive)
                      << std::endl;
        }

        //RAII
        int fd = open(image.str().c_str(), O_RDONLY);
        if(fd == -1)
        {
            perror("open");
            exit(1);
        }

        char buffer[BUFSIZ];
        memset(buffer, 0, sizeof(buffer));

        ssize_t bytes_read = 0;
        size_t total_bytes_read = 0;
        archive_entry* entry = archive_entry_new2(image_archive);

        struct stat sb;
        int error = fstat(fd, &sb);
        if(error)
        {
            perror("stat");
            exit(1);
        }

        archive_entry_copy_stat(entry, &sb);
        archive_entry_set_pathname(entry, image.str().c_str());
        //TODO: set fflags
        int header_error = archive_write_header(image_archive, entry);
        assert(header_error == ARCHIVE_OK);
        while(true)
        {
            //TODO: Some sort of progress callback
            bytes_read = read(fd, buffer, sizeof(buffer));
            if(bytes_read == -1)
            {
                perror("read");
                exit(1);
            }
            else if(bytes_read == 0)
            {
                break;
            }

            ssize_t bytes_written = archive_write_data(image_archive, buffer, bytes_read);
        }

        std::cerr << "bytes: " << total_bytes_read << std::endl;
        archive_write_free(image_archive);
        ::close(fd);
    }

    /**
     * @brief run_makefs Runs the "makefs" utility to create a ufs image.
     * @param source Directory which will be made into an image
     * @param dest Path the the image file which will be created.
     * @return Returns the exit code from makefs.
     */
    int run_makefs(fs_path source,
                   fs_path dest)
    {
        //TODO: mask sigchild and other necessary signals. Perhaps just
        //use SA_RESTART for now.
        pid_t child_pid = fork();

        //TODO: Implement details.
        switch(child_pid)
        {
        case -1:
        {
            std::ostringstream msg;
            msg << "Error forking makefs subprocess: " << strerror(errno);
            throw std::runtime_error(msg.str());
            break;
        }
        case 0:
        {
            //child
            std::vector<char const*> args;
            std::string src_str = source.str();
            std::string dest_str = dest.str();
            args.push_back("makefs");
            args.push_back("-t");
            args.push_back("ffs");
            args.push_back(dest_str.c_str());
            args.push_back(src_str.c_str());
            args.push_back(nullptr);

            for(auto arg : args)
            {
                if(arg == nullptr)
                {
                    break;
                }
                std::cerr << arg << " ";
            }
            std::cerr << std::endl;
            int error = execvp("makefs", (char* const*)args.data());
            if(error)
            {
                std::ostringstream msg;
                msg << "Error exec'ing makefs: " << strerror(errno);
                throw std::runtime_error(msg.str());
            }
        }
            break;
        default:
        {

            int status = 0;
            __wrusage resources;
            siginfo_t siginfo;
            pid_t pid = wait6(P_PID, child_pid, &status, WEXITED,
                              &resources, &siginfo);

            std::cerr << "Wait6 return: " << pid << std::endl;
            //TODO: Do something with the resources and siginfo.  We should
            //return an object with easy access to all the info returned from
            //the wait6 call.  It should have a stream operator function so
            //we can easily output the info.
            if(pid == -1)
            {
                //TODO: Need timeout.  This can be done when we
                //switch to async/kqueue
                std::ostringstream msg;
                msg << "Error waiting for makefs: " << strerror(errno);
                throw std::runtime_error(msg.str());
            }

            if(pid > 0)
            {
                return WEXITSTATUS(status);
            }
            break;
        }
        }

        //Shouldn't get here.
        throw std::logic_error("Unhandled case in makefs");
    }
}

int appc::create_image_archive(const fs_path &source, const fs_path &dest)
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

    std::cerr << "dest: " << dest.str() << std::endl;
    return run_makefs(source, dest);
}
