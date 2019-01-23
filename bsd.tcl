# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

namespace eval appc::bsd {

    proc host_architecture {} {

        return [exec uname -m]
    }

    proc host_version {} {

        return [exec uname -r]
    }
}
