#include <algorithm>
#include <array>
#include <cassert>
#include <cerrno>
#include "exec.h"
#include <fcntl.h>
#include <iostream>
#include <list>
#include <map>
#include <set>
#include <sstream>
#include <string>
#include <termios.h>
#include <vector>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include "tcl_kqueue.h"
#include "tcl_util.h"

using namespace vessel;

/*TODO: Consistent naming conventions*/
/*TODO: Better logging support.  There is too much logging to cerr for an extension*/
namespace
{
    /**
     * @brief The ctrl_pipe class handles the creation, configuration and destruction of
     * the process monitor group's control pipe.  A control pipe accepts commands from a
     * supervisor and acts accordingly.  It is a more synchronous, robust and extensible
     * mechanism then sending signals.
     */
    class ctrl_pipe
    {
        int m_child_fd;
        int m_parent_fd;
        bool m_initialized;
        bool m_in_parent;
        Tcl_Interp* m_interp;
        Tcl_Channel m_chan;

    public:
        ctrl_pipe(Tcl_Interp* interp)
            : m_child_fd(-1),
              m_parent_fd(-1),
              m_initialized(false),
              m_in_parent(false),
              m_interp(interp),
              m_chan(nullptr)
        {
            int pipe_fds[2];
            int ret = pipe2(pipe_fds, 0);
            if(ret)
            {
                std::ostringstream msg;
                msg << "Error creating ctrl pipe: " << strerror(errno);
                throw std::runtime_error(msg.str());
            }
            m_child_fd = pipe_fds[0];
            m_parent_fd = pipe_fds[1];
        }

        /**
         * @brief parent Should be called after fork while in the parent process.  Initializes the
         * pipe to live in the parent.
         * @return
         */
        Tcl_Obj* parent()
        {
            if(m_initialized)
            {
                throw std::logic_error("ctrl_pipe already initialized when trying to initialize in parent");
            }

            m_in_parent = true;
            close(m_child_fd);

            /*We use the freebsd specific bi-directional pipe*/
            m_chan = Tcl_MakeFileChannel((ClientData)((long)m_parent_fd), TCL_READABLE|TCL_WRITABLE);

            if(m_chan == nullptr)
            {
                return nullptr;
            }

            Tcl_RegisterChannel(m_interp, m_chan);
            m_initialized = true;
            return Tcl_NewStringObj(Tcl_GetChannelName(m_chan), -1);
        }

        /**
         * @brief child Should be called in the child process after a fork.  Initializes the pipe
         * for operation in the child, including setting the environment variable.
         * @return
         */
        int child()
        {
            if(m_initialized)
            {
                throw std::logic_error("ctrl_pipe already initialized when trying to initialize in child");
            }
            m_in_parent = false;
            close(m_parent_fd);

            m_initialized = true;
            tclobj_ptr vessel_ctrl_env = create_tclobj_ptr(Tcl_ObjPrintf("VESSEL_CTRL_FD=%d", m_child_fd));
            Tcl_IncrRefCount(vessel_ctrl_env.get());
            return Tcl_PutEnv(Tcl_GetStringFromObj(vessel_ctrl_env.get(), nullptr));
        }

        int parent_fd()
        {
            return m_parent_fd;
        }

        int child_fd()
        {
            return m_child_fd;
        }

        ~ctrl_pipe()
        {
            /*I'm not really sure we need to do anything here.  We close
             * the child pipe just in case it's needed but if the child process
             * has exited, the pipe should be closed.*/
            if(!m_initialized)
            {
                return;
            }

            if(m_in_parent)
            {
                /*tcl script is responsible for closing the channel*/
            }
            else
            {
                (void)close(m_child_fd);
            }
        }
    };

    /**
     * Class for monitoring a heirarchy of processes.  This class provides the interface
     * that is called based on EVFILT_PROC events.
     */
    class monitored_process_group
    {
        pid_t m_child; /**< The process that was directly forked*/
        bool m_child_exited; /**< True if the child has exited.  Note that descendants
                               * can still be added if the child has exited.*/
        uint64_t m_child_exit_status = 0;

