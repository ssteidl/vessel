#include "devctl.h"
#include "tcl_kqueue.h"
#include "tcl_util.h"

#include <array>
#include <cstring>
#include <fcntl.h>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/socket.h>
#include <sys/un.h>
#include <tcl.h>
#include <unistd.h>

using namespace vessel;

namespace
{    
    class devctl_socket
    {
        static const std::string DEVCTL_PATH;
        fd_guard m_fd;

        int open_devctl()
        {
            struct sockaddr_un devd_addr;
            int error;

            /*Connect to devd's seq packet pipe*/
            memset(&devd_addr, 0, sizeof(devd_addr));
            devd_addr.sun_family = PF_LOCAL;
            strlcpy(devd_addr.sun_path, DEVCTL_PATH.c_str(), sizeof(devd_addr.sun_path));
            fd_guard s(socket(PF_LOCAL, SOCK_SEQPACKET, 0));

            error = connect(s.fd, (struct sockaddr*)&devd_addr, SUN_LEN(&devd_addr));
            if(error == -1)
            {
                std::ostringstream msg;
                msg << "Error connecting to " << DEVCTL_PATH << ": " << strerror(error);
                throw std::runtime_error(msg.str());
            }

            return s.release();
        }

        public:

        devctl_socket()
            : m_fd(open_devctl())
        {}

        std::string read()
        {
            char msg[1024];
            memset(msg, 0, sizeof(msg));

            return std::string(msg);
        }

        ~devctl_socket()
        {}
    };

    const std::string devctl_socket::DEVCTL_PATH = "/var/run/devd.seqpacket.pipe";

    struct devctl_context
    {
        Tcl_Interp* interp;
        tclobj_ptr callback;
        devctl_socket socket;

        devctl_context(Tcl_Interp* interp)
            : interp(interp),
              callback(nullptr, unref_tclobj)
        {}

        void set_callback(Tcl_Obj* callback_prefix)
        {
            Tcl_IncrRefCount(callback_prefix);
            callback = create_tclobj_ptr(callback_prefix);
        }
    };


    devctl_context& get_context(Tcl_Interp* interp)
    {
        devctl_context* ctx = reinterpret_cast<devctl_context*>(Tcl_GetAssocData(interp, "DevCtlContext", nullptr));
        return *ctx;
    }

    class devctl_socket_ready_event : public Tcl_Event
    {
        Tcl_Interp* interp;

        static int event_proc(Tcl_Event *evPtr, int flags)
        {
            (void)flags;

            devctl_socket_ready_event* _this = reinterpret_cast<devctl_socket_ready_event*>(evPtr);
            devctl_context& ctx = get_context(_this->interp);

            int callback_length = 0;
            Tcl_Obj **callback_elements = nullptr;
            int error = Tcl_ListObjGetElements(_this->interp, ctx.callback.get(), &callback_length, &callback_elements);
            if(error)
            {
                Tcl_BackgroundError(_this->interp);
                return 1;
            }

            tclobj_ptr eval_params = create_tclobj_ptr(Tcl_NewListObj(callback_length, callback_elements));
            std::string devctl_event = ctx.socket.read();
            error = Tcl_ListObjAppendElement(_this->interp, eval_params.get(),
                                             Tcl_NewStringObj(devctl_event.c_str(), devctl_event.size()));
            if(error)
            {
                Tcl_BackgroundError(_this->interp);
                return 1;
            }

            error = Tcl_EvalObjEx(_this->interp, eval_params.get(), TCL_EVAL_GLOBAL);
            if(error)
            {
                Tcl_BackgroundError(_this->interp);
                return 1;
            }

            return 1;
        }

    public:

        devctl_socket_ready_event(Tcl_Interp* interp)
            : Tcl_Event()
        {

            this->proc = event_proc;
            this->nextPtr = nullptr;
        }
    };

    class devctl_socket_ready_event_factory : tcl_event_factory
    {
        Tcl_Interp* m_interp;
    public:
        devctl_socket_ready_event_factory(Tcl_Interp* interp)
            : m_interp(interp)
        {

        }

        tcl_event_ptr create_tcl_event(const struct kevent &event) override
        {
            return alloc_tcl_event<devctl_socket_ready_event>(m_interp);
        }
    };

    int Vessel_DevCtlSetCallback(void *clientData, Tcl_Interp *interp,
                                 int objc, struct Tcl_Obj *const *objv)
    {
        (void)clientData;
        if(objc != 2)
        {
            Tcl_WrongNumArgs(interp, objc, objv, "<callback_prefix>");
            return TCL_ERROR;
        }
        devctl_context& ctx = get_context(interp);
        ctx.set_callback(objv[1]);
        return TCL_OK;
    }
}

int Vessel_DevCtlInit(Tcl_Interp* interp)
{
    Tcl_SetAssocData(interp, "DevCtlContext", vessel::cpp_delete_with_interp<devctl_context>, new devctl_context(interp));
    Tcl_CreateObjCommand(interp, "vessel::devctl_set_callback", Vessel_DevCtlSetCallback, nullptr, nullptr);

    return TCL_OK;
}
