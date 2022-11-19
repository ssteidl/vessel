
package require vessel::env

namespace eval vessel::network {
 
    logger::initNamespace [namespace current] debug
    variable log [logger::servicecmd [string trimleft [namespace current] :]]
    
    
    namespace eval bridge {
     
        variable bridge_name [vessel::env::bridge_name]
        
        namespace eval _ {
            
            

            proc create_bridge {bridge_name inet_iface} {
                
            }
        }
        
        # Create and name the bridge, optionally giving an inet_interface
        # so that attached jails on the default vlan can communicate
        # with the internet.
        #
        # Note: The design of vessel networking allows for the vessel
        # bridge to persist, so we don't clean up after ourselves if anything
        # in this function fails  but we do make it idempotent so if a portion
        # of it fails it can be called again.  Thus, we don't need to check
        # for existence before we call it.
        proc create_bridge {inet_iface} {
            # Create the bridge and add the external interface as a member
            
            variable bridge_name
            variable ::vessel::network::log
            
            #Not idempotent so we need to check if it exists
            if {![exists?]} {
                if {[catch {exec ifconfig bridge create name ${bridge_name}} msg]} {${log}::debug $msg}
            }
            
            #idempotent
            if {[catch {exec ifconfig $name up} msg]} {${log}::debug $msg}
                    
            if {${inet_iface} ne {}} {
                
                #idempotent
                if {[catch {exec ifconfig ${bridge_name} addm ${inet_iface}} msg]} {${log}::debug $msg}            
            }
        }
        
        proc exists? {} {
            
            variable bridge_name
            
            set exists true
            if {[catch {exec ifconfig $bridge_name} msg]} {
                set exists false
            }
            
            return $exists
        }
    }
    
    proc network_command {arg_dict} {
        
        # The network command is the command that queries meta-data regarding
        # existing networks.
    }
}