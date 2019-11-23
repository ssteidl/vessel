#include <array>
#include <cerrno>
#include "exec.h"
#include <fcntl.h>
#include <iostream>
#include <set>
#include <sstream>
#include <string>
#include <termios.h>
#include <vector>
#include <unistd.h>
#include <sys/event.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include "tcl_util.h"

/*TODO: Consistent naming conventions*/
/*TODO: Better logging support.  There is too much logging to cerr for an extension*/
/*TODO: There are actually 3 potentially separate modules in this file.  kqueue, process monitoring
 * and exec*/
namespace
{
    struct kqueue_state
    {
        int kqueue_fd;
        bool ready;

        kqueue_state(int kqueue_fd)
            : kqueue_fd(kqueue_fd),
              ready(false)
        {}

        ~kqueue_state()
        {
            if(kqueue_fd != -1)
            {
                close(kqueue_fd);
            }
        }
    };

    /**
     * Class for monitoring a heirarchy of processes.
     */
    class monitored_process_group
    {
        pid_t m_child; /**< The process that was directly forked*/
        bool m_child_exited; /**< True if the child has exited.  Note that descendants
                               * can still be added if the child has exited.*/
        uint64_t m_child_exit_status = 0;

        std::set<pid_t> m_descendants; /**< Flattened set of descendant processes.*/

    public:
        monitored_process_group(pid_t child)
            : m_child(child),
              m_child_exited(false),
              m_descendants()
        {}

        void add_descendant(pid_t pid)
        {
            m_descendants.insert(pid);
        }

        /**
         * Remove pid from the monitor group.
         *
         * @returns true if all processes from the monitor group have exited.
         */
        bool exited(pid_t pid, uint64_t exit_status)
        {
            if(pid == m_child)
            {
                m_child_exited = true;
                m_child_exit_status = exit_status;

                std::cerr << "Waiting for child process: " << pid << std::endl;
                int status = 0;
                pid_t waitedpid = waitpid(pid, &status, 0);
                std::cerr << "Waited on: " << waitedpid << ": " << WIFEXITED(status) << ","
                          << WIFCONTINUED(status) << "," << WIFSIGNALED(status) << ","
                          << WIFSTOPPED(status)<< std::endl;
                std::cerr << "Signal: " << WTERMSIG(status) << std::endl;
                /*TODO: Have a background error here if waitpid fails.*/
            }
            else
            {
                size_t removed_count = m_descendants.erase(pid);
                if(removed_count == 0)
                {
                    throw std::runtime_error("Tried to remove a pid that does not exist in descendants");
                }
            }

            return (m_child_exited && m_descendants.empty());
        }
    };

    struct process_group_tcl_event : public Tcl_Event
    {
        Tcl_Interp* interp;
        Tcl_Obj* callback_script;
        std::unique_ptr<monitored_process_group> mpg;

        static int event_proc(Tcl_Event *ev, int flags)
        {
            (void)flags;
            process_group_tcl_event* _this = reinterpret_cast<process_group_tcl_event*>(ev);

            int ret = Tcl_EvalObjEx(_this->interp, _this->callback_script, TCL_EVAL_GLOBAL);

            if(ret != TCL_OK)
            {
                Tcl_BackgroundError(_this->interp);
            }

            /*Explicitly call the destructor because TCL event loop owns the memory*/
            _this->~process_group_tcl_event();

            return 1; /*Event has been processed*/
        }

        process_group_tcl_event(Tcl_Interp* interp, Tcl_Obj* callback_script,
                                pid_t child_pid)
            : interp(interp),
              callback_script(callback_script),
              mpg(std::make_unique<monitored_process_group>(child_pid))
        {
            this->proc = event_proc;
            this->nextPtr = nullptr;

            Tcl_IncrRefCount(callback_script);
        }

        ~process_group_tcl_event()
        {
            Tcl_DecrRefCount(callback_script);
        }
    };

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

    /*Kqueue fd is active*/
    void KqueueEventReady(void *clientData, int flags)
    {
        kqueue_state* state = reinterpret_cast<kqueue_state*>(clientData);
        state->ready = true;
    }

