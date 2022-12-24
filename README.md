# Vessel
Application containers for FreeBSD.

The goal of vessel is to expose the many powerful features of FreeBSD to application, ops and test engineers.  Vessel accomplishes this goal by integrating tightly with FreeBSD system level interfaces and providing a "docker-like" interface that feels familiar to most developers.  Vessel differs from other jail management systems in that it runs alongside the container listening for system events that are useful for management and observability.

# Feature Highlights

|Feature                                                                            | Implemented|
|-----------------------------------------------------------------------------------|------------|
| [VesselFile (similar to Dockerfile)](docs/ImageCreation.md)                       | Yes        |
| [Run configuration files (ini)](docs/RunningContainer.md#runtime-file)            | Yes        |
| [Volume Management](docs/RunningContainer.md#volumes-and-datasets)                | Yes        |
| [Image Push/Pull Repositories (s3)](docs/ImageCreation.md#impage-publish-and-pull)| Yes        |
| [Jail Management](docs/RunningContainer.md#jail-management)                       | Yes        |
| [Container Supervisor](docs/Supervisor.md)                                        | Yes        |
| [Resource Control](docs/ResourceControl.md)                                       | Yes        |
| [CPU Sets](docs/RunningContainer.md#cpu-sets)                                     | Yes        |
| Internal (Bridged) Networking                                                     | In Progress|
| DNS Service Discovery                                                             | Not yet    |
| Multi-node container orchestration                                                | Not yet    |
| VNET Routing via PF                                                               | Not yet    |

* [Tips and Tricks](docs/ExamplesTipsAndTricks.md)
* [Build, Install and Develop](docs/BuildAndInstall.md)

# Quickstart

Initialize your user environment to work with vessel.  The init command will create a minimal image by downloading the base tarball of the currently running container and installing it into a dedicated dataset.

`sudo -E vessel init`

Run a shell in an ephemeral container using the previously created minimal image:

`sudo -E vessel run --interactive --rm minimal:12.3-RELEASE -- sh`

## Vessel Files

While quickly running a minimal container can be useful, it's generally more useful to create a customized container.  For this we can use a VesselFile which is similar to a DockerFile.  Let's look at a VesselFile that creates a container to run a custom django application.  Note that the modeline is set to tcl to allow for syntax highlighting

```
# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

FROM FreeBSD:12.2-RELEASE

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

# Note On Networking

The current version of vessel uses ipv4 inherited networking (IOW, the host network stack).  In the future a bridged and vlan networking system with VNET will be implemented.  For now, only inherited networking is used.  

> ℹ️ We have found that using inherited networking is not the major limitation that it seems.  While a full fletched vnet network would/could have it's uses, inherited network has met all of our use cases so far.

