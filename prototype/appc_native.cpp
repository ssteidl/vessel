#include <array>
#include <cerrno>
#include <iostream>
#include <list>
#include <string>
#include <sys/types.h>
#include <sys/socket.h>
#include <tcl.h>
#include <unistd.h>
#include <vector>

#include <getopt.h>

namespace
{
    template<typename... CODES>
    int syserror_result(Tcl_Interp* interp, CODES... error_codes)
    {

        Tcl_SetResult(interp, (char*)Tcl_ErrnoMsg(errno), TCL_STATIC);
        Tcl_SetErrorCode(interp, &error_codes..., Tcl_ErrnoId(), nullptr);
        return TCL_ERROR;
    }

//    int Appc_StartJail(void *clientData, Tcl_Interp *interp,
//                       int objc, struct Tcl_Obj *const *objv)
//    {
//        std::array<int, 2> sv = {};
//        int error = socketpair(PF_LOCAL, SOCK_SEQPACKET|SOCK_NONBLOCK, 0, sv.data());
//        if(error)
//        {
//            return syserror_result(interp, "SYS", "SOCKETPAIR");
//        }

//        //TODO: kqueue or devd to monitor jail process

//        pid_t pid = fork();
//        switch(pid)
//        {
//        case -1:
//            return syserror_result(interp, "SYS", "FORK");
//        case 0:
//            //Child function
//            //TODO: jail function, set resources, capsicum and execute
//            sv
//            break;
//        default:
//            //parent;
//            break;
//        }

//        return TCL_OK;
//    }

    int parse_build_options(Tcl_Interp* interp, int argc, Tcl_Obj** args, Tcl_Obj* options_dict)
    {
        assert(argc > 1);

        static const struct option long_opts[] = {
            {"file", required_argument, nullptr, 'f'},
            {nullptr, 0, nullptr, 0}
        };

        std::vector<const char*> argv{};

        //Start at 1 because 0 is the command.
        for(int i = 0; i < argc; ++i)
        {
            argv.push_back(Tcl_GetString(args[i]));
        }

        int ch = -1;

        //This needs to be wrapped in RAII.
        Tcl_Obj* args_dict = Tcl_NewDictObj();
        int tcl_error = TCL_OK;
        while((ch = getopt_long(argc, (char* const *)argv.data(), "f:", long_opts, nullptr)) != -1)
        {
            switch(ch)
            {
            case 'f':
                tcl_error = Tcl_DictObjPut(interp, args_dict,
                                           Tcl_NewStringObj("file", -1),
                                           Tcl_NewStringObj(optarg, -1));
                if(tcl_error) return tcl_error;
                break;
            case ':':
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("Missing argument for optind: %d", optind));
                return TCL_ERROR;
            case '?':
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("Unknown option for optind: %d", optind));
                return TCL_ERROR;
            default:
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("Error parsing options.  optind: %d", optind));
                return TCL_ERROR;
            }
        }

        tcl_error = Tcl_DictObjPut(interp, options_dict,Tcl_NewStringObj("args", -1), args_dict);
        return tcl_error;
    }

    /**
     * appc::parse_options $argc $argv
     */
    int Appc_ParseOptions(void *clientData, Tcl_Interp *interp,
                          int objc, struct Tcl_Obj *const *objv)
    {
        if(objc != 2)
        {
            Tcl_WrongNumArgs(interp, objc, objv, "Only one arg expected. <argv>");
            return TCL_ERROR;
        }

        int arg_count = 0;
        Tcl_Obj** argument_objs = nullptr;
        int tcl_error = Tcl_ListObjGetElements(interp, objv[1], &arg_count, &argument_objs);
        if(tcl_error)
        {
            return tcl_error;
        }

        if(arg_count < 2)
        {
            Tcl_SetResult(interp, (char*)"subcommand not provided", TCL_STATIC);
            Tcl_SetErrorCode(interp, "ARGS");
            return TCL_ERROR;
        }

        std::string command(Tcl_GetString(argument_objs[0]));

        /*TODO: Make command lookup table for commands.*/

        Tcl_Obj* command_options = Tcl_NewDictObj();
        tcl_error = Tcl_DictObjPut(interp, command_options, Tcl_NewStringObj("args", -1),
                                   Tcl_NewStringObj("", 0));
        if(tcl_error) return tcl_error;

        if(command == "build")
        {
            //parse args if any remaining.  shift to first non-command argument
            tcl_error = parse_build_options(interp, arg_count, argument_objs, command_options);
            if(tcl_error) return tcl_error;
        }
        else if(command == "run")
        {
            assert(0);
        }
        else
        {
            Tcl_SetObjResult(interp, Tcl_ObjPrintf("Unknown command given: %s", command.c_str()));
            return TCL_ERROR;
        }
        /*TODO: Parse command then command options.  First option should always be a command
         * - appc run -it --rm <image-name>
         * - appc build -f Dockerfile .
         */

        tcl_error = Tcl_DictObjPut(interp, command_options, Tcl_NewStringObj("command", -1), argument_objs[0]);
        if(tcl_error) return tcl_error;
        Tcl_SetObjResult(interp, command_options);
        return TCL_OK;
    }

}

extern "C" {

extern int Appctcl_Init(Tcl_Interp* interp)
{
    if(Tcl_InitStubs(interp, "8.6", 0) == nullptr)
    {
        return TCL_ERROR;
    }

//    (void)Tcl_CreateObjCommand(interp, "appc::start_jail", Appc_StartJail, nullptr, nullptr);
    (void)Tcl_CreateObjCommand(interp, "appc::parse_options", Appc_ParseOptions, nullptr, nullptr);

    return TCL_OK;
}
}
