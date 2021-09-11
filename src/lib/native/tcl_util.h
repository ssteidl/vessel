#ifndef TCL_UTIL_H
#define TCL_UTIL_H

#include <iostream>

#include <cerrno>
#include <memory>
#include <tcl.h>


namespace vessel
{

void unref_tclobj(Tcl_Obj* obj);

template<class T>
void tclalloc_free(T* arg);

template<class T>
void tclalloc_destruct(T* arg);

using tclobj_ptr = std::unique_ptr<Tcl_Obj, decltype(&unref_tclobj)>;

template<class T>
using tclalloc_ptr = std::unique_ptr<T, decltype(&tclalloc_free<T>)>;

template<class T>
void placement_destructor(T* arg);

template<class T>
using placement_ptr = std::unique_ptr<T, decltype(&placement_destructor<T>)>;

template<class T>
placement_ptr<T> create_placement_ptr(T* arg);

void tclobj_delete_proc(void* client_data, Tcl_Interp* interp);

tclobj_ptr create_tclobj_ptr(Tcl_Obj* obj);

template<typename... CODES>
int syserror_result(Tcl_Interp* interp, CODES... error_codes)
{

    Tcl_SetResult(interp, (char*)Tcl_ErrnoMsg(errno), TCL_STATIC);
    Tcl_SetErrorCode(interp, &error_codes..., Tcl_ErrnoId(), nullptr);
    return TCL_ERROR;
}

int get_handle_from_channel(Tcl_Interp* interp, Tcl_Obj* chan_name, long& handle);

template <typename T>
void cpp_delete(void* client_data)
{
    delete((T*)client_data);
}

template <typename T>
void cpp_delete_with_interp(void* client_data, Tcl_Interp* interp)
{
    delete((T*)client_data);
}

struct fd_guard
{
    int fd;

    fd_guard(int fd);
    int release();
    ~fd_guard();
};
}

template<class T>
void vessel::tclalloc_free(T* arg)
{
    Tcl_Free(reinterpret_cast<char*>(arg));
}

template<class T>
void vessel::tclalloc_destruct(T* arg)
{
    arg->~T();
    Tcl_Free(reinterpret_cast<char*>(arg));
}

template<class T>
void vessel::placement_destructor(T* arg)
{
    arg->~T();
}

template<class T>
vessel::placement_ptr<T> vessel::create_placement_ptr(T* arg)
{
    return placement_ptr<T>(arg, vessel::placement_destructor<T>);
}
#endif // TCL_UTIL_H
