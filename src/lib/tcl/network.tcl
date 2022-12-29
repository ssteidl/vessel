
package require defer

package require vessel::bsd
package require vessel::env
package require vessel::metadata_db

namespace eval vessel::network {
 
    logger::initNamespace [namespace current] debug
    variable log [logger::servicecmd [string trimleft [namespace current] :]]
    
    
    namespace eval bridge {
     
        variable bridge_name [vessel::env::bridge_name]
        
        
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
            if {[catch {exec ifconfig $bridge_name up} msg]} {${log}::debug $msg}
                    
            if {${inet_iface} ne {}} {
                
                #idempotent
                if {[catch {exec ifconfig ${bridge_name} addm ${inet_iface}} msg]} {${log}::debug $msg}            
            }
            
            return [exists?]
        }
        
        proc exists? {} {
            variable ::vessel::network::log
            variable bridge_name
            
            set exists true
            if {[catch {exec ifconfig $bridge_name} msg]} {
                ${log}::debug "exists? $msg"
                set exists false
            }
            
            return $exists
        }
    }
    
    #Namespace for manipulating epair devices
    namespace eval epair {
        
        #Creates the epair.  Does not bring it up.
        proc create {name} {
            variable ::vessel::network::log
            
            if {! [exists? $name]} {
                ${log}::debug "epair doesn't exist, creating"
                set epair [exec ifconfig epair create]
                
                #epair will be something like epair0a we can use that to rename the a side
                exec ifconfig $epair name [get_jail_iface $name]
                
                #Get the basename so we can rename the b side
                set epair_basename [string range $epair 0 end-1]
                exec ifconfig "${epair_basename}b" name [get_bridge_iface $name]
            }
            
            return $name
        }
        
        proc get_jail_iface {name} {
            
            return "${name}a"
        }
        
        proc get_bridge_iface {name} {
         
            return "${name}b"
        }
        
        proc exists? {name} {
            
            variable ::vessel::network::log
            
            set iface_exists true
            set iface [get_bridge_iface $name]
            if {[catch {exec ifconfig $iface} msg]} {
                ${log}::debug "epair_exists: $msg"
                set iface_exists false
            }

            return $iface_exists
        }
        
        proc destroy {name} {
         
            variable ::vessel::network::log
            
            if {[exists? $name]} {
                ${log}::debug "Destroying [get_jail_iface $name]"
                
                #Destroying the a side of an epair will destroy both sides
                exec ifconfig [get_jail_iface $name] destroy
            }
        }
    }
    
    namespace eval router {
     
        variable router_image_name "vessel-router"
        
        #The current tag to use for router so we know if we need to update
        variable router_tag "1.0.0"
        
        # Check if the router image exists
        proc router_image_exists? {} {
            variable router_image_name
            variable router_tag
            
            # Get the current images.  Image name should be FreeBSD:<current version>/vessel-router:<current router tag>
            set version [vessel::bsd::host_version_without_patch]
            
            
            return [vessel::metadata_db::image_exists $router_image_name $router_tag]            
        }
        
        proc get_image_vesselfile_contents {dnsmasq_conf_path} {
            set template {
FROM FreeBSD:[vessel::bsd::host_version_without_patch]

RUN env ASSUME_ALWAYS_YES=yes pkg update
RUN env ASSUME_ALWAYS_YES=yes pkg install dnsmasq
RUN touch /etc/rc.conf
RUN sysrc dnsmasq_enable=YES
COPY ${dnsmasq_conf_path} /usr/local/etc/dnsmasq.conf}
            
            return [subst $template]
        }
        
        # Returns the configuration for dnsmasq with the listening iface substituted
        # So that dnsmasq only listens on the internal interface.
        proc get_dnsmasq_config {listening_iface} {
            set template {
port=53

# The following two options make you a better netizen, since they                                                                             
# tell dnsmasq to filter out queries which the public DNS cannot                                                                              
# answer, and which load the servers (especially the root servers)                                                                            
# unnecessarily. If you have a dial-on-demand link they also stop                                                                             
# these requests from bringing up the link unnecessarily.                                                                                     

# Never forward plain names (without a dot or domain part)                                                                                    
domain-needed
# Never forward addresses in the non-routed address spaces.                                                                                   
bogus-priv

# If you want dnsmasq to listen for DHCP and DNS requests only on                                                                             
# specified interfaces (and the loopback) give the name of the                                                                                
# interface (eg eth0) here.                                                                                                                   
# Repeat the line for more than one interface.                                                                                                
interface=${listening_iface}

addn-hosts=/var/run/vessel/router/hosts


#TODO: This domain feature seems useful.                                                                                                      
# Set this (and domain: see below) if you want to have a domain                                                                               
# automatically added to simple names in a hosts-file.                                                                                        
#expand-hosts                                                                                                                                 

# Set the domain for dnsmasq. this is optional, but if it is set, it                                                                          
# does the following things.                                                                                                                  
# 1) Allows DHCP hosts to have fully qualified domain names, as long                                                                          
#     as the domain part matches this setting.                                                                                                
# 2) Sets the "domain" DHCP option thereby potentially setting the                                                                            
#    domain of all systems configured by DHCP                                                                                                 
# 3) Provides the domain part for "expand-hosts"                                                                                              
#domain=thekelleys.org.uk                                                                                                                     

dhcp-range=192.168.9.5,192.168.0.200,12h

#This could be very useful if the user wanted to use static ips                                                                               
# Enable the address given for "judge" in /etc/hosts                                                                                          
# to be given to a machine presenting the name "judge" when                                                                                   
# it asks for a DHCP lease.                                                                                                                   
#dhcp-host=judge                                                                                                                              

# Set the default time-to-live to 50                                                                                                          
#dhcp-option=23,50                                                                                                                            

# Set the "all subnets are local" flag                                                                                                        
#dhcp-option=27,1                                                                                                                             

#TODO: Use this for updating DNS?                                                                                                             
# Run an executable when a DHCP lease is created or destroyed.                                                                                
# The arguments sent to the script are "add" or "del",                                                                                        
# then the MAC address, the IP address and finally the hostname                                                                               
# if there is one.                                                                                                                            
dhcp-script=/usr/bin/logger -t vesseldns
}

            return [subst $template]
        }
        
        proc build_image {dnsmasq_listening_iface} {
            
            variable router_image_name
            variable router_tag
        
            # Generate the temporary VesselFile
            set vesselfile_tmp_chan [file tempfile vesselfile_path "/tmp/routervesselfile"]
            set dnsmasq_tmp_chan [file tempfile dnsmasq_path "/tmp/dnsmasq"]
            
            #Schedule the temporary files to be closed and deleted.
            defer::with [list vesselfile_tmp_chan vesselfile_path dnsmasq_tmp_chan dnsmasq_path] {
             
                catch {
                    close ${vesselfile_tmp_chan}
                    file delete ${vesselfile_path}   
                }
                
                catch {
                    close ${dnsmasq_tmp_chan}
                    file delete $dnsmasq_path
                }
            }
            
            #Write the dnsmasq config tmp file
            puts ${dnsmasq_tmp_chan} [get_dnsmasq_config ${dnsmasq_listening_iface}]
            flush ${dnsmasq_tmp_chan}
            
            #Write the routers vessel file tmp file.  It needs the dnsmasq path so that it can copy 
            #it into the image as /usr/local/etc/dnsmasq.conf
            puts ${vesselfile_tmp_chan} [get_image_vesselfile_contents ${dnsmasq_path}]
            flush ${vesselfile_tmp_chan}
            
            exec vessel build --file=${vesselfile_path} --tag=${router_tag} --name=${router_image_name} >&@ stderr
        }
    }
    
    proc network_command {arg_dict} {
        variable ::vessel::network::log
        
        ${log}::debug "network command args: $arg_dict"
        # The network command is the command that queries meta-data regarding
        # existing networks.
        
        if {[dict get $arg_dict create]} {
            
            #TODO: [dict get $arg_dict inet_interface]
            bridge::create_bridge {}
            
            #create the network in the sqlite db
            set network_dict [metadata_db::add_network [dict get $arg_dict name]]
            
            #create the epair for the network
            set internal_epair [vessel::network::epair::create "[dict get ${network_dict} name][dict get ${network_dict} vlan]"]
            
            #Check if the router image needs to be built
            if {![router::router_image_exists?]} {
             
                
                #Build the router vm if necessary
                vessel::network::router::build_image ${internal_epair}
                
                # We need to know the name of the epair device that will be assigned
                # to the router on the vlan so we can tell dnsmasq what to listen for
                
                router_build_image ${internal_epair} 
            }
            
            #Start the router vm, won't do anything if it is running already
            
            #create devd rule
            
            #If the vm is not running, start it.  Ensure pf.conf rules have been executed.
            #Tables can be updated dynamically as jails on the network start and stop.
            
        }
    }
}

package provide vessel::network 1.0.0