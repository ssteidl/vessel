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

#include <iostream>
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
            int fd = s.release();
            std::cerr << "my fd: " << fd << std::endl;
            return fd;
        }

        public:

        devctl_socket()
            : m_fd(open_devctl())
        {
            std::cerr << "constructor fd: " << m_fd.fd << std::endl;
        }

        devctl_socket(const devctl_socket& other) = delete;

        std::string read()
        {
            std::cerr << "Reading... " << std::endl;
            char msg[1024];
            memset(msg, 0, sizeof(msg));
            ssize_t bytes_read = ::recv(fd(), msg, sizeof(msg), MSG_DONTWAIT);
            switch (bytes_read) {
            case 0:
                /*TODO: Handle closing socket*/
                std::cerr << "Socket has closed" << std::endl;
                break;
            case -1:
                std::cerr << "devctl error: " << ::strerror(errno) << ": " << m_fd.fd << std::endl;
                break;
            default:
                break;
            }
            std::string msg_str(msg);
            std::cerr << "MSG: " << msg_str << std::endl;
            return std::string(msg);
        }

        int fd()
        {
            return m_fd.fd;
        }

        ~devctl_socket()
        {
            std::cerr << "Socket destructor" << std::endl;
        }
    };

    const std::string devctl_socket::DEVCTL_PATH = "/var/run/devd.seqpacket.pipe";

    class devctl_socket_ready_event : public Tcl_Event
    {
        Tcl_Interp* interp;
        devctl_socket& m_socket;
        tclobj_ptr m_callback_prefix;

        static int event_proc(Tcl_Event *evPtr, int flags)
        {
            (void)flags;

            devctl_socket_ready_event* _this = (devctl_socket_ready_event*)(evPtr);
            std::cerr << "Event: " << (void*)_this->interp << std::endl;
            if(_this->m_callback_prefix == nullptr)
            {
                /*Callback prefix hasn't been set so there is no point to continuing*/
                std::cerr << "Callback not set" << std::endl;
                return 1;
            }


            std::cerr << "Event: yo2" << std::endl;

            int callback_length = 0;
            Tcl_Obj **callback_elements = nullptr;
            int error = Tcl_ListObjGetElements(_this->interp, _this->m_callback_prefix.get(), &callback_length, &callback_elements);
            std::cerr << "1" << std::endl;
            if(error)
            {
                Tcl_BackgroundError(_this->interp);
                return 1;
            }

            tclobj_ptr eval_params = create_tclobj_ptr(Tcl_NewListObj(callback_length, callback_elements));
            Tcl_IncrRefCount(eval_params.get());
            std::cerr << "ref count:" << callback_elements[0]->refCount << std::endl;
            std::string devctl_event = _this->m_socket.read();
            std::cerr << "2: " << devctl_event << std::endl;
            error = Tcl_ListObjAppendElement(_this->interp, eval_params.get(),
                                             Tcl_NewStringObj(devctl_event.c_str(), devctl_event.size()));
            if(error)
            {
                std::cerr << "Error appending" << std::endl;
                Tcl_BackgroundError(_this->interp);
                return 1;
            }

            std::cerr << "3: " << Tcl_GetStringFromObj(eval_params.get(), nullptr) << std::endl;
            error = Tcl_EvalObjEx(_this->interp, eval_params.get(), TCL_EVAL_GLOBAL);
            if(error)
            {
                std::cerr << "error eval: " << Tcl_GetStringResult(_this->interp) << std::endl;
                Tcl_BackgroundError(_this->interp);
                return 1;
            }

            std::cerr << "I'm out" << std::endl;

            /*TODO: this should be done with RAII*/
            _this->~devctl_socket_ready_event();

            return 1;
        }

    public:

        devctl_socket_ready_event(Tcl_Interp* interp, devctl_socket& socket, Tcl_Obj* callback_prefix)
            : Tcl_Event(),
              interp(interp),
              m_socket(socket),
              m_callback_prefix(create_tclobj_ptr(callback_prefix))
        {

            this->proc = event_proc;
            this->nextPtr = nullptr;

            if(m_callback_prefix)
            {
                Tcl_IncrRefCount(callback_prefix);
            }
        }

        ~devctl_socket_ready_event()
        {
            std::cerr << "Destructed" << std::endl;
        }
    };

    class devctl_socket_ready_event_factory : public tcl_event_factory
    {
        Tcl_Interp* m_interp;
        devctl_socket& m_socket;
        tclobj_ptr m_callback_prefix;
    public:
        devctl_socket_ready_event_factory(Tcl_Interp* interp, devctl_socket& socket)
            : m_interp(interp),
              m_socket(socket),
              m_callback_prefix(create_tclobj_ptr(nullptr))
        {}

        devctl_socket_ready_event_factory(const devctl_socket_ready_event_factory& other) = delete;

        void set_callback_prefix(Tcl_Obj* callback_prefix)
        {
            Tcl_IncrRefCount(callback_prefix);
            m_callback_prefix = create_tclobj_ptr(callback_prefix);
        }

        tcl_event_ptr create_tcl_event(const struct kevent &event) override
        {
            return alloc_tcl_event<devctl_socket_ready_event>(m_interp, std::ref(m_socket), m_callback_prefix.get());
        }

        ~devctl_socket_ready_event_factory()
        {
            std::cerr << "Event factory destructor" << std::endl;
        }
    };

    struct devctl_context
    {
        Tcl_Interp* interp;
        devctl_socket socket;
        devctl_socket_ready_event_factory event_factory;

        devctl_context(Tcl_Interp* interp)
            : interp(interp),
              socket(),
              event_factory(interp, socket)
        {}

        void set_callback(Tcl_Obj* callback_prefix)
        {
            event_factory.set_callback_prefix(callback_prefix);
        }

        ~devctl_context()
        {
            std::cerr << "Devctl context destructor" << std::endl;
        }
    };

    devctl_context& get_context(Tcl_Interp* interp)
    {
        devctl_context* ctx = reinterpret_cast<devctl_context*>(Tcl_GetAssocData(interp, "DevCtlContext", nullptr));
        return *ctx;
    }

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
    /*NOTE: We don't really handle the situation where devd would close the devd socket.*/
    Tcl_SetAssocData(interp, "DevCtlContext", vessel::cpp_delete_with_interp<devctl_context>, new devctl_context(interp));
    Tcl_CreateObjCommand(interp, "vessel::devctl_set_callback", Vessel_DevCtlSetCallback, nullptr, nullptr);

    devctl_context& ctx = get_context(interp);

    std::cerr << "Devctlinit" << std::endl;
    struct kevent event;
    EV_SET(&event, ctx.socket.fd(), EVFILT_READ, EV_ADD, 0, 0, 0);
    return Kqueue_Add_Event(interp, event, ctx.event_factory);
}
