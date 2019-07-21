#ifndef TCL_UTIL_H
#define TCL_UTIL_H

#include <cerrno>
#include <memory>
#include <tcl.h>


namespace appc
{

void unref_tclobj(Tcl_Obj* obj);

using tclobj_ptr = std::unique_ptr<Tcl_Obj, decltype(&unref_tclobj)>;

void tclobj_delete_proc(void* client_data, Tcl_Interp* interp);

tclobj_ptr create_tclobj_ptr(Tcl_Obj* obj);

template<typename... CODES>
int syserror_result(Tcl_Interp* interp, CODES... error_codes)
{

    Tcl_SetResult(interp, (char*)Tcl_ErrnoMsg(errno), TCL_STATIC);
    Tcl_SetErrorCode(interp, &error_codes..., Tcl_ErrnoId(), nullptr);
    return TCL_ERROR;
}
}
#endif // TCL_UTIL_H
