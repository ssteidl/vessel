#include <cerrno>
#include "exec.h"
#include <fcntl.h>
#include <iostream>
#include <sstream>
#include <string>
#include <termios.h>
#include <vector>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>

namespace
{

    int dup_fd(int old_fd, int new_fd, const std::string& fd_name, int error_fd = 2)
    {
        std::cerr << getpid() << ": " << old_fd << "->" << new_fd << std::endl;
        new_fd = dup2(old_fd, new_fd);
        if(new_fd == -1)
        {
            std::ostringstream msg;
            msg << fd_name << " dup2: " << strerror(errno) << std::endl;
            ssize_t bytes_written = write(error_fd, msg.str().c_str(), msg.str().size());
            assert(bytes_written >= 0);
            return -1;
        }

        return 0;
    }
}

int Appc_Exec(void *clientData, Tcl_Interp *interp,
              int objc, struct Tcl_Obj *const *objv)
{
    (void)clientData;

    if(objc < 3)
    {
        Tcl_WrongNumArgs(interp, objc, objv, "<fd_dict> cmd...");
        return TCL_ERROR;
    }

    int stdin_fd = 0;
    int stderr_fd = 1;
    int stdout_fd = 2;

    Tcl_Obj* fd_dict = objv[1];
    Tcl_DictSearch search;
    Tcl_Obj* key = nullptr;
    Tcl_Obj* value = nullptr;
    int done;
    int tcl_error = TCL_OK;
    for(tcl_error = Tcl_DictObjFirst(interp, fd_dict, &search, &key, &value, &done);
        done == 0;
        Tcl_DictObjNext(&search, &key, &value, &done))
    {
        int handle = -1;
        if(std::string("stdin") == Tcl_GetString(key))
        {
            Tcl_Channel stdin = Tcl_GetChannel(interp, Tcl_GetString(value), nullptr);
            if(stdin == nullptr) return TCL_ERROR;

            tcl_error = Tcl_GetChannelHandle(stdin, TCL_READABLE, (void**)&handle);
            if(tcl_error)
            {
                Tcl_SetObjResult(interp, Tcl_NewStringObj("Error getting stdin handle from fd_dict", -1));
                return tcl_error;
            }

            stdin_fd = handle;
        }
        else if(std::string("stdout") == Tcl_GetString(key))
        {
            Tcl_Channel stdout = Tcl_GetChannel(interp, Tcl_GetString(value), nullptr);
            if(stdout == nullptr) return TCL_ERROR;

            tcl_error = Tcl_GetChannelHandle(stdout, TCL_WRITABLE, (void**)&handle);
            if(tcl_error)
            {
                Tcl_SetObjResult(interp, Tcl_NewStringObj("Error getting stdout handle from fd_dict", -1));
                return tcl_error;
            }

            stdout_fd = handle;
        }
        else if(std::string("stderr") == Tcl_GetString(key))
        {
            Tcl_Channel stderr = Tcl_GetChannel(interp, Tcl_GetString(value), nullptr);
            if(stderr == nullptr) return TCL_ERROR;

            tcl_error = Tcl_GetChannelHandle(stderr, TCL_WRITABLE, (void**)&handle);
            if(tcl_error)
            {
                Tcl_SetObjResult(interp, Tcl_NewStringObj("Error getting stdout handle from fd_dict", -1));
                return tcl_error;
            }

            stderr_fd = handle;
        }
    }

    /*Now create the vector of arguments so that we can fork/exec*/
    std::vector<char*> args;
    for(int i = 0; i < objc; ++i)
    {
        std::cerr << "objc: " << objc << ", " << Tcl_GetString(objv[i]) << std::endl;
    }
    for(int i = 2; i < objc; ++i)
    {
        std::cerr << "YO: " << Tcl_GetString(objv[i]) << std::endl;
        args.push_back(Tcl_GetString(objv[i]));
    }
    args.push_back(nullptr);

    pid_t pid = fork();

    switch(pid)
    {
    case 0:
    {
        /*Child*/
//        close(stdin_fd);
//        close(stdout_fd);
//        close(stderr_fd);

        int masterfd = posix_openpt(O_RDWR);
        if(masterfd == -1)
        {
            perror("openpt");
            exit(1);
        }

        int error = grantpt(masterfd);
        if(error == -1)
        {
            perror("grantpg");
            exit(1);
        }

        error = unlockpt(masterfd);
        if(error == -1)
        {
            perror("unlockpt");
            exit(1);
        }

        std::cerr << "ptname: " << ptsname(masterfd) << std::endl;

        stdin_fd = masterfd;
        stdout_fd = masterfd;
        stderr_fd = masterfd;

        /*I don't think we want to touch the interp as even deleting it calls
         * deletion callbacks*/

        pid_t process_grpid = 0;
        if(isatty(stdin_fd))
        {
            int tmp_stderr = 2;//fcntl(2, F_DUPFD_CLOEXEC);
            int fd = open("/usr/home/shane/shane.log", O_WRONLY | O_CREAT);

            process_grpid = setsid();

            std::cerr << "setsid" << std::endl;
            if(process_grpid == (int)-1)
            {
                perror("setsid");
                exit(1);
            }

            signal(SIGHUP, SIG_IGN);

            std::cerr << "tcsetsid" << std::endl;
            error = tcsetsid(stdin_fd, process_grpid);
            if(error == -1)
            {
                 perror("tcsetsid");
                 exit(1);
            }

            error = tcsetpgrp(stdin_fd, 0);

            pid_t shell_pid = fork();
            switch(shell_pid)
            {
            default:
            {
                error = setpgid(shell_pid, 0);
//                if(error == -1)
//                {
//                    perror("setpgid");
//                    _exit(1);
//                }

                error = tcsetpgrp(stdin_fd, shell_pid);
//                if(error == -1)
//                {
//                    std::ostringstream msg;
//                    msg << "tcsetpgrp: " << strerror(errno) << std::endl;
//                    write(tmp_stderr, msg.str().c_str(), msg.str().size());
//                    exit(1);
//                }

                int status = 0;
                wait(&status);
                _exit(1);
            }
                break;
            case 0:

                break;
            case -1:
                perror("second fork");
                _exit(1);
            }

            /*shell child*/
            std::cerr << "Process: " << getpid() << ", terminal: " << tcgetsid(stdin_fd) << std::endl;

            error = setpgid(getpid(), getpid());
//            if(error == -1)
//            {
//                perror("setpgid2");
//                _exit(1);
//            }

            error = tcsetpgrp(stdin_fd, getpid());
//            if(error == -1)
//            {
//                std::ostringstream msg;
//                msg << "tcsetpgrp2: " << strerror(errno) << std::endl;
//                write(tmp_stderr, msg.str().c_str(), msg.str().size());
//                exit(1);
//            }

            signal(SIGHUP, SIG_DFL);

            error = dup_fd(stdin_fd, 0, "stdin");
            if(error) exit(1);

            error = dup_fd(stdout_fd, 1, "stdout");
            if(error) exit(1);

            error = dup_fd(stderr_fd, 2, "stderr", tmp_stderr);
            if(error) exit(1);

            closefrom(3);
            /*For now we keep the same environment or at least don't do anything special
             * to change the environment.  In the future we can use exect to setup environment
             * and do things with resource control, etc.*/
            error = execvp(args[0], args.data());
            if(error)
            {
                std::ostringstream msg;
                msg << "execvp error: " << strerror(errno) << std::endl;
                exit(1);
            }

        }
        exit(1);
    }
    case -1:
        Tcl_SetResult(interp, (char*)Tcl_ErrnoMsg(errno), TCL_STATIC);
        return TCL_ERROR;
    default:
    {
        /*Parent*/
        /*TODO: Monitor process using kqueue with tcl event source*/

        /*For initial testing just do a waitpid*/
//        std::cerr << "Waiting for child process: " << pid << std::endl;
//        int status = 0;
//        pid_t waitedpid = waitpid(pid, &status, 0);
//        std::cerr << "Waited on: " << waitedpid << ": " << WIFEXITED(status) << ","
//                  << WIFCONTINUED(status) << "," << WIFSIGNALED(status) << ","
//                  << WIFSTOPPED(status)<< std::endl;
//        std::cerr << "Signal: " << WTERMSIG(status) << std::endl;
//        if(waitedpid != (pid_t)-1)
//        {
//            std::cerr << "Exit status: " << WEXITSTATUS(status) << std::endl;
//            Tcl_SetObjResult(interp, Tcl_NewIntObj(waitedpid));
//        }
//        else
//        {
//            std::ostringstream msg;
//            msg << "wait() " << Tcl_PosixError(interp);
//            Tcl_SetResult(interp, (char*)msg.str().c_str(), TCL_VOLATILE);
//            return TCL_ERROR;
//        }
        break;
    }
    }


    return TCL_OK;
}
