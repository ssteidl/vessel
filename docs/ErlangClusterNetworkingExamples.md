Overview
========

This document describes the different mechanisms for jail networking and the use cases for each.  We
use an erlang cluster and an exercise to describe each one.

IP Aliased Jails
================

IP aliased jails are useful when you cannot or do not want to expose virtual devices to the external network
infrastructure.  These jails require management of network configuration.  These are useful for some forms
and testing but mostly useful for situations where you need to run multiple containers on virtual hardware
where the cloud provider is able to provide multiple IP addresses for each (virtual) NIC.

IP Aliased Jails for Erlang Development
=======================================

* 3 containers in an EC2 instance that communicate with each other and the internet using an extra ENI instance.
* To do this you need to manage the extra IP addresses and routing tables.

vnet jail on a virtual box vm with a nat'd network
==================================================

This should be the easiest way to generate a cluster.  Just use jib to connect an epair to each jail and connect each
epair to a bridge.  Should be able to just use jib for each.  Service discovery won't be available unless we add that
DNS server on the network as well.  

JIB is just a utility script to help generate mac address and configure the jail.

This will work on a home network or virtual box nat'd network.

Steps for cluster:

1. Start an instance of vessel for each
2. I'm not sure if a nullfs mount can be mounted to multiple jails, if not, disallow nullfs mounts in cluster mode.
nullfs would be best because it would support monitoring the source files.
3. If nullfs is not available, code is released to a dataset.  The dataset is cloned for each jail.  If the jails have
names then the dataset will have a name.  If the jail is anonymous, the dataset will be anonymous.
4. Hostnames can be specified for each instance or for a single instance and a number suffixed to the end.

IP Aliased Jails on EC2
=======================

Network Testing with VLANs
===========================