        std::set<pid_t> m_descendants; /**< Flattened set of descendant processes.*/

        std::unique_ptr<ctrl_pipe> m_cpipe; /**< The control pipe that can be used by the process group.
                                                 This probably doesn't belong to this class but it needs
                                                 to share the same scope. However, I could imagine future
                                                 features that could send pipe messages based on the events
                                                 tracked in this class.*/

    public:
        monitored_process_group(pid_t child, std::unique_ptr<ctrl_pipe> cpipe)
            : m_child(child),
              m_child_exited(false),
              m_descendants(),
              m_cpipe(std::move(cpipe))
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

        std::set<pid_t> active_pids()
        {
            std::set<pid_t> pids;
            if(!m_child_exited)
            {
                pids.insert(m_child);
            }

            pids.insert(std::begin(m_descendants), std::end(m_descendants));
            return pids;
        }

        bool has_first_child_exited() const
        {
            return m_child_exited;
        }

        pid_t first_child_pid() const
        {
            return m_child;
        }
    };


    using monitored_process_group_list = std::map<pid_t, std::shared_ptr<monitored_process_group>>;

    /**
     * @brief The VesselExecSignalEvent class Encapsulates the event handling of signal events.
     */
    class vessel_exec_signal_event : public Tcl_Event
    {
        Tcl_Interp* m_interp;
        monitored_process_group_list m_mpgs;
        Tcl_Obj* m_signal_callback;
        struct kevent m_event;

        static int event_proc(Tcl_Event *evPtr, int flags)
        {
            (void)flags;
            placement_ptr<vessel_exec_signal_event> _this = create_placement_ptr((vessel_exec_signal_event*)(evPtr));

            /*The list of mpg dicts that will be returned.*/
            vessel::tclobj_ptr top_level_list = vessel::create_tclobj_ptr(Tcl_NewListObj(0, nullptr));
            for(auto& mpg : _this->m_mpgs)
            {
                /*Each mpg is represented by a dict:
                 * "main_pid": empty if main pid has exited.  Pid if it is still active.
                 * "active_pids": List of active pids*/

                /*Create the mpg dict and add it to the top level list to be returned.*/
                Tcl_Obj* mpg_dict = Tcl_NewDictObj();
                int error = Tcl_ListObjAppendElement(_this->m_interp, top_level_list.get(), mpg_dict);
                if(error)
                {
                    Tcl_BackgroundError(_this->m_interp);
                    return 1;
                }

                /*Add the value of the main pid.  Empty object if the main process has exited.*/
                vessel::tclobj_ptr main_pid_val = vessel::create_tclobj_ptr(Tcl_NewObj());
                if(!mpg.second->has_first_child_exited())
                {
                    main_pid_val = vessel::create_tclobj_ptr(Tcl_NewWideIntObj(mpg.second->first_child_pid()));
                }
                error = Tcl_DictObjPut(_this->m_interp, mpg_dict, Tcl_NewStringObj("main_pid", -1), main_pid_val.release());
                if(error)
                {
                    Tcl_BackgroundError(_this->m_interp);
                    break;
                }

                /*Create the active pids list and add it to the mpg dict.*/
                Tcl_Obj* mpg_list = Tcl_NewListObj(0, nullptr);
                error = Tcl_DictObjPut(_this->m_interp, mpg_dict, Tcl_NewStringObj("active_pids", -1), mpg_list);
                if(error)
                {
                    Tcl_BackgroundError(_this->m_interp);
                    return 1;
                }

                /*The signal handler should take a list of lists each of which contain all active pids
                 * for a process group.  The tcl code can search for jails and shut them down as necessary*/
                for(pid_t pid : mpg.second->active_pids())
                {
                    error = Tcl_ListObjAppendElement(_this->m_interp, mpg_list, Tcl_NewWideIntObj(pid));
                    if(error)
                    {
                        Tcl_BackgroundError(_this->m_interp);
                        return 1;
                    }
                }
            }

            /*Create an object with the callback elements provided as well as the top level list of mpgs*/

            int callback_length = 0;
            Tcl_Obj **callback_elements = nullptr;
            int error = Tcl_ListObjGetElements(_this->m_interp, _this->m_signal_callback, &callback_length, &callback_elements);
            if(error)
            {
                Tcl_BackgroundError(_this->m_interp);
                return 1;
            }

            vessel::tclobj_ptr eval_params = vessel::create_tclobj_ptr(Tcl_NewListObj(callback_length, callback_elements));
            /*NOTE: Will segfault when evaluating if we don't incr the ref count.*/
            Tcl_IncrRefCount(eval_params.get());

            error = Tcl_ListObjAppendElement(_this->m_interp, eval_params.get(), Tcl_NewStringObj(sys_signame[_this->m_event.ident], -1));
            error = error || Tcl_ListObjAppendElement(_this->m_interp, eval_params.get(), top_level_list.release());
            if(error)
            {
                Tcl_BackgroundError(_this->m_interp);
                return 1;
            }

            error = Tcl_EvalObjEx(_this->m_interp, eval_params.get(), TCL_EVAL_GLOBAL);

            if(error)
            {
                Tcl_BackgroundError(_this->m_interp);
            }

            return 1; /*Handled event.  */
        }

