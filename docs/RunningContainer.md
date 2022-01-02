# Vessel Run Command

Invoking a container from an image is done with the `vessel run` command. Interactive jails are simple to create from the commandline.  If you are making a container that will be used multiple times, it's best to use a runtime ini file.

# Commandline Arguments

The run command help is copied below.  `{}` mark optional parameters.

```
vessel run {--name=container_name} {--interactive} {--rm} {--volume=/path/to/hostdir:/path/to/mountdir} 
{--dataset=zfs/dataset:container_mountpoint} image{:tag} {command...}

--name        Name of the new container
--interactive Leave stdin open.  Useful for running shells
--rm          Remove the image after it exits
--dataset     Use the specified zfs dataset at the mountpoint.  Creates the dataset if needed.
--volume      Path to directory to nullfs mount into the container
--ini=<path>  Path to the ini file which specifies how the jail should be run
```

## Anonymous vs. Named Containers

An important distinction when using the commandline is understanding the difference between anonymous and named containers.  If you invoke a container without the `--name` option, the container is considered to be an anonymous container and a new dataset will **always** be cloned from the provided `image` parameter.

If the `--name` parameter is provided, a new dataset is only cloned if a cloned dataset with the given base image and name combination does not already exist.

> 🕵️ Given the command:
> *  `sudo -E vessel run --name pkgtest minimal:12.3-RELEASE env ASSUME_ALWAYS_YES=yes pkg install bash` 
> * followed by:
> *  `sudo -E vessel run --interactive --name pkgtest minimal:12.3-RELEASE bash`.  
> * The second invocation would open a bash shell because the [VESSEL_POOL]/jails/minimal:12.3-RELEASE/pkgtest dataset already existed and bash has been installed in that dataset.  So instead of cloning a new dataset like with anonymous jails, the existing dataset was used.

## Commandline Examples

### Simple Ephemeral Container

Assuming `vessel init` has already been run on a `12.3-RELEASE` image.  We can start a shell in a new jail with:

`sudo -E vessel run --interactive --rm minimal:12.3-RELEASE sh`

This command will always start a jail in a new clone of the minimal:12.3-RELEASE dataset.  The sh command will be run in the shell.  The `--rm` command is given because we don't want a one-off anonymous (no name) jail cluttering up our zfs pool.

> 🕵️ if you don't provide the `--interactive` flag, the jail would start and then immediately exit.  This is because the `--interactive` flag keeps stdin open, if it is not open, the shell will notice and immediately exit.

### Development Test Container

TODO: Container to nullmount the source directory into a container

# Runtime File

Quick, ephemeral containers from the commandline can be useful for simple tasks.  The real power in `vessel` comes from exposing the powerful features of the FreeBSD operating system to user workloads.  Containers can be easily defined in a ini file that is referred to as   

```
[dataset:upload-images]
dataset=zroot/upload-images
mount=/var/db/uploaded-images

[jail]
# anything in this section is treated as a jail parameter and will
# be added to the generated jail file.
host.hostname=reweb
```

## Volumes and Datasets

## CPU Sets

## Resource Control

## Jail Parameters

