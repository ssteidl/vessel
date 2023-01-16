Multi IP Address Jails
======================

This is how jails originally implemented networking before vnet was available.  However, vnet does not
replace all usecases.  When running on cloud providers like AWS, connecting epair devices to the network
is not supported as the generated MAC addresses do not belong to AWS ENI (elastic network interfaces). While
you can have multiple ENIs per EC2 instance, if you want to support the maximum number of networked jails
per EC2 instance, you need to use IP jails.  See [this page](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-eni.html)
to see the ENI and IP address limits per instance type.

This type of jail network address management requires customized routing tables for jails.  To do this, you must update
boot/loader.conf to increase the number of fibs with `net.fibs=<num>`.  You should also set the sysctl `net.add_addr_allfibs=0`.

CLI Interface
--------------

Create the network.  This allows us to reuse the network fib when needed.  The name is optional and the
composite key is the gateway, interface and dns.

`vessel create-network --type=ip --gateway=<gateway ip> --dns=<dns> --nic=<ena1> --name=[optional name]`

We can store this in the sqlite database and allocate a fib (the fib number needs to be stored).

Then run a jail with:

`vessel run --ip=<ip address> --nic=<ena1> ...`

NOTE:

We should provide example ansible files on how to configure the host system for each.

NOTE:

We should avoid network architecture that requires configuring PF on the host.  We can provide an example but in
general we should avoid adding configurations to the host.