    public:
        vessel_exec_signal_event(Tcl_Interp* interp, monitored_process_group_list& mpgs, Tcl_Obj* signal_callback, struct kevent& event)
            : Tcl_Event(),
              m_interp(interp),
              m_mpgs(mpgs),
              m_signal_callback(signal_callback),
              m_event(event)
        {

            this->proc = event_proc;
            this->nextPtr = nullptr;
            Tcl_IncrRefCount(m_signal_callback);
        }

        ~vessel_exec_signal_event()
        {
            Tcl_DecrRefCount(m_signal_callback);
        }
    };

    /**
     * @brief The signal_event_factory class is used to tie kqueue signal processing
     * with tcl events.
     */
    class signal_event_factory : public tcl_event_factory
    {
        Tcl_Interp* m_interp;
        monitored_process_group_list& m_mpgs;
        tclobj_ptr m_signal_callback;

    public:

        signal_event_factory(Tcl_Interp* interp, monitored_process_group_list& mpgs)
            : m_interp(interp),
              m_mpgs(mpgs),
              m_signal_callback(create_tclobj_ptr(nullptr))
        {}

        tcl_event_ptr create_tcl_event(const struct kevent& event) override
        {
            if(!m_signal_callback)
            {
                throw std::logic_error("Signal callback has not yet been set");
            }

            return alloc_tcl_event<vessel_exec_signal_event>(m_interp, m_mpgs, m_signal_callback.get(), event);
        }

        void set_signal_callback(tclobj_ptr callback)
        {
            m_signal_callback = std::move(callback);
        }

        ~signal_event_factory()
        {}
    };

    /**
     * @brief The mpg_cleanup_ctx struct is used to group together data needed
     * to properly cleanup an mpg after all processes have exited.
     */
    struct mpg_cleanup_ctx
    {
        Tcl_Interp* interp;
        std::shared_ptr<monitored_process_group> mpg;

        mpg_cleanup_ctx(Tcl_Interp* interp, std::shared_ptr<monitored_process_group>& mpg)
            : interp(interp),
              mpg(mpg)
        {}
    };

    /*declaration for cleaning up a process group*/
    void cleanup_mpg_from_interp(ClientData data);

    /**
     * @brief The process_group_tcl_event struct is the structure that is used as
     * a tcl event when the monitored process group has exited.  It is responsible
     * for calling the provided callback script when all processes have exited.
     */
    struct process_group_tcl_event : public Tcl_Event
    {
        Tcl_Interp* interp;
        Tcl_Obj* callback_script;
        std::shared_ptr<monitored_process_group> mpg;
        struct kevent event;