    void KqueueEventSetupProc(void *clientData, int flags)
    {
        (void)flags;

        kqueue_state* state = (kqueue_state*)clientData;
        if(state == nullptr || state->kqueue_fd == -1)
        {
            return;
        }

        Tcl_CreateFileHandler(state->kqueue_fd, TCL_READABLE, KqueueEventReady, state);
    }

    void handle_kqueue_proc_event(struct kevent& event)
    {
        assert(event.udata);
        process_group_tcl_event* pge = reinterpret_cast<process_group_tcl_event*>(event.udata);

        if(event.fflags & NOTE_TRACKERR)
        {
            Tcl_SetObjResult(pge->interp,
                             Tcl_ObjPrintf("Error tracking child process of %lu", event.ident));
            Tcl_BackgroundError(pge->interp);
            return;
        }

        if(event.fflags & NOTE_CHILD)
        {
            std::cerr << "NOTE_CHILD: " << event.ident << std::endl;
            pge->mpg->add_descendant((pid_t)event.ident);
        }
        else if(event.fflags & NOTE_EXIT)
        {

            std::cerr << "NOTE_EXIT: " << event.ident << std::endl;
            bool is_process_group_empty = pge->mpg->exited(event.ident, event.data);
            if(is_process_group_empty)
            {
                Tcl_QueueEvent(pge, TCL_QUEUE_TAIL);
            }
        }
    }

    void KqueueEventCheckProc(void *clientData, int flags)
    {
        (void)flags;

        kqueue_state* state = reinterpret_cast<kqueue_state*>(clientData);
        assert(state);

        if(!state->ready)
        {
            return;
        }
        state->ready = false;

        /*Kqueue is ready.  Get the available events and process them.*/
        std::array<struct kevent, 16> events = {};

        /*Use timespec instead of nullptr so kevent doesn't block*/
        timespec spec;
        spec.tv_sec = 0;
        spec.tv_nsec = 0;
        ssize_t event_count = kevent(state->kqueue_fd, nullptr, 0,
                                     events.data(), events.size(),
                                     &spec);

        if(event_count == -1)
        {
            /*TODO: We should use tcl background errors instead of c++ exceptions*/
            std::ostringstream msg;
            msg << "Error occurred while retrieving kevents: " << strerror(errno);
            std::cerr << msg.str() << std::endl;
            throw std::runtime_error(msg.str());
        }

        for(int i = 0; i < event_count; ++i)
        {
            switch(events[i].filter)
            {
            case EVFILT_PROC:
                handle_kqueue_proc_event(events[i]);
                break;
            default:
                throw std::runtime_error("Unexexpected filter type: " + std::to_string(events[i].filter));
                break;
            }
        }
    }

    void KqueueDeleteProc(void *clientData, Tcl_Interp *interp)
    {
        int kqueue_fd = -1;
        Tcl_Obj* fd_obj = (Tcl_Obj*)clientData;
        int tcl_error = Tcl_GetIntFromObj(interp, fd_obj, &kqueue_fd);

        if(!tcl_error)
        {
            Tcl_DecrRefCount(fd_obj);
            close(kqueue_fd);
        }
    }
}

int Appc_ExecInit(Tcl_Interp* interp)
{
    /*TODO: We should probably make our own kqueue module
     * for appc::native extension
     */
    int kqueue_fd = kqueue();
    if(kqueue_fd == -1)
    {
        return appc::syserror_result(interp, "EXEC KQUEUE");
    }

    std::unique_ptr<kqueue_state> state = std::make_unique<kqueue_state>(kqueue_fd);

    (void)Tcl_CreateObjCommand(interp, "appc::exec", Appc_Exec, state.get(),
                               appc::cpp_delete<kqueue_state>);
    Tcl_CreateEventSource(KqueueEventSetupProc, KqueueEventCheckProc, state.release());
    return TCL_OK;
}

