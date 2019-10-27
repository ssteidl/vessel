#include <array>
#include <cassert>
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

#include "dns/embdns.h"
#include "exec.h"
#include "tcl_util.h"
#include "url_cmd.h"

namespace
{
    std::vector<const char*> argv_vector_from_command_args(int argc, Tcl_Obj** args)
    {
        std::vector<const char*> argv{};

        for(int i = 0; i < argc; ++i)
        {
            argv.push_back(Tcl_GetString(args[i]));
        }

        return argv;
    }

    int parse_build_options(Tcl_Interp* interp, int argc, Tcl_Obj** args, Tcl_Obj* options_dict)
    {
        assert(argc > 0);

        static const struct option long_opts[] = {
            {"file", required_argument, nullptr, 'f'},
            {"name", required_argument, nullptr, 'n'},
            {"tag", required_argument, nullptr, 't'},
            {nullptr, 0, nullptr, 0}
        };

        std::vector<const char*> argv = argv_vector_from_command_args(argc, args);

        int ch = -1;

        //This needs to be wrapped in RAII.
        appc::tclobj_ptr args_dict(Tcl_NewDictObj(), appc::unref_tclobj);
        int tcl_error = TCL_OK;
        while((ch = getopt_long(argc, (char* const *)argv.data(), "f:n:t:", long_opts, nullptr)) != -1)
        {
            switch(ch)
            {
            case 'f':
                tcl_error = Tcl_DictObjPut(interp, args_dict.get(),
                                           Tcl_NewStringObj("file", -1),
                                           Tcl_NewStringObj(optarg, -1));
                if(tcl_error) return tcl_error;
                break;
            case 'n':
                tcl_error = Tcl_DictObjPut(interp, args_dict.get(),
                                           Tcl_NewStringObj("name", -1),
                                           Tcl_NewStringObj(optarg, -1));
                if(tcl_error) return tcl_error;
                break;
            case 't':
                tcl_error = Tcl_DictObjPut(interp, args_dict.get(),
                                           Tcl_NewStringObj("tag", -1),
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

        tcl_error = Tcl_DictObjPut(interp, options_dict,Tcl_NewStringObj("args", -1), args_dict.release());
        return tcl_error;
    }

    int parse_run_options(Tcl_Interp* interp, int argc, Tcl_Obj** args, Tcl_Obj* options_dict)
    {
        /*At some point we will have a server and need a -it flag*/
        /*appc run <layer> */

        assert(argc > 0);

        static const struct option long_opts[] = {
            {"volume", required_argument, nullptr, 'v'},
            {"rm", no_argument, nullptr, 'r'},
            {"tag", required_argument, nullptr, 't'},
            {nullptr, 0, nullptr, 0}
        };

        std::vector<const char*> argv = argv_vector_from_command_args(argc, args);

        int ch = -1;

        bool remove_container = false;
        int tag = -1;
        appc::tclobj_ptr args_dict(Tcl_NewDictObj(), appc::unref_tclobj);
        int tcl_error = TCL_OK;
        while((ch = getopt_long(argc, (char* const *)argv.data(), "v:t:", long_opts, nullptr)) != -1)
        {
            switch(ch)
            {
            case 'v':
                tcl_error = Tcl_DictObjPut(interp, args_dict.get(),
                                           Tcl_NewStringObj("volume", -1),
                                           Tcl_NewStringObj(optarg, -1));
                if(tcl_error) return tcl_error;
                break;
            case 'r':
                remove_container = true;
                break;
            case 't':
                tag = atoi(optarg);
                break;
            case ':':
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("Missing argument for optind: %d", optind));
                return TCL_ERROR;
            case '?':
                /*Ignore unknown options case because there could be options in the command arguments.*/
                break;
            default:
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("Error parsing options.  optind: %d", optind));
                return TCL_ERROR;
            }
        }


        tcl_error = Tcl_DictObjPut(interp, args_dict.get(),
                                   Tcl_NewStringObj("remove", -1),
                                   Tcl_NewBooleanObj(remove_container));
        if(tcl_error) return tcl_error;

        if(tag > -1)
        {
            tcl_error = Tcl_DictObjPut(interp, args_dict.get(),
                                       Tcl_NewStringObj("tag", -1),
                                       Tcl_NewIntObj(tag));
            if(tcl_error) return tcl_error;
        }
        if(optind == argc)
        {
            Tcl_SetObjResult(interp, Tcl_NewStringObj("Missing container name in run command", -1));
            return TCL_ERROR;
        }

        tcl_error = Tcl_DictObjPut(interp, args_dict.get(),
                                   Tcl_NewStringObj("image", -1),
                                   Tcl_NewStringObj(argv[optind], -1));
        if(tcl_error) return tcl_error;

        optind++;

        if (optind < argc)
        {
            appc::tclobj_ptr command_list(Tcl_NewListObj(0, nullptr), appc::unref_tclobj);

            for(; optind < argc; ++optind)
            {
                tcl_error = Tcl_ListObjAppendElement(interp, command_list.get(),
                                                     Tcl_NewStringObj(argv[optind], -1));
                if(tcl_error) return tcl_error;
            }
            tcl_error = Tcl_DictObjPut(interp, args_dict.get(),
                                       Tcl_NewStringObj("command", -1),
                                       command_list.release());
            if(tcl_error) return tcl_error;
        }

        tcl_error = Tcl_DictObjPut(interp, options_dict,
                                   Tcl_NewStringObj("args", -1),
                                   args_dict.release());
        return TCL_OK;
    }

    int parse_publish_pull_options(Tcl_Interp* interp, int argc,
                                   Tcl_Obj** args, Tcl_Obj* options_dict)
    {
        assert(argc > 0);

        static const struct option long_opts[] = {
            {"tag", required_argument, nullptr, 't'},
            {nullptr, 0, nullptr, 0}
        };

        if(argc < 2)
        {
            Tcl_WrongNumArgs(interp, argc, args, "publish <image> [--tag]");
            return TCL_ERROR;
        }

        std::vector<const char*> argv = argv_vector_from_command_args(argc, args);

        int ch = -1;

        std::string image{};
        std::string tag{};
        appc::tclobj_ptr args_dict(Tcl_NewDictObj(), appc::unref_tclobj);
        int tcl_error = TCL_OK;
        while((ch = getopt_long(argc, (char* const *)argv.data(), "t:", long_opts, nullptr)) != -1)
        {
            switch(ch)
            {
            case 't':
                tag = optarg;
                break;
            case ':':
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("Missing argument for optind: %d", optind));
                return TCL_ERROR;
            case '?':
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("Unknown argument for optind: %d", optind));
                return TCL_ERROR;
            default:
                Tcl_SetObjResult(interp, Tcl_ObjPrintf("Unknown error for optind: %d", optind));
                return TCL_ERROR;
            }
        }

