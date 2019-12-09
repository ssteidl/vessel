#! /usr/bin/env tclsh8.6

package require cmdline
package require appc::network

proc create_network {netname hostip} {

    puts stderr "netname: $netname, hostip: $hostip"
    
    #Intentionally don't destroy these objects so the
    #OS objects (interfaces) are not destroyed.
    set bridge_obj [appc::network::bridge new "${netname}bridge"]
    set internal_network_obj [appc::network::internal_network new $netname $bridge_obj $hostip]
}

set options {
    {network.arg "" "Name of the network to create"}
    {ip.arg 192.168.102.1 "Ip address of the host epair"}
}

set usage "create-network --network=<name> --ip=<host ip>"

try {
    array set params [::cmdline::getoptions argv $options $usage]
} trap {CMDLINE USAGE} {msg o} {
    # Trap the usage signal, print the message, and exit the application.
    # Note: Other errors are not caught and passed through to higher levels!
    puts stderr $msg
    exit 1
}

parray params

set netname $params(network)
set ip $params(ip)

create_network $netname $ip