        static int event_proc(Tcl_Event *ev, int flags)
        {
            (void)flags;
            placement_ptr<process_group_tcl_event> _this = create_placement_ptr((process_group_tcl_event*)(ev));

            if(_this->event.fflags & NOTE_TRACKERR)
            {
                Tcl_SetObjResult(_this->interp,
                                 Tcl_ObjPrintf("Error tracking child process of %lu", _this->event.ident));
                Tcl_BackgroundError(_this->interp);
                return 1;
            }

            if(_this->event.fflags & NOTE_CHILD)
            {
                _this->mpg->add_descendant((pid_t)_this->event.ident);
                return 1;
            }
            else if(_this->event.fflags & NOTE_EXIT)
            {
                bool is_process_group_empty = _this->mpg->exited(_this->event.ident, _this->event.data);

                /*PROC events seem to get removed automatically when a process exits.  I tried removing them
                 * but I got a file not found.*/

                if(!is_process_group_empty)
                {
                    /*All processes in group have not yet exited so mark this event as handled*/
                    return 1;
                }
            }

            /*Process group has finished.  We can invoke the callback and cleanup*/

            /*TODO: Make a function to invoke the callback*/
            /*TODO: The if(tcl_error) return tcl_error; pattern doesn't work.  We should be raising a background error if it
             * fails.*/
            Tcl_Obj** elements = nullptr;
            int length = 0;
            int tcl_error = Tcl_ListObjGetElements(_this->interp, _this->callback_script, &length, &elements);
            if(tcl_error) return tcl_error;
            tclobj_ptr cmd_exited_callback = create_tclobj_ptr(Tcl_NewListObj(length, elements));
            Tcl_IncrRefCount(cmd_exited_callback.get());
            tcl_error = Tcl_ListObjAppendElement(_this->interp, cmd_exited_callback.get(), Tcl_NewStringObj("exit", -1));
            if(tcl_error) return tcl_error;
            tcl_error = Tcl_EvalObjEx(_this->interp, cmd_exited_callback.get(), TCL_EVAL_GLOBAL);

            if(tcl_error != TCL_OK)
            {
                Tcl_BackgroundError(_this->interp);
            }

            /*TODO: we need a struct that has the mpg pointer and the interp*/
            char* ctx_buf = Tcl_Alloc(sizeof(mpg_cleanup_ctx));
            mpg_cleanup_ctx* cleanup_ctx = new(ctx_buf) mpg_cleanup_ctx(_this->interp, _this->mpg);
            Tcl_DoWhenIdle(cleanup_mpg_from_interp, cleanup_ctx);
            return 1; /*Event has been processed*/
        }

        process_group_tcl_event(Tcl_Interp* interp, Tcl_Obj* callback_script,
                                std::shared_ptr<monitored_process_group>& mpg,
                                struct kevent& ev)
            : interp(interp),
              callback_script(callback_script),
              mpg(mpg),
              event(ev)
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

    class process_group_event_factory : public tcl_event_factory
    {
        Tcl_Interp* m_interp;
        tclobj_ptr m_callback_script;
        std::shared_ptr<monitored_process_group> m_mpg;

    public:

        process_group_event_factory(Tcl_Interp* interp, Tcl_Obj* callback_script, std::shared_ptr<monitored_process_group> mpg)
            : tcl_event_factory(),
              m_interp(interp),
              m_callback_script(create_tclobj_ptr(callback_script)),
              m_mpg(mpg)
        {
            Tcl_IncrRefCount(callback_script);
        }

        tcl_event_ptr create_tcl_event(const struct kevent &event) override
        {
            return alloc_tcl_event<process_group_tcl_event>(m_interp, m_callback_script.get(), m_mpg, event);
        }
    };

