#ifndef KQUEUE_H
#define KQUEUE_H

#include <memory>
#include <sys/event.h>
#include "tcl_util.h"

namespace vessel
{
    using tcl_event_ptr = tclalloc_ptr<Tcl_Event>;

    /**
     * Utility function to create a Tcl_Event.  T must be a
     * subclass of Tcl_Event
     */
    template <class T, class...Ts>
    tcl_event_ptr alloc_tcl_event(Ts... args);

    class tcl_event_factory
    {
    public:

        virtual tcl_event_ptr create_tcl_event(const struct kevent& event) = 0;

        virtual ~tcl_event_factory()
        {}
    };

    int Kqueue_Init(Tcl_Interp* interp);

    /**
     * @brief Kqueue_Add_Event Add an event to the kqueue with the given tcl event factory.
     * @param interp
     * @param event
     * @param event_factory Object used to create Tcl_Events to handle the given kevent when it is active.  Note
     * that it is a reference.  It is up to the caller to ensure the lifetime of the event factory outlives the lifetime
     * of the kevent in kqueue.
     * @return
     */
    int Kqueue_Add_Event(Tcl_Interp* interp, struct kevent& event, tcl_event_factory& event_factory);

    int Kqueue_Remove_Event(Tcl_Interp* interp, struct kevent& event);
}

template <class T, class...Ts>
vessel::tcl_event_ptr vessel::alloc_tcl_event(Ts... args)
{
    /*Tcl alloc function here*/
    T* instance = reinterpret_cast<T*>(Tcl_Alloc(sizeof(T)));
    new(instance) T(args...);
    return tcl_event_ptr(instance, vessel::tclalloc_free<Tcl_Event>);
}
#endif // KQUEUE_H
