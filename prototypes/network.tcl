#Create a bridge epair devices and vlan

package require appc::network
package require defer


# set bridge_obj [appc::network::bridge new appcd-bridge]

# set epair_obj [appc::network::epair new testepair]

# set vlan_obj [appc::network::vlan new 7 [$epair_obj get_aside]]

# set vlan_obj2 [appc::network::vlan new 7 [$epair_obj get_bside]]

# $epair_obj add_to_bridge $bridge_obj

proc create_network {} {

    namespace eval create_networkns {}

    defer::defer namespace delete create_networkns
    set bridge_obj [appc::network::bridge createWithNamespace  create_networkns::acbridge create_networkns "acbridge"]
    
    appc::network::internal_network_vlan createWithNamespace create_networkns::shanenet create_networkns "shanenet" \
	$bridge_obj 7 192.168.7.3
}

create_network
