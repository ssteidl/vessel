#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/select.h>
#include <stdlib.h>
#include <iostream>
#include <termios.h>
int main(int argc, char** argv)
{
    int master_fd = posix_openpt(O_RDWR);
    if(master_fd == -1)
    {
        perror("posix_openpt");
        exit(1);
    }


    grantpt(master_fd);
    unlockpt(master_fd);

    std::cerr << "pts: " << ptsname(master_fd) << std::endl;
    char input[512];
    ssize_t bytes_read = 0;

    termios tios;
    tcgetattr(0, &tios);
    tios.c_lflag &= ~ICANON;
    tios.c_lflag &= ~ECHO;
    cfmakeraw(&tios);
    tcsetattr(0, TCSANOW, &tios);
    tcsetattr(1, TCSANOW, &tios);

    cfmakesane(&tios);
    tcsetattr(master_fd, TCSANOW, &tios);
    for (;;)
    {
        fd_set set;
        FD_ZERO(&set);

        FD_SET(0, &set);
        FD_SET(master_fd, &set);
        int error = select(master_fd + 1, &set, nullptr, nullptr, nullptr);

        if(error == -1)
        {
            perror("select");
            exit(1);
        }

        if(FD_ISSET(0, &set))
        {
            bytes_read = read(0, input, sizeof(input));
            if(bytes_read == -1)
            {
                perror("read stdin");
                exit(1);
            }

            write(master_fd, input, bytes_read);
        }

        if(FD_ISSET(master_fd, &set))
        {
            bytes_read = read(master_fd, input, sizeof(input));

            if(bytes_read == 0)
            {
                std::cerr << "Exiting" << std::endl;
                exit(0);
            }

            if(bytes_read == -1)
            {
                perror("read stdin");
                exit(1);
            }

            write(1, input, bytes_read);
        }
    }

    return 0;
}
