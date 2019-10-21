#ifndef EXEC_H
#define EXEC_H
#include <tcl.h>

int Appc_Exec(void *clientData, Tcl_Interp *interp,
              int objc, struct Tcl_Obj *const *objv);

#endif // EXEC_H
