#include <iostream>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>
#include <sys/wait.h>
#include <signal.h>
#include <vector>

int main(int argc, char** argv)
{
    std::cerr << "Forking child" << std::endl;
    std::string slave_path = argv[1];

    pid_t fork1_pid = fork();

    switch(fork1_pid)
    {
    case -1:
        perror("fork1()");
        exit(1);
    case 0:
        std::cerr << "Child: " << getpid() << std::endl;
        break;
    default:

        std::cerr << "Waiting for child session leader" << std::endl;
        int status = 0;
        pid_t wait_pid = wait(&status);
        std::cerr << "Waited on: " << wait_pid << ": " << WIFEXITED(status) << ","
                          << WIFCONTINUED(status) << "," << WIFSIGNALED(status) << ","
                          << WIFSTOPPED(status)<< std::endl;
                std::cerr << "Signal: " << WTERMSIG(status) << std::endl;
        exit(0);
    }

    int slave_fd = open(argv[1], O_RDWR);
    /*Session leader process*/

    termios tios;
    tcgetattr(slave_fd, &tios);

//    tios.c_oflag |= OPOST | ONLCR | ONLRET;
//    std::cerr << "oflag" << tios.c_oflag << std::endl;
//    tios.c_oflag &= ~ONOCR;
//    std::cerr << "oflag" << tios.c_oflag << std::endl;
//    tios.c_lflag |= ICANON;
//    tcsetattr(master_fd, TCSANOW, &tios);

    pid_t sl_process_grpid = setsid();
    signal(SIGHUP, SIG_DFL);

    int error = tcsetsid(slave_fd, sl_process_grpid);
    if(error == -1)
    {
        perror("tcsetsid");
        exit(1);
    }

    dup2(slave_fd, 0);
    dup2(slave_fd, 1);
    dup2(slave_fd, 2);
    error = tcsetpgrp(slave_fd, sl_process_grpid);
    if(error == -1)
    {
        perror("tcsetpgrp");
    }

//    tcgetattr(slave_fd, &tios);
//    tios.c_lflag &= ~ICANON;
//    tcsetattr(slave_fd, TCSANOW, &tios);
    std::vector<char*> args = {"bash", nullptr};
    error = execvp("bash", args.data());
    perror("execvp");
    exit(1);
}
