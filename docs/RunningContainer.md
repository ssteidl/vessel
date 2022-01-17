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

It's often useful to manually create a development environment container and then mount a host folder into the container.  The host would contain the source code being built in the development container.  Thus allowing editors installed on the host system to edit source files in a development container.  Below is an example of how the author develops a django application:

* `sudo -E vessel run --name=uwsgi --volume=$PWD:/development uwsgi:local sh`
* `# uwsgi --ini=development/uwsgi/dev.ini`
   * uwsgi is (among other things) WSGI server that can run django.  It has hot reloading functionality
* Because my source directory ($PWD) contains the source code and is mounted in the container at `/development`; changes to the sourcefile will automatically be noticed by uwsgi running in the container at the application reloaded. 

# Runtime File

Quick, ephemeral containers from the commandline can be useful for simple tasks.  The real power in `vessel` comes from exposing the powerful features of the FreeBSD operating system to user workloads.  Containers can be easily defined in a ini file that is referred to as a runtime definiton file.

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

Volumes and datasets are different mechanisms to allowing data to persist outside of the lifetime of the container.

### Volumes

Volumes are directories from the host system that are mounted into one or more containers.   You can add a volume to a container by using the `--volume=` parameter or adding a `[nullfs:<name>]` section to the runtime definition file. 

**Volume Example INI Section**

> ℹ️ We've found that volumes are generally provided on the commandline and datasets are defined in runtime definition files.

```
[nullfs:develdir]
directory=/usr/home/shane/projects
mount=/projects
```

> 🕵️ The volume uses [nullfs](https://www.freebsd.org/cgi/man.cgi?query=nullfs&sektion=&n=1) to mount a directory into a container.

### Datasets
Datasets are useful for providing large amounts of persistent storage to ephemeral containers.  `vessel` datasets are zfs datasets that are configured to be controlled by the container.  You can add a dataset to a container by adding a `--dataset=` parameter or adding a `[dataset:<name>]` section to the runtime definition file.  

**Dataset Example INI Section**
```
[dataset:pgdata]
dataset=zroot/volumes/redata
mount=/var/db/postgres
```
> 🕵️ The following steps are taken to jail datasets:
> * Create the dataset if necessary
> * Set the mountpoint to the *mount path within the jail*
> * Set the jailed attribute
> * Call `zfs jail` on the dataset
> * Call `zfs mount` on the dataset after the jail is created.


## CPU Sets
CPU sets can be used to pin jails to specific CPUs.  This allows for more fine grained resource management.  See [cpuset(1)](https://www.freebsd.org/cgi/man.cgi?query=cpuset&sektion=1&format=html).  A CPU set for a jail can be configured only in the runtime definition file.

**CPU Set Example INI Section**d
```
[cpuset]
list=0,3
```

> 🕵️ The cpu set section takes the value of `list` and runs the command `cpuset -c -l <list value> -j <jailid>`

## Resource Control

See [Resource Limits](./ResourceControl.md)

## Jail Parameters
Most who have worked with jails know that there are a lot of options and parameters in a jail file.  See [jail(8)](https://www.freebsd.org/cgi/man.cgi?query=jail&apropos=0&sektion=0&manpath=FreeBSD+13.0-RELEASE+and+Ports&arch=default&format=html).  Vessel does not attempt to control or abstract these parameters.  Therefore, a special 'jail' section in the runtime definition file is used to set pass through any of the available configuration parameters through to the jail system.

**Jail Example INI Section**

```
[jail]
sysvshm=new
host.hostname=testhost
```

# Jail Management
Unlike docker, vessel has first class support for running "thick containers" in the foreground.  Thus, allowing for multiple system services to be running in a single container.  Including syslog, cron and any other services that may be useful to run next to an application. 

Vessel has the ability to track when a jail exits and cleanup after the jail.  If using the supervisor, it will even restart the jail for you if necessary.

> 🕵️ FreeBSD lacks a "jail exit" event.  Therefore, vessel makes up for the lack of this event by tracking process creation/exits using kqueue process tracking.
>   When all child processes of the start command have exited, vessel closes and cleans up the jail.  For this reason, the `persist=1` argument to the jail 
>   is always set.  Otherwise the jail would exit before vessel could finish system cleanup.

> 🕵️ Jail cleanup is done via:
> * `jail -r -f </var/run/vessel/jails/<jail_name.conf>`
> * Some custom cleanup methods that should be moved to the jail.conf file.