    /**
     * @brief dup_fd Duplicates an fd into another specific fd and handles errors as needed.
     * @param old_fd
     * @param new_fd
     * @param fd_name
     * @param error_fd
     * @return
     */
    int dup_fd(int old_fd, int new_fd, const std::string& fd_name, int error_fd = 2)
    {
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

    /**
     * @brief The vessel_exec_interp_state struct Contains the necessary per-interpreter state.  Basically
     * all of the data that is needed at the global level but hang it off of an interp for good practice.
     */
    struct vessel_exec_interp_state
    {

        Tcl_Interp* interp;
        std::map<pid_t, std::shared_ptr<process_group_event_factory>> mpg_event_factories;
        monitored_process_group_list mpgs;
        signal_event_factory signal_factory;

    private:
        vessel_exec_interp_state(Tcl_Interp* interp)
            : interp(interp),
              mpg_event_factories(),
              mpgs(),
              signal_factory(interp, mpgs)
        {}
    public:
        ~vessel_exec_interp_state()
        {}

        static int create(Tcl_Interp* interp,
                          std::unique_ptr<vessel_exec_interp_state>& interp_state)
        {
            /*NOTE: Can't use make_unique with private constructor.*/
            std::unique_ptr<vessel_exec_interp_state> tmp_ptr(new vessel_exec_interp_state(interp));
            interp_state = std::move(tmp_ptr);
            return TCL_OK;
        }

        void set_signal_callback(Tcl_Obj* callback)
        {
            Tcl_IncrRefCount(callback);
            signal_factory.set_signal_callback(create_tclobj_ptr(callback));
        }

        std::shared_ptr<process_group_event_factory>
        add_mpg(std::shared_ptr<monitored_process_group>& mpg, Tcl_Obj* callback)
        {
            mpgs.insert({mpg->first_child_pid(), mpg});
            auto factory = std::make_shared<process_group_event_factory>(interp, callback, mpg);
            mpg_event_factories.insert({mpg->first_child_pid(), factory});
            return factory;
        }

        void remove_mpg(std::shared_ptr<monitored_process_group>& mpg)
        {
            mpgs.erase(mpg->first_child_pid());
            mpg_event_factories.erase(mpg->first_child_pid());
        }
    };


    void cleanup_mpg_from_interp(ClientData data)
    {
        tclalloc_ptr<mpg_cleanup_ctx> ctx(reinterpret_cast<mpg_cleanup_ctx*>(data), tclalloc_destruct<mpg_cleanup_ctx>);

        /*TODO: Need a function for this*/
        vessel_exec_interp_state* interp_state =
                reinterpret_cast<vessel_exec_interp_state*>(Tcl_GetAssocData(ctx->interp, "VesselExec", nullptr));

        std::shared_ptr<monitored_process_group> mpg = ctx->mpg;

        if(interp_state == nullptr)
        {
            throw std::logic_error("Interp state not found when cleaning up mpg");
        }

        interp_state->remove_mpg(ctx->mpg);
    }
}

int Vessel_ExecInit(Tcl_Interp* interp)
{
    std::unique_ptr<vessel_exec_interp_state> interp_state;
    int tcl_error = vessel_exec_interp_state::create(interp, interp_state);
    if(tcl_error) return tcl_error;

    Tcl_SetAssocData(interp, "VesselExec", vessel::cpp_delete_with_interp<vessel_exec_interp_state>, interp_state.release());

    (void)Tcl_CreateObjCommand(interp, "vessel::exec_set_signal_handler", Vessel_Exec_SetSignalHandler, nullptr, nullptr);
    (void)Tcl_CreateObjCommand(interp, "vessel::exec", Vessel_Exec, nullptr, nullptr);
    (void)Tcl_CreateObjCommand(interp, "vessel::get_supervisor_ctrl_channel", Vessel_Get_Supervisor_Ctrl_Channel, nullptr, nullptr);

    return TCL_OK;
}

/**
 * @brief Vessel_Exec_SetSignalHandler Setup kqueue to notify us of interesting signals.  Set the signal
 * handler that will be called when an interesting signal is given to us.
 * @param clientData
 * @param interp
 * @param objc
 * @param objv
 * @return
 */
int Vessel_Exec_SetSignalHandler(void *clientData, Tcl_Interp *interp,
              int objc, struct Tcl_Obj *const *objv)
{
    (void)clientData;
    /*NOTE: I wonder if I should be using a pty to pass along signals instead of doing this?
     * I don't think so because that wouldn't help with jail processes that run in the background.  Perhaps
     * that should be done in interactive mode.  See ticket #37*/
    if(objc != 2)
    {
        Tcl_WrongNumArgs(interp, objc, objv, "<callback_prefix>");
    }


    vessel_exec_interp_state* interp_state = reinterpret_cast<vessel_exec_interp_state*>(Tcl_GetAssocData(interp, "VesselExec", nullptr));
    interp_state->set_signal_callback(objv[1]);

    struct kevent ev;
    std::vector<int> sigs = {SIGINT, SIGTERM, SIGHUP};
    for(int sig : sigs)
    {
        signal(sig, SIG_IGN);
        EV_SET(&ev, sig, EVFILT_SIGNAL, EV_ADD, 0, 0, nullptr);
        Kqueue_Add_Event(interp, ev, interp_state->signal_factory);
    }

    return TCL_OK;
}


/**
 * @brief Vessel_Get_Supervisor_Ctrl_Channel Can be called by the child
 * spawned in exec.  The channel can be used to implement a protocol.
 */
int Vessel_Get_Supervisor_Ctrl_Channel(void *clientData, Tcl_Interp *interp,
                                       int objc, struct Tcl_Obj *const *objv)
{
    if(objc != 1)
    {
        Tcl_WrongNumArgs(interp, objc, objv, "no arguments are expected");
        return TCL_ERROR;
    }

    char* fd_str = ::getenv("VESSEL_CTRL_FD");
    if(fd_str == nullptr)
    {
        Tcl_SetResult(interp, (char*)"No 'VESSEL_CTRL_FD' found in environment", TCL_STATIC);
        return TCL_ERROR;
    }

    long fd = -1;
    int tcl_ret = Tcl_ExprLong(interp, fd_str, &fd);
    if(tcl_ret) return tcl_ret;

    /*Read and write because that is what we have defined the supervisor
     * channel to be.  FreeBSD supports bi-directional pipes */
    Tcl_Channel ctrl_channel = Tcl_MakeFileChannel((ClientData)fd, TCL_READABLE | TCL_WRITABLE);
    Tcl_RegisterChannel(interp, ctrl_channel);

    const char* channel_name = Tcl_GetChannelName(ctrl_channel);
    /*Set to volatile so tcl makes a copy of the channel name*/
    Tcl_SetResult(interp, (char*)channel_name, TCL_VOLATILE);

    return TCL_OK;
}

int Vessel_Exec(void *clientData, Tcl_Interp *interp,
              int objc, struct Tcl_Obj *const *objv)
{
    (void)objv;
    vessel_exec_interp_state* vessel_exec = reinterpret_cast<vessel_exec_interp_state*>(Tcl_GetAssocData(interp, "VesselExec", nullptr));
    assert(vessel_exec);

    if(objc < 4)
    {
        Tcl_WrongNumArgs(interp, objc, objv, "<fd_dict> <callback_prefix> cmd...");
        return TCL_ERROR;
    }

    int stdin_fd = 0;
    int stderr_fd = 1;
    int stdout_fd = 2;

    Tcl_Obj* fd_dict = objv[1];
    Tcl_Obj* callback_prefix = objv[2];
    int tcl_error = TCL_OK;

    int async = 0;
    /*If the callback is not an empty string then we run the command
     * async*/
    (void)Tcl_GetStringFromObj(callback_prefix, &async);
    if(tcl_error) return tcl_error;

    Tcl_DictSearch search;
    Tcl_Obj* key = nullptr;
    Tcl_Obj* value = nullptr;
    int done;
    for(tcl_error = Tcl_DictObjFirst(interp, fd_dict, &search, &key, &value, &done);
        done == 0;
        Tcl_DictObjNext(&search, &key, &value, &done))
    {
        long handle = -1;
        if(std::string("stdin") == Tcl_GetString(key))
        {
            tcl_error = vessel::get_handle_from_channel(interp, value, handle);
            if(tcl_error) return tcl_error;
            stdin_fd = (int)handle;

        }
        else if(std::string("stdout") == Tcl_GetString(key))
        {
            tcl_error = vessel::get_handle_from_channel(interp, value, handle);
            if(tcl_error) return tcl_error;

            stdout_fd = (int)handle;
        }
        else if(std::string("stderr") == Tcl_GetString(key))
        {

            tcl_error = vessel::get_handle_from_channel(interp, value, handle);
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


    std::unique_ptr<ctrl_pipe> cpipe = std::make_unique<ctrl_pipe>(interp);

    pid_t pid = fork();

    switch(pid)
    {
    case 0:
    {
        /*Child*/
        int error = cpipe->child();
        if(error) return vessel::syserror_result(interp, "Exec", "CTRL_PIPE", "ENV");

        /*I don't think we want to touch the interp as even deleting it calls
         * deletion callbacks*/

        pid_t process_grpid = 0;
        /*Only start a new session if stdin is a pty and not stdin of the current process*/
        if(isatty(stdin_fd) && stdin_fd != 0)
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

        /*dup2 handles the case where the fds are the same*/
        error = dup_fd(stdin_fd, 0, "stdin");
        if(error) exit(1); //TODO: This shouldn't be an exit()

        error = dup_fd(stdout_fd, 1, "stdout");
        if(error) exit(1);

        error = dup_fd(stderr_fd, 2, "stderr");
        if(error) exit(1);

        for(int fd = 3; fd < cpipe->child_fd(); fd++)
        {
            close(fd);
        }
        closefrom(cpipe->child_fd() + 1);

        /*In the future we can use exect to setup environment
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
        Tcl_Obj* cpipe_name = cpipe->parent();

        /*This seems like the proper thing to set as the result.  But it's not really
         * useful when you are trying to get the jail id.  Need to use procfs and jail name for
         * that.*/
        Tcl_SetObjResult(interp, Tcl_NewWideIntObj(pid));

        /*Parent*/
        if(async)
        {
            int length = 0;

            /*Invoke the startup callback*/
            Tcl_Obj** elements = nullptr;
            tcl_error = Tcl_ListObjGetElements(interp, callback_prefix, &length, &elements);
            if(tcl_error) return tcl_error;
            tclobj_ptr cmd_started_callback = create_tclobj_ptr(Tcl_NewListObj(length, elements));
            Tcl_IncrRefCount(cmd_started_callback.get());
            tcl_error = Tcl_ListObjAppendElement(interp, cmd_started_callback.get(), Tcl_NewStringObj("start", -1));
            if(tcl_error) return tcl_error;
            tcl_error = Tcl_ListObjAppendElement(interp, cmd_started_callback.get(), cpipe_name);
            if(tcl_error) return tcl_error;
            tcl_error = Tcl_NREvalObj(interp, cmd_started_callback.get(), TCL_EVAL_GLOBAL);
            if(tcl_error) return tcl_error;

            std::shared_ptr<monitored_process_group> mpg = std::make_shared<monitored_process_group>(pid, std::move(cpipe));
            auto factory = vessel_exec->add_mpg(mpg, callback_prefix);

            struct kevent event;
            EV_SET(&event, pid, EVFILT_PROC, EV_ADD, NOTE_EXIT|NOTE_TRACK, 0, nullptr);
            Kqueue_Add_Event(interp, event, *factory);
        }
        else
        {
            std::cerr << "Blocking wait for child process: " << pid << std::endl;
            int status = 0;
            pid_t waitedpid = waitpid(pid, &status, 0);
            std::cerr << "Waited on: " << waitedpid << ": " << WIFEXITED(status) << ","
                      << WIFCONTINUED(status) << "," << WIFSIGNALED(status) << ","
                      << WIFSTOPPED(status)<< std::endl;
            std::cerr << "Signal: " << WTERMSIG(status) << std::endl;
        }
        break;
    }
    }


    return TCL_OK;
}
