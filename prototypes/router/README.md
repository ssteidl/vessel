# Notes
This directory contains the output of a deep dive I did in researching
the correct way to run multiple isolated vnet jails on a bridge vlan.

The gist of the design is that you have a router jail that can run DNS for
service discovery of other jails on this node as well as other nodes.  However, I didn't get far enough as to injecting ips from other nodes.  DNSMasq has a dbus interface but I also considered implementing DNS myself,
likely in erlang or elixir orchestrator.

## network.tcl

This package has a dnsmasq file and an embedded ini and VesselFile to generate the router.