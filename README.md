# Vessel
Application containers for FreeBSD.

The goal of vessel is to unleash the plethora of underutilized FreeBSD features to application, DevOps and test engineers.  The secondary goal of vessel is to feel similar to those who are comfortable working in a Linux docker environment.

Vessel accomplishes the above goals by integrating tightly with FreeBSD system level interfaces.  This differs from other jail management systems in that vessel actively monitors and manages running jails.  Examples include:

* Actively tracing jail processes to monitor when a jail exits.  This allows vessel to stay in the foreground while running a jail with multiple services, which has various management benefits.
* Monitors and parses `/var/run/devd.seqpacket.pipe` so that custom actions can be taken based on resource control events.
* Supervisor can monitor and route log output as well as stop, start and reload jails based on configuration file changes.

# Feature Highlights

|Feature                                               | Implemented|
|------------------------------------------------------|------------|
| VesselFile (similar to Dockerfile)                   | Yes        |
| Run configuration files (ini)                        | Yes        |
| Volume Management                                    | Yes        |
| Image Import/Export                                  | Yes        |
| Image Push/Pull Repositories (s3)                    | Yes        |
| Jail management                                      | Yes        |
| Container Supervisor                                 | Yes        |
| [Resource Control](docs/ResourceControl.md)          | Yes        |
| Internal (Bridged) Networking                        | Not yet    |
| DNS Service Discovery                                | Not yet    |
| Multi-node container orchestration                   | Not yet    |
| VNET Routing via PF                                  | Not yet    |


# Quickstart

Initialize your user environment to work with vessel.  The init command will create a minimal image by downloading the base tarball of the currently running container and installing it into a dedicated dataset.

`sudo -E vessel init`

Run a shell in an ephemeral container using the previously created minimal image:

`sudo -E vessel run --interactive --rm minimal:12.3-RELEASE sh`

## Vessel Files

While quickly running a minimal container can be useful, it's generally more useful to create a customized container.  For this we can use a VesselFile which is similar to a DockerFile.  Let's look at a VesselFile that creates a container to run a custom django application.  Note that the modeline is set to tcl to allow for syntax highlighting

```
# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

FROM FreeBSD:12.3-RELEASE

RUN mkdir -p /usr/local/etc/pkg/repos
COPY ./deployment/FreeBSD.conf /usr/local/etc/pkg/repos/FreeBSD.conf
RUN env ASSUME_ALWAYS_YES=yes pkg update -f
RUN env ASSUME_ALWAYS_YES=yes pkg install python
RUN env ASSUME_ALWAYS_YES=yes pkg install py37-django-extensions \
    py37-pandas uwsgi gnuplot-lite mime-support \
    py37-django-bootstrap4 py37-Jinja2 py37-psycopg2 \
    nginx

RUN sysrc syslogd_enable=YES
RUN sysrc uwsgi_enable=YES
RUN sysrc uwsgi_configfile=/re/freebsd/uwsgi.ini
RUN sysrc zfs_enable=YES
RUN sysrc nginx_enable=YES
RUN sysrc clear_tmp_enable=YES 

# We need to enable this kernel module via ansible first
# RUN sysrc nginx_http_accept_enable=YES

RUN sh -c "touch /var/log/all.log && chmod 600 /var/log/all.log"
RUN mkdir -p /var/log/nginx
COPY ./freebsd/syslog.conf /etc
COPY ./freebsd/nginx.conf /usr/local/etc/nginx
COPY . /re

```

To build the above image run:

`sudo -E vessel build --file=./DjangoAppVesselFile --tag=1.0 --name=djangoapp`

Once the image is built, it can be run with:

`sudo -E vessel run --rm djangoapp:1.0 sh /etc/rc`

This will start the init process in a new container running in the foreground.  

# Jail Management
Unlike docker, vessel is perfectly capable of running "thick containers" in the foreground.  Thus, allowing for multiple system services to be running in a single container.  Including syslog, cron and any other services that may be useful to run along side of the container. 

For those interested, vessel makes up for the lack of system event on jail exit by tracking process creation and exiting using kqueue process tracking.  Therefore, vessel can track when all jail processes have exited.  This is how vessel can shutdown jails cleanly with simple signal handling.  If you have started a jail via vessel, you can simply press ctrl+C to shutdown the jail (and all jailed processes) cleanly.



