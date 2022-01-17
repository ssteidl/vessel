
# Tips and Tricks

Some tips and tricks for working with vessel.

# How to Develop Images to Run Applications

Developing a VesselFile is straight forward:

1. Start an interactive prompt in a minimal image null mounting the application folder: `sudo -E vessel run --interactive --rm -v $PWD:/app minimal:12.3-RELEASE`
2. Install the application into the container following the installation process.  Let's say `make install` for this example.
3. Install the packages needed to run the application.  Note the packages in the VesselFile.  Generally they are listed in a single `pkg install` command.  
```
RUN env ASSUME_ALWAYS_YES=yes pkg update
RUN env ASSUME_ALWAYS_YES=yes pkg install <pkg list>
```
4. Run `sudo -E vessel build --file=./VesselFile --tag=latest --name=myapp`
5. Run the app command in the newly built container and verify that your applications runs properly.  If your app doesn't run properly, start a shell in your newly built container and fix it (and update your VesselFile)
6. Generate a runtime definition file with the appropriate resources, volumes, jail options and cpusets

# Dependencies with Vessel Supervisor

Vessel supervisor does not yet have great container dependency support. The only way to simulate this is by setting `start-delay` values in the vessel-supervisor section of the runtime file. 

# Minimize Images

When generating a vessel image, it's good practice to delete unnecessary files that are installed with packages. For instance the man pages like man pages.  This allows for smaller file transfers when publishing and pulling images.  It also takes less disk space.  For tiny images, learn how to use FreeBSDs support for firstboot services.   

# FreeBSD Init System

The most powerful tool to learn when working with vessel containers is the FreeBSD init system.  Images should be started with rc files using the standard init tools.  This includes `rcorder` and all of the functions defined in 

**Firstboot Service File Example**
The following firstboot file installs and starts a postgres instance the first time a container is started.
```
#!/bin/sh

# PROVIDE: postgresql_firstboot
# REQUIRE: DAEMON
# BEFORE:  postgresql
# KEYWORD: firstboot 

. /etc/rc.subr

name="postgresql_firstboot"
rcvar="postgresql_firstboot_enable"
start_cmd=do_start

do_start()
{
    env ASSUME_ALWAYS_YES=yes pkg update
    env ASSUME_ALWAYS_YES=yes pkg install postgresql12-server
    chown postgres:postgres /var/db/postgres
    service postgresql initdb
    service postgresql start
    /usr/local/bin/psql -h localhost -U postgres -c "create database re;"
}

load_rc_config $name
run_rc_command "$1"
```

# Debugging, Reviewing and Using jail.conf file

Vessel attempts to work with existing system tools instead of replacing them.  To work with the `jail` command vessel must generate jail.conf files.  The jail.conf file for a jail is stored in `/var/run/vessel/jails/<jail_name.conf>`.  If your container fails to start, you can see the generated jail.conf file via stderr of vessel by using the `--debug` provided to the vessel command `vessel --debug run ...`

**Example**
`jail -r -f /var/run/vessel/jails/<name.conf> <name>`
