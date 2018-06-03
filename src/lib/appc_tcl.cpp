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

tcl_obj_raii::tcl_obj_raii(const tcl_obj_raii& other)
    : tcl_obj_raii(Tcl_DuplicateObj(other.obj))
{

}

tcl_obj_raii::tcl_obj_raii(tcl_obj_raii&& other)
    : obj(other.obj)
{
    other.obj = nullptr;
}

tcl_obj_raii& tcl_obj_raii::operator=(const tcl_obj_raii& other)
{
    if(this != &other)
    {
        obj = Tcl_DuplicateObj(other.obj);
    }

    return *this;
}

tcl_obj_raii& tcl_obj_raii::operator=(tcl_obj_raii&& other)
{
    if(this != &other)
    {
        obj = other.obj;
        other.obj = nullptr;
    }
    return *this;
}

tcl_obj_raii::operator Tcl_Obj*() const
{
    return obj;
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
    return appc::interp_ptr(Tcl_CreateInterp(), appc::delete_interp);
}
