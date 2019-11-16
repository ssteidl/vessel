package require TclOO

namespace eval appc::network {

    oo::class create bridge {

	self export createWithNamespace
	
	variable _name

	method Create {name} {

	    set _name $name
	    if {! [my exists]} {
		#The created name can actually be different then the
		#name parameter in the case that the bridge already exists.
		#We check that it doesn't exist but not sure if there are
		#other cases where it would create the bridge with a
		#different name (probably not).
		puts stderr "Bridge doesn't exist, creating"
		set _name [exec ifconfig bridge create name $name]
	    }

	    puts stderr "Bridge name: $_name"
	}
	
	constructor {name} {

	    my Create $name
	}
	
	method exists {} {

	    set exists true
	    if {[catch {exec ifconfig $_name} msg]} {
		puts stderr "Exists check: $msg"
		set exists false
	    }

	    puts stderr "Exists: $exists"
	    return $exists
	}

	method add_member {member_interface} {

	    exec ifconfig $_name addm $member_interface
	}

	method delete_member {member_interface} {

	    exec ifconfig $_name deletem $member_interface
	}

	destructor {
	    puts stderr "destroy bridge"
	    exec ifconfig $_name destroy
	}
    }

    oo::class create epair {

	self export createWithNamespace
	
	variable _name
	
	method Create {name} {
	    set _name $name
	    if {![my exists]} {
		set epair_iface [exec ifconfig epair create]

		#ifconfig always returns the 'a' side of the epair
		#We strip the a off so we can easily work with both
		#sides
		set epair_iface [string range $epair_iface 0 end-1]
		exec ifconfig "${epair_iface}a" name "${name}a"
		exec ifconfig "${epair_iface}b" name "${name}b"

	    }
	}

	method Destroy {} {

	    exec ifconfig [my get_aside] destroy
	}
	
	constructor {name} {
	    
	    my Create $name
	}

	method exists {} {

	    set exists true
	    if {[catch {exec ifconfig $_name} msg]} {
		puts stderr "$_name Exists check: $msg"
		set exists false
	    }

	    return $exists
	}
	
	method get_aside {} {
	    return "${_name}a"
	}
	
	method get_bside {} {
	    return "${_name}b"
	}

	method add_to_bridge {bridge_obj} {

	    $bridge_obj add_member [my get_bside]
	}
	
	destructor {
	    puts stderr "destroy epair"
	    my Destroy
	}
    }

    oo::class create vlan {

	self export createWithNamespace
	
	variable _name
	variable _tag_number

	method Create {tag_number vlandev} {
	    set _name "${vlandev}.${tag_number}"
	    set _tag_number $tag_number
	    exec ifconfig $_name create vlan $_tag_number vlandev $vlandev  
	}
	
	constructor {tag_number vlandev} {

	    my Create $tag_number $vlandev
	}

	method set_ip_addr {ip} {
	    #ip can be with or without the netmask
	    #192.168.3.2 or 192.168.3.2/24
	    exec ifconfig $_name $ip
	}
	
	destructor {

	    exec ifconfig $_name destroy
	}
    }

    oo::class create internal_network_vlan {

	self export createWithNamespace
	
	variable _network_name
	variable _bridge_obj_ref
	variable _ip
	variable _epair_obj
	variable _vlan_obj

	#List of jail objects that have networks.
	variable jail_obj_ref_list
	
	constructor {network_name bridge_obj vlan_tag ip} {

	    set _network_name $network_name
	    set _bridge_obj_ref $bridge_obj
	    set _ip $ip
	    set _epair_obj [appc::network::epair new "${network_name}"]
	    set _vlan_obj [appc::network::vlan new $vlan_tag [$_epair_obj get_aside]]
	    $_epair_obj add_to_bridge $_bridge_obj_ref
	    $_vlan_obj set_ip_addr $ip
	}

	method add_jail {jid ip} {

	    return -code error -errorcode {APPC NETWRK NYI} \
		"add_jail is not yet implemented"
	}
	
	destructor {
	    catch {$_vlan_obj destroy}
	    catch {$_epair_obj destroy}

	    #TODO: Maintain a list of jails that are connected to
	    # this network
	}
    }
}
package provide appc::network 1.0.0
