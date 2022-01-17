
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
* How to develop images with --name or --local containers

# Dependencies with Vessel Supervisor
* Set start delay when containers need to be started in order.  Later we can implement start messages

# Minimize Images
* delete unnecessary folders when building

# FreeBSD Init System
* learn the freebsd init system and how to use firstboot jails

# Debugging, Reviewing and Using jail.conf file

