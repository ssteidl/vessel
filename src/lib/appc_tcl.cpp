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

