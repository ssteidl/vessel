#include <archive.h>
#include <archive_entry.h>
#include <cassert>
#include <iostream>
#include <fcntl.h>
#include <sys/stat.h>

int main(int argc, char** argv)
{
    struct archive *image_archive = archive_write_new();

    (void)archive_write_set_format_pax(image_archive);
    (void)archive_write_add_filter_xz(image_archive);
    archive_write_set_bytes_per_block(image_archive, 10);
    int archive_error = archive_write_open_filename(image_archive,
                                                    "/usr/home/shane/compresstest.xz");
    if(archive_error)
    {
        std::cerr << "Error opening file for write: " << archive_error_string(image_archive)
                  << std::endl;
    }

    int fd = open("/usr/home/shane/compresstest", O_RDONLY);
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
    archive_entry_set_pathname(entry, "compresstest");
    //TODO: set fflags
    int header_error = archive_write_header(image_archive, entry);
    assert(header_error == ARCHIVE_OK);
    while(true)
    {
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
