package require appc::native

namespace eval _ {
    oo::class create repo {

	variable full_url
	variable scheme
	
	constructor {url} {
	    puts stderr "repo constructor"
	    #Parse it to ensure it is valid
	    set url_dict [appc::url::parse ${url}]
	    set scheme [dict get $url_dict scheme]
	    set full_url ${url}
	}
	
	method pull_image {image tag} {
	    return -code error errorcode {INTERFACECALL} \
		"Subclass of repo must implement pull_image"
	}

	method put_image {image tag} {
	    return -code error errorcode {INTERFACECALL} \
		"Subclass of repo must implement put_image"
	}

	method get_url {} {

	    return $full_url
	}

	method get_scheme {} {

	    return $scheme
	}
    }

    oo::class create file_repo {
	superclass repo
	constructor {url} {
	    next $url

	    puts stderr "file_repo constructor"
	}

	method pull_image {image tag} {
	    
	}

	method put_image {image tag} {
	    #TODO
	}
    }
}

_::file_repo create myrepo {file:///usr/home/shane/jack}

puts stderr "[myrepo get_url]"
