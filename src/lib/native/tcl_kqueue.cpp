#include "tcl_kqueue.h"
#include "tcl_util.h"

#include <array>
#include <cassert>
#include <fcntl.h>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <sys/event.h>
#include <unistd.h>

using namespace vessel;

namespace
{
    /**
     * @brief The kqueue_state struct simply manages if there is an event ready to be
     * processed in the kqueue.
     */
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
     * @brief KqueueEventReady The callback for the tcl file handler (fd notifier).
     * @param clientData
     * @param flags
     */
    void KqueueEventReady(void *clientData, int flags)
    {
        kqueue_state* state = reinterpret_cast<kqueue_state*>(clientData);
        state->ready = true;
    }

    /**
     * @brief KqueueEventSetupProc The setup proc for the tcl event loop integration.
     * @param clientData
     * @param flags
     */
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


    /**
     * @brief KqueueEventCheckProc Handles available kqueue events.  We know if
     * an event is ready based on the kqueue_state which is set by the file event
     * handler.
     * @param clientData
     * @param flags
     */
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
            if(events[i].udata == nullptr)
            {
                throw std::runtime_error("Missing user data in kevent");
            }

            /*NOTE: Events need to be allocated by Tcl_Alloc.  Copy the enqueue_signal_event for how to
             * add do new placement and allocation correctly.*/
            tcl_event_factory* factory = reinterpret_cast<tcl_event_factory*>(events[i].udata);
            tcl_event_ptr event = factory->create_tcl_event(events[i]);
            Tcl_QueueEvent(event.release(), TCL_QUEUE_TAIL);
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

    class tcl_kqueue
    {

        kqueue_state m_kq_state;
        Tcl_Interp* m_interp;

    public:
        tcl_kqueue(Tcl_Interp* interp)
            : m_kq_state(kqueue()),
              m_interp(interp)
        {
            if(m_kq_state.kqueue_fd != -1)
            {
                Tcl_CreateEventSource(KqueueEventSetupProc, KqueueEventCheckProc, this);
            }
        }

        /* Note that the consumer should not use event.udata, they should use the subclass of Tcl_Event
         * for any context they need.*/
        int add_kevent(struct kevent& event, tcl_event_factory& event_factory)
        {
            /*NOTE it's up to the consumer to ensure the event_factory object lifetime
             * is longer then the event lives in kqueue*/
            event.udata = &event_factory;
            int error = kevent(m_kq_state.kqueue_fd, &event, 1, nullptr, 0, nullptr);
            if(error == -1)
            {
                return vessel::syserror_result(m_interp, "EXEC", "MONITOR", "KQUEUE");
            }
            return TCL_OK;
        }

        int remove_kevent(struct kevent& event)
        {
            int error = kevent(m_kq_state.kqueue_fd, &event, 1, nullptr, 0, nullptr);
            if(error == -1)
            {
                return vessel::syserror_result(m_interp, "EXEC", "MONITOR", "KQUEUE");
            }
            return TCL_OK;
        }

        ~tcl_kqueue()
        {
            /*Tcl ignores the case when the event source doesn't exist.*/
            Tcl_DeleteEventSource(KqueueEventSetupProc, KqueueEventCheckProc, this);
        }
    };
}

int vessel::Kqueue_Init(Tcl_Interp* interp)
{
    Tcl_SetAssocData(interp, "TclKqueueContext", vessel::cpp_delete_with_interp<tcl_kqueue>, new tcl_kqueue(interp));
    return TCL_OK;
}

int vessel::Kqueue_Add_Event(Tcl_Interp* interp, struct kevent& event, tcl_event_factory& event_factory)
{
    tcl_kqueue* kq = reinterpret_cast<tcl_kqueue*>(Tcl_GetAssocData(interp, "TclKqueueContext", nullptr));
    kq->add_kevent(event, event_factory);
    return TCL_OK;
}

int vessel::Kqueue_Remove_Event(Tcl_Interp* interp, struct kevent& event)
{
    tcl_kqueue* kq = reinterpret_cast<tcl_kqueue*>(Tcl_GetAssocData(interp, "TclKqueueContext", nullptr));
    return kq->remove_kevent(event);
}
