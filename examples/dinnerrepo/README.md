# Context
This example creates a [fossil](https://www2.fossil-scm.org/home/doc/trunk/www/index.wiki) repository served via a lighttpd reverse proxy with scgi
protocol to the fossil server.

# Notes
Some important notes for this example:

* A ZFS dataset is defined in the .ini runtime configuration file.  This decouples the repository database from the container.  In the production environment, the zfs dataset (and thus the fossil database) live on an EBS volume.
* The fossil rc.d script is modified to create the repository if it doesn't exist.  This was easier then adding first boot support for such a simple repo.  It also changes the ownership of the repo mountpoint. 
* The Makefile demonstrates how to build, run, publish and deploy the container.  Deploying to AWS is as simple as scp'ing a file to EC2 instance running vessel-supervisor.
