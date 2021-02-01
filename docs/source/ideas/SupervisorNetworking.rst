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

Vessel-Supervisor Monitor
^^^^^^^^^^^^^^^^^^^^^^^^^
* Some systemd like features
    * Restart
    * Redirect standard out logs
    * Resource control - rctl command is in vessel feature

