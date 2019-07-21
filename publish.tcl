# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require appc::env

package require uri

namespace eval appc::publish {

    namespace eval _:: {

        proc publish_s3 {uri_dict} {

            set scheme [dict get $uri_dict scheme]
            # if {$scheme ne s3}
        }
    }
    
    proc publish {image_name tag} {

        
        set repo_url [appc::env::get_repo]

        set repo_url_dict [uri::split $repo]

        set scheme [dict get $repo_url_dict scheme]
        switch -exact  $scheme {

            file {
                
            }
            s3 {

            }
            default {
                return -code error -errorcode {PUBLISH SCHEME ENOTSUPPORTED } \
                    "Scheme not supported for publishing: $scheme"
            }
        }
    }
}

::uri::register {s3 S3} {
	variable NIDpart {[a-zA-Z0-9][a-zA-Z0-9-]{0,31}}
    variable esc {%[0-9a-fA-F]{2}}
    variable trans {a-zA-Z0-9$_.+!*'(,):=@;-}
    variable NSSpart "($esc|\[$trans\])+"
    variable URNpart "($NIDpart):($NSSpart)"
    variable schemepart $URNpart
	variable url "s3:$NIDpart:$NSSpart"
}
package provide appc::publish 1.0.0
