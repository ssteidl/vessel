#include <cassert>
#include "appc_tcl.h"

using namespace appc;

tcl_obj_raii::tcl_obj_raii(Tcl_Obj* obj)
    : obj(obj)
{
    if(obj)
    {
        Tcl_IncrRefCount(obj);
    }
}

tcl_obj_raii::~tcl_obj_raii()
{
    if(obj)
    {
        Tcl_DecrRefCount(obj);
    }
}

void appc::delete_interp(Tcl_Interp* interp)
{
    assert(interp);
    Tcl_DeleteInterp(interp);
}

interp_ptr create_tcl_interp()
{
    return std::unique_ptr<Tcl_Interp>(Tcl_CreateInterp(), appc::delete_interp);
}
