#ifndef APPC_TCL_H
#define APPC_TCL_H

#include <tcl.h>

namespace appc
{

struct tcl_obj_raii
{
    Tcl_Obj* obj;

    tcl_obj_raii(Tcl_Obj* obj);

    ~tcl_obj_raii();

private:
    tcl_obj_raii(const tcl_obj_raii&) = delete;
    tcl_obj_raii(tcl_obj_raii&&) = delete;
    tcl_obj_raii operator=(const tcl_obj_raii&) = delete;
    tcl_obj_raii operator=(tcl_obj_raii&&) = delete;
};

}
#endif // APPC_TCL_H
