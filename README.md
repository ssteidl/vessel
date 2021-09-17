# Vessel
Application containers for FreeBSD.

* [Quick Start](docs/QuickStart.md)
* [Feature Highlights](docs/FeatureHighlights.md)

## Goal
The goal of vessel is to unleash the plethora of underutilized FreeBSD features to application, DevOps (operations) and test engineers.  These features include but are not limited to:
 
 * Jails (Heirarchical)
 * pf
 * zfs
 * capsicum
 * rctl
 * mandatory access control
 * Security Level

## Vocabulary
* **Image**: A directory or mounted filesystem that the container will use as a root directory.
* **Image Archive**: A single file (usually a compressed image) that suitable for storing in a registry.
* **Registry**: A store for image archives (REST, local filesystem, ftp, etc)
* **Volume**: A filesystem that is mounted to a directory inside of the image.  Bind mount, memory back file mount, disk etc.
* **Container**: The combination of image, network stack, volumes and jail.

## Environment

* **APPC_IMAGE_DIR**: Directory for unpacked images
* **APPC_CONTAINER_DIR**: Directory for containers.  Images are mounted (nullfs mount for directories, mount for vnode fs's) here and
  containers are run in those images.
* **APPC_ARCHIVE_DIR**: Directory for archives to be saved (during creation or download).
* **APPC_REGISTRY_URL**: URL to the appc registry

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

# Commands needed to be useful for development and deployment
* **build**: Build an image given spec file.
* **publish**: Publish a built image into a repository (file and s3)
* **pull**: Pull an image into the system from a repository (file and s3)
* **run -t -v <volume> --network=<name>**: Run a container in the foreground with a network on
  the provided bridge (creating the bridge if necessary).
* **run**: Run a command in the background monitoring it as needed.  Potentially providing resource limits.

## Thougths
* It would be useful to integrate with uwsgi in emperor mode.
    * uwsgi already supports managing daemons.
    * uwsgi has async processors like mule, signals etc
    * Building and publishing the daemons would be external to uwsgi
    * Starting new containers is as simple as dropping new configuration files into a directory.  You could also do it from the command line.
    * We can still run all the code via tcl, it's just a new plugin.
    * I think we can still do interactive mode
    * We'd need to teach uwsgi how to monitor when a jail dies (monitor all the processes in the jail)
    * I think the development workflow is the same for appc.  Then there is just an appc plugin.
