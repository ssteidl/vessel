# Introduction

vessel is very good and running multiple jails on the same FreeBSD instance.  The obvious next step is to run VMs on multiple instances via an container orchestrator.  We could potentially integrate with consul and nomad.  However, I think we will be better suited writing something customer fit to work with vessel.  

The real reason though is because I need a good project to learn erlang and elixir.

# Design

The cluster manager will:

1. Communicate with vessel-supervisor via a json interface.
2. vessel-supervisor will make an outgoing connection to the cluster via environment variable or commandline option
3. A periodic heartbeat will be sent to the connected node in the cluster
4. swarm and libcluster will be used for auto detection and load balancing as needed.
5. otel will be used for observability
6. Ets or mnesia will be used for persistance needs and crash recovery
7. Migration from one vm to another will require vessel to properly shutdown a jail, communicate with the cluster and vessel-supervisor on another jail will start the new jail.  Hopefully we can base all of this on swarm
8. A phoenix app can be used for visualization and potentially log viewing per VM.  Log aggregation and viewing would be a sweet feature.
