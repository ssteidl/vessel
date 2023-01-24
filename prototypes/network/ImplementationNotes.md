Goal for this next development iteration:

Bring up a cluster of elixir nodes locally.  

* 5 Nodes.  
* Updates hostname with a counter
* Single supervisor config file
* The hostnames will be elixir-cluster-<node_instance_number>
* Cluster will be configured to use `elixir-cluster-1` to connect on startup and
be fully connected.
* The cluster is connected on a vlan using the bridge module with internal DHCP
running so nodes can discover each other
* A postgres instance can be started before the cluster jails are started
* The end result is a postgresql jail and 5 cluster nodes running on localhost all
fully connected and discoverable via DNS.  IP addrs assigned via DHCP
* STRETCH GOAL: Add support for creating jails via ansible.  Maybe this is a
`START_SSH` that uses the inherited network.
* STRETCH GOAL 2: Create cookbook instead of videos that demos each featureset.

What needs to be done?
======================

1. Potentially `create-network` to startup a jail that runs DHCP and DNS and 
sets up other components.
2. Add commandline options for jail to join a network where hostname is passed
to the DNS server.  vessel supervisor may need to act as the intermediary/broker
or it just passes the ip of the dns server to vessel and vessel communicates
with it.

Note Regarding DHCP on application jails
========================================

 * dhclient requires bpf which is a non-starter for any jail that needs an internal network.  bpf allows for packet
 sniffing outside the jail.  It kindof defeats the purpose.
 * To handle IP addresses in jail we are going to use a create-network application that runs on the host machine to 
 setup a network.  I think create network will be a long running service.  It's likely just a special command to vessel.
 In fact, we should just do `vessel run-network --name=<network-name> --subnet=192.168.1.0/24`  When a new network is needed.  
 vessel-supervisor could take care of this as needed for deployments
 
 What Does `vessel run-network` need to do?
==========================================
 
 * It needs to setup the bridge if it doesn't exist.  
 * We can bind mount `/var/run/vessel/networks/<network_name>/<network_name>.seq_packet`.
 * We'll need to figure out permissions for the unix socket between host and jail.  The bad part of this is that the jail
 could potentially affect the host system.  However, it is a jail we own that is not talking to the outside world.  Perhaps
 that's good enough.  Otherwise, it might be useful problem to solve with and learn about mandatory access control.
 * When `vessel run --network=<network_name>` is invoked, `vessel` will communicate over the networks socket to communicate
 the hostname (stored for DNS) and request an IP address.  The response will contain the IP address for the new jail and
 the ip address of the network jail so that the new jails resolv.conf can be created.
 * `vessel run-network` creates a `<networkname>-router` jail.
 
 How Does the network-router jail's filesystem get created?
=================================================
 
 * We can create it as part of vessel init
 
 What's running in the network-router jail?
===========================================
 
 * The vessel network config app.  Ideally this is a simple single binary that can be copied into the jail without a complex
 install process.
 
 * The network config app can also act as the dns server or can configure dnsmasq as needed.  An alternative more difficult
 implementation would be for vessel network config app to be a dhcp client to dnsmasq.
 
 * haproxy or nginx can run to expose ports from the host system to any of the jails.
 
 * If jails expose the same ports they can be round-robin'd
 
 * router should not accept incoming connections
 
 How does outbound internet access work with a router?
======================================================
 
 * The nice part is, we can run our own jail with it's own pf rules.  
 * Since we own the network router, we will unhide bpf and use DHCP to
 * We can unhide pf so we can make nat rules that don't interfere with the host
 * Router has two nics, one for the vlan and one for the outbound internet.
 * join the external network via the bridge.  
 * gateway_enable is needed
 * We let the OS define the MAC addresses for epair instead of using jib and it's mac address generation 
 * If needed the router can be used as a jump host to the jails.
 * dnsmasq is used as a recursive resolver that contains the hosts of other jails on the network
 
 What is the commandline interface?
 ==================================
 
 * Initialize the bridge attaching the external nic: `vessel init --inet-nic=<nic>`
 * Create a nat'd network router: `vessel network --create --name=<network name>`
 * List the network, vlan, epairs (by mac) that are part of that network `vessel network --list`
 * Create a jail that joins that network (needs to generate ip and add route): `vessel run --network=<network name> --addr=<ip addr|dhcp>`
 * Create a jail that just joins the external network via bridge: `vessel run --addr=dhcp ...`
 
 How do we manage members of a network?
 ======================================
 * meta data likely belongs in a sqlite database in `/var/db/vessel`
 * The json metadata should be moved to the sqlite database
 * each container has a uuid
 * the jail.conf file uses the --name of the container for the file name
 * the hostname is set to --name
 * When vessel starts up, it needs to check the state of each network, compare to the running containers and
   cleanup as needed.
 
 What is the vessel-supervisor interface?
 ========================================
 
 * Add a `[network:<name>]` section
 * section contains a type and address
 * alternatively we could support separate network files that are processed first.  They need to be idempotent
 
 Notes on different types of networks
 ====================================
 
 ## Epair bridged
 
 This is the easiest type of network and what jib sets up.  You simply create an epair, assign it
 to a vnet jail and assign the other end to a bridge.  Then you can use the subnets DHCP server 
 (if available) to get the network configuration.  Otherwise, you would need to configure the network manually.

 
 ## IP Assigned Jails

This is how jails were done before vnet.  I don't think vnet jails are a complete replacement for this.
VNET jails allow for easy communicating with external infrastructure and routing management.  However,
if you do not own the external infrastructure, they do not integrate well.  They don't integrate well
because they require either generated mac addresses that the external infrastructure doesn't know about,
or multiple NICs.  It does not support the situation where multiple IP addresses are available for the
same network interface.     

### Why

## Router jail and vlan

A router jail is created that runs a dhcp and dns server.  The dns server is updated with the 
hostname of each jail as it is added to the vlan.  Each "cluster" of jails on a host is on a 
separate vlan on the bridge.  Each jail has an epair.  The router jail has an internal vlan 
interface (generally an epair) and an eternal interface.  On home systems and virtualized systems
like virtualbox, connecting an epair in the router vm to the bridge works fine.  However, on 
AWS or other systems, the DHCP server isn't going to respond to a MAC address that it doesn't know,
so an internal interface would be needed (ENI).  The router jail uses pf to forward packets.  
I'm still haven't figured out if the router jail with ENI needs to be a legacy configuration where
it just uses an ip address of the ENI.  I need to play around with this more.
 
 