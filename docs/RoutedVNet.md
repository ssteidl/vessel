Routed VNET
===========

Routed VNET is very useful for running an actual internal network completely on the host.  This can be useful for
deployment or simulating a broader production environment.  The router jail supplies DNS to support service
discovery as well.  


Description, each internal network can live on a separate VLAN.  A router jail runs for each network and routes packets
from the VLAN to an IP address.  This still requires an IP address for each internal network.  It also requires a fib
for each internal network to do the routing.

PF is used in the router for exposing ports (i.e. rdr), as well as nat.  This type of jail still needs a lot of prototyping
and validation.