        std::cerr << "optind: " << optind << "," << argc << std::endl;
        if((argc - optind) <= 0)
        {
            Tcl_SetObjResult(interp, Tcl_ObjPrintf("image name not provided"));
            return TCL_ERROR;
        }

        image = argv[optind];

        tcl_error = Tcl_DictObjPut(interp, args_dict.get(),
                       Tcl_NewStringObj("tag", -1),
                       Tcl_NewStringObj(tag.c_str(), tag.size()));
        if(tcl_error) return tcl_error;

        tcl_error = Tcl_DictObjPut(interp, args_dict.get(),
                       Tcl_NewStringObj("image", -1),
                       Tcl_NewStringObj(image.c_str(), image.size()));
        if(tcl_error) return tcl_error;

        tcl_error = Tcl_DictObjPut(interp, options_dict,
                       Tcl_NewStringObj("args", -1),
                       args_dict.release());
        if(tcl_error) return tcl_error;

        return TCL_OK;
    }

    /**
     * appc::parse_options $argc $argv
     */
    int Appc_ParseOptions(void *clientData, Tcl_Interp *interp,
                          int objc, struct Tcl_Obj *const *objv)
    {
        if(objc < 2)
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

        if(arg_count == 0)
        {
            Tcl_SetResult(interp, (char*)"subcommand not provided", TCL_STATIC);
            Tcl_SetErrorCode(interp, "ARGS");
            return TCL_ERROR;
        }


        //TODO: RAII on command_options since it is top level object.
        appc::tclobj_ptr command_options(Tcl_NewDictObj(), appc::unref_tclobj);
        Tcl_Obj* pre_command_flags = Tcl_NewDictObj();
        tcl_error = Tcl_DictObjPut(interp, command_options.get(),
                                   Tcl_NewStringObj("pre_command_flags", -1),
                                   pre_command_flags);
        if(tcl_error) return tcl_error;

        tcl_error = Tcl_DictObjPut(interp, pre_command_flags,
                                   Tcl_NewStringObj("local", -1),
                                   Tcl_NewBooleanObj(0));
        if(tcl_error) return tcl_error;

        /*Parse pre command options like --local*/
        int command_index = 0; /*Index of the command in the options list*/
        for (int i=0; i < arg_count; i++)
        {
            std::string pre_command_option(Tcl_GetStringFromObj(argument_objs[i], nullptr));
            if(pre_command_option == "--local")
            {
                tcl_error = Tcl_DictObjPut(interp, pre_command_flags,
                                           Tcl_NewStringObj("local", -1),
                                           Tcl_NewBooleanObj(1));
            }
            else
            {
                break;
            }

            command_index++;
        }
        arg_count -= command_index;
        argument_objs += command_index;
        std::string command(Tcl_GetString(argument_objs[0]));

        /*TODO: Make command lookup table for commands.*/
        tcl_error = Tcl_DictObjPut(interp, command_options.get(), Tcl_NewStringObj("args", -1),
                                   Tcl_NewStringObj("", 0));
        if(tcl_error) return tcl_error;

        if(command == "build")
        {
            //parse args if any remaining.  shift to first non-command argument
            tcl_error = parse_build_options(interp, arg_count, argument_objs, command_options.get());
            if(tcl_error) return tcl_error;
        }
        else if(command == "run")
        {
            tcl_error = parse_run_options(interp, arg_count, argument_objs, command_options.get());
            if(tcl_error) return tcl_error;
        }
        else if(command == "publish")
        {
            tcl_error = parse_publish_pull_options(interp, arg_count,
                                                   argument_objs, command_options.get());
            if(tcl_error) return tcl_error;
        }
        else if(command == "pull")
        {
            tcl_error = parse_publish_pull_options(interp, arg_count,
                                                   argument_objs, command_options.get());
            if(tcl_error) return tcl_error;
        }
        else
        {
            Tcl_SetObjResult(interp, Tcl_ObjPrintf("Unknown command given: %s", command.c_str()));
            return TCL_ERROR;
        }

        tcl_error = Tcl_DictObjPut(interp, command_options.get(),
                                   Tcl_NewStringObj("command", -1),
                                   argument_objs[0]);
        if(tcl_error) return tcl_error;
        Tcl_SetObjResult(interp, command_options.release());
        return TCL_OK;
    }

    int Appc_DNSParseQuery(void *clientData, Tcl_Interp *interp,
                           int objc, struct Tcl_Obj *const *objv)
    {
        /*appc::dns::parse_query <binary obj>
         * @returns array with the following keys:
         *     qname, type, class
         */

        if(objc != 2)
        {
            Tcl_WrongNumArgs(interp, objc, objv, "binary_buffer");
            return TCL_ERROR;
        }

        int buf_len = 0;
        unsigned char* query_buf = Tcl_GetByteArrayFromObj(objv[1], &buf_len);

        embdns::dns_query query = embdns::parse_packet(query_buf, (size_t)buf_len);

        Tcl_Obj* query_dict = Tcl_NewDictObj();
        Tcl_DictObjPut(interp, query_dict,
                       Tcl_NewStringObj("qname", -1),
                       Tcl_NewStringObj(query.qname.c_str(), query.qname.size()));

        Tcl_DictObjPut(interp, query_dict,
                       Tcl_NewStringObj("type", -1),
                       Tcl_NewIntObj(query.qtype) /*TODO: map int to string*/);

        Tcl_DictObjPut(interp, query_dict,
                       Tcl_NewStringObj("class", -1),
                       Tcl_NewIntObj(query.qclass) /*TODO: map int to string*/);

        Tcl_DictObjPut(interp, query_dict,
                       Tcl_NewStringObj("raw_query", -1),
                       Tcl_NewByteArrayObj(query.raw().data(), query.raw().size()));

        Tcl_SetObjResult(interp, query_dict);
        return TCL_OK;
    }


    int Appc_DNSGenerateAResponse(void *clientData, Tcl_Interp *interp,
                                 int objc, struct Tcl_Obj *const *objv)
    {

        /*generate_A_response addr ttl raw_query*/
        if(objc != 4)
        {
            Tcl_WrongNumArgs(interp, objc, objv, "addr ttl raw_query");
            return TCL_ERROR;
        }

        std::string addr(Tcl_GetString(objv[1]));
        uint32_t ttl = 0;
        int tcl_error = Tcl_GetIntFromObj(interp, objv[2], (int*)&ttl);
        if(tcl_error) return tcl_error;

        int query_size = 0;
        unsigned char* raw_query = Tcl_GetByteArrayFromObj(objv[3], &query_size);

        embdns::dns_query query = embdns::parse_packet(raw_query, (size_t)query_size);
        if(query.qtype != 1)
        {
            Tcl_SetObjResult(interp, Tcl_NewStringObj("Attempted to generate dns A record response for non A record query", -1));
            return TCL_ERROR;
        }

        std::array<uint8_t, embdns::dns_message::MAX_SIZE> pkt_buf;
        size_t response_size = embdns::generate_response(pkt_buf, query, addr, ttl);
        Tcl_Obj* response_buf_obj = Tcl_NewByteArrayObj(pkt_buf.data(), (int)response_size);
        Tcl_SetObjResult(interp, response_buf_obj);
        return TCL_OK;
    }

    void init_dns(Tcl_Interp* interp)
    {
        Tcl_Obj* query_handler = nullptr;
        Tcl_SetAssocData(interp, "dns.query_handler", appc::tclobj_delete_proc,
                         query_handler);


            (void)Tcl_CreateObjCommand(interp, "appc::dns::parse_query", Appc_DNSParseQuery, nullptr, nullptr);
            (void)Tcl_CreateObjCommand(interp, "appc::dns::generate_A_response", Appc_DNSGenerateAResponse,
                                       nullptr, nullptr);
    }

    void init_url(Tcl_Interp* interp)
    {
        (void)Tcl_CreateObjCommand(interp, "appc::url::parse", Appc_ParseURL, nullptr, nullptr);
    }

    void init_exec(Tcl_Interp* interp)
    {
        (void)Appc_ExecInit(interp);
    }
}

extern "C" {

/*Forward declare PTY_Init from pty.c module.*/
int
Pty_Init(Tcl_Interp *interp);

extern int Appctcl_Init(Tcl_Interp* interp)
{
    if(Tcl_InitStubs(interp, "8.6", 0) == nullptr)
    {
        return TCL_ERROR;
    }

    (void)Tcl_CreateObjCommand(interp, "appc::parse_options", Appc_ParseOptions, nullptr, nullptr);

    init_dns(interp);
    init_url(interp);
    init_exec(interp);
    Pty_Init(interp);
    Tcl_PkgProvide(interp, "appc::native", "1.0.0");

    return TCL_OK;
}
}
