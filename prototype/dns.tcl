#!/usr/bin/env tclsh8.6
# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require TclOO
package require udp

load libappctcl.so

namespace eval appc::dns {

    namespace eval _ {

        oo::class create transform {

            constructor {} {

            }

            method initialize {handle mode} {

                return "initialize clear finalize read write"
            }

            method clear {} {
                
            }

            method finalize {handle} {

            }

            method limit {handle} {
                return 0
            }

            method read {handle buffer} {

                set query [appc::dns::parse_query $buffer]
                return $query
            }

            method write {handle buffer} {

                if {![dict exists $buffer raw_query] ||
                    ![dict exists $buffer address] ||
                    ![dict exists $buffer ttl]} {
                    return -code error -errorcode {DNS RESPONSE INVALID} \
                        "writing response to dns channel must be a dict with 'raw_query', 'address' and 'ttl' keys"
                }

                set addr [dict get $buffer address]
                set ttl [dict get $buffer ttl]
                set raw_query [dict get $buffer raw_query]
                # buffer should be an ipv4 address string or an empty string
                set response [appc::dns::generate_A_response $addr $ttl $raw_query]
                return $response
            }
        }
    }
}

proc udpevent_handler {sock transform_handle} {

    set pkt [read $transform_handle]
    fconfigure $sock -remote [fconfigure $sock -peer]
    set response [dict create]
    dict set response address "192.168.3.7"
    dict set response raw_query [dict get $pkt raw_query]
    dict set response ttl 30
    puts -nonewline $transform_handle $response
    flush $transform_handle
}

set dns_sock [udp_open 53]
fconfigure $dns_sock -translation binary -buffering none -blocking false

set dns_transform [appc::dns::_::transform new]
puts stderr "channel name $dns_transform"
set transform_handle [chan push $dns_sock $dns_transform]
fileevent $dns_sock readable [list udpevent_handler $dns_sock $transform_handle]

puts stderr "Waiting for request"
vwait forever
