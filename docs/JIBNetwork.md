JIB Network
============

A jib network (named after the jib script) is a vnet based network that relies on external networking infrastructure
(DNS, DHCP, Routing).  This is generally useful for development because most cloud providers do not support
having virtual mac addresses on the network.  However, if the network infrastructure supports it, this is
a quick and simple way to integrate jails on the network.






                         -Bridge-
jail1--------------------|   |   |----------------------jail2
                             |
                            NIC
                            
                            
To create jails in this network, simply do a

`sudo vessel create-network --type=jib --interface=em0 --name=<network_name> --ruleset=<devfs num>`

After this is executed, we need to output a message that shows an example devfs ruleset that is needed. If
the user wants to use dhclient.

then run a jail on the network with:

`sudo jail run --network=<network-name>`

DNS is configured with the hosts resolv.conf

BPF the user needs to provide a devfs ruleset number.  We can output a 