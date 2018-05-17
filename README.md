# FBSDAppContainers
Application containers for FreeBSD.

## Goals
* Provide a simple and powerful interface to the plethora of underutilized FreeBSD features, including:
    * Jails (Heirarchical)
    * pf
    * zfs
    * capsicum
    * rctl
    * mandatory access control
    * Security Level
* Deeply integrate with FreeBSD system, preferring system libraries to fork/exec.  This project has 0 concern with being portable.

## Features

* **Image registry**: Pull multiple formats of images that can be used as filesystems for jails.  There could be multiple registry types:
    * ftp(s)
    * ssh
    * zfs: via zsend and zrecv
    * fs: local fs registry
    * http(s)
* **Layered images**: Use unionfs to layer images, similar to docker
* **Multiple Image Formats**
    * iso
    * tarball
* **Auto Networking**: 
    * expose ports: Automatically create pf redirect rule.
    * VIMAGE when supported by kernel
    * Auto create subnets based on network names
* **Task Scheduling**:
    * Support a scheduler passing tasks to different hosts.  Similar to borg or nomad
    * Perhaps implement a nomad backend.
