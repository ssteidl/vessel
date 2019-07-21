#include "tcl_util.h"

using namespace appc;

void appc::unref_tclobj(Tcl_Obj* obj)
{
    if(obj)
    {
        Tcl_DecrRefCount(obj);
    }
}

void appc::tclobj_delete_proc(void* client_data, Tcl_Interp* interp)
{
    Tcl_DecrRefCount((Tcl_Obj*)client_data);
}

tclobj_ptr appc::create_tclobj_ptr(Tcl_Obj* obj)
{
    return tclobj_ptr(obj, appc::unref_tclobj);
}
