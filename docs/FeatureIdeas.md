Feature Ideas
==============
This page documents some thoughts on ideas that would be nice, useful or fun to implement in the future.

Vessel-Supervisor Networking
^^^^^^^^^^^^^^^^^^^^^^^^^^^^
There are tons of cool networking features we achieve with a supervisor.

* Service Discovery by jail hostname.
* Network management via DHCP.
* IP forwarding via nginx.  I don't think we need to mess with pf.
* Vessel networking sidecar jail.
    * Imagine a rctl controlled jail that ran with each version of vessel-supervisor.
    * It could run dnsmasq for dhcp and dns.
    * It would also run nginx for tcp forwarding and ssl termination.
    * Potentially would be a log sync
* Each instance of vessel-supervisor can have a bridge that supports multiple networks via epairs and vlan.

Event Driven Execution (Serverless)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Listen to kafka topic and feed it into a container.

* This is realy event driven execution and not serverless as there is no cloud provider managing the servers.
* Generally serverless integrates with the scripting language and calls a callback when a message becomes
  available.  We can do that with tcl and/or python but I think a good starting point is to just have the service
  read a message from stdin and shutdown the process when there are no available messages.  Maybe give some
  histerisis.

Vessel-Supervisor Monitor
^^^^^^^^^^^^^^^^^^^^^^^^^
* Some systemd like features
    * Restart
    * Redirect standard out logs
    * Resource control - rctl command is in vessel feature

