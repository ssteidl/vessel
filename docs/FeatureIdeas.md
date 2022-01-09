# Feature Ideas
This page documents some thoughts on ideas that would be nice, useful or fun to implement in the future.

# Vessel-Supervisor Networking

There are tons of cool networking features we achieve with a supervisor.

* Service Discovery by jail hostname.
* Network management via DHCP.
* IP forwarding via pf
* Vessel networking sidecar jail.
    * Imagine a rctl controlled jail that ran with each version of vessel-supervisor.
    * It could run dnsmasq for dhcp and dns.
    * It would also run nginx for tcp forwarding and ssl termination.
    * Potentially would be a log sync
* Each instance of vessel-supervisor can have a bridge that supports multiple networks via epairs and vlan.

# Event Driven Execution (Serverless)

Listen to kafka topic and feed it into a container.

* This is realy event driven execution and not serverless as there is no cloud provider managing the servers.
* Generally serverless integrates with the scripting language and calls a callback when a message becomes
  available.  