int Appc_Exec(void *clientData, Tcl_Interp *interp,
              int objc, struct Tcl_Obj *const *objv)
{
    kqueue_state* state = reinterpret_cast<kqueue_state*>(clientData);

    if(objc < 4)
    {
        Tcl_WrongNumArgs(interp, objc, objv, "<fd_dict> <callback_prefix> cmd...");
        return TCL_ERROR;
    }

    /*TODO: Accept a -daemon flag which will do a double fork so it is
     * reparented by init.  daemon flag can just cause daemon() to be called.
     * This flag will affect whether we need to reap the child or not.
     */

    int stdin_fd = 0;
    int stderr_fd = 1;
    int stdout_fd = 2;

    Tcl_Obj* fd_dict = objv[1];
    Tcl_Obj* callback_prefix = objv[2];
    Tcl_DictSearch search;
    Tcl_Obj* key = nullptr;
    Tcl_Obj* value = nullptr;
    int done;
    int tcl_error = TCL_OK;
    for(tcl_error = Tcl_DictObjFirst(interp, fd_dict, &search, &key, &value, &done);
        done == 0;
        Tcl_DictObjNext(&search, &key, &value, &done))
    {
        long handle = -1;
        if(std::string("stdin") == Tcl_GetString(key))
        {
            tcl_error = appc::get_handle_from_channel(interp, value, handle);
            if(tcl_error) return tcl_error;
            stdin_fd = (int)handle;

        }
        else if(std::string("stdout") == Tcl_GetString(key))
        {
            tcl_error = appc::get_handle_from_channel(interp, value, handle);
            if(tcl_error) return tcl_error;

            stdout_fd = (int)handle;
        }
        else if(std::string("stderr") == Tcl_GetString(key))
        {

            tcl_error = appc::get_handle_from_channel(interp, value, handle);
            if(tcl_error) return tcl_error;

            stderr_fd = (int)handle;
        }
    }

    /*Now create the vector of arguments so that we can fork/exec*/
    std::vector<char*> args;
    for(int i = 3; i < objc; ++i)
    {
        args.push_back(Tcl_GetString(objv[i]));
    }
    args.push_back(nullptr);

    pid_t pid = fork();

    switch(pid)
    {
    case 0:
    {
        /*Child*/

        /*I don't think we want to touch the interp as even deleting it calls
         * deletion callbacks*/

        pid_t process_grpid = 0;
        if(isatty(stdin_fd))
        {
            process_grpid = setsid();

            if(process_grpid == (int)-1)
            {
                perror("setsid");
                exit(1);
            }

            int error = tcsetsid(stdin_fd, process_grpid);
            if(error == -1)
            {
                 perror("tcsetsid");
                 exit(1);
            }

            error = tcsetpgrp(stdin_fd, 0);

            /*shell child*/

            error = tcsetpgrp(stdin_fd, getpid());
            if(error == -1)
            {
                std::ostringstream msg;
                msg << "tcsetpgrp2: " << strerror(errno) << std::endl;
                exit(1);
            }

            struct termios tios;
            error = tcgetattr(stdin_fd, &tios);
            if(error == -1)
            {
                perror("tcgetattr");
                exit(1);
            }

            cfmakesane(&tios);

            error = tcsetattr(stdin_fd, TCSANOW, &tios);
            if(error == -1)
            {
                perror("tcsetattr");
                exit(1);
            }
        }

        signal(SIGHUP, SIG_DFL);

        int error = dup_fd(stdin_fd, 0, "stdin");
        if(error) exit(1);

        error = dup_fd(stdout_fd, 1, "stdout");
        if(error) exit(1);

        error = dup_fd(stderr_fd, 2, "stderr");
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
            std::cerr << msg.str() << std::endl;
            exit(1);
        }
    }
    case -1:
        Tcl_SetResult(interp, (char*)Tcl_ErrnoMsg(errno), TCL_STATIC);
        return TCL_ERROR;
    default:
    {
        /*Parent*/
        struct kevent event;
        void* pge_buffer = Tcl_Alloc(sizeof(process_group_tcl_event));

        std::cerr << "Forked pid: " << pid << std::endl;
        new(pge_buffer) process_group_tcl_event(interp, callback_prefix, pid);
        EV_SET(&event, pid, EVFILT_PROC, EV_ADD, NOTE_EXIT|NOTE_TRACK, 0, pge_buffer);

        int error = kevent(state->kqueue_fd, &event, 1, nullptr, 0, nullptr);
        if(error == -1)
        {
            return appc::syserror_result(interp, "EXEC", "MONITOR", "KQUEUE");
        }

        break;
    }
    }


    return TCL_OK;
}
