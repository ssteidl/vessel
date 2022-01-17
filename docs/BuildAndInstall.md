# Creating a FreeBSD Package
Vessel has not yet been accepted into the FreeBSD port collection.  However it is simple to build a package for installation.

1. Ensure that the ports tree is installed.  Namely `/usr/ports/Mk/` needs to be available.
2. Create the tarball with HEAD of the cloned repository: ```sudo env DISTDIR=/tmp make -e -f port/port-helper.mk _V=`git rev-parse HEAD` tarball```
3. Build dependencies and package: ```sudo env DISTDIR=/tmp make -e -C port _V=`git rev-parse HEAD` package```

# Building and Developing Vessel

Vessel uses CMake as a build system.  To develop vessel, a script `dev.sh` is used to setup the environment.  `. dev.sh` will setup the environment so in-tree changes are picked up whenever `vessel` is invoked.

1. `mkdir build`
2. `cd build`
3. `cmake ..`
4. `make`
5. `cd ..`
6. `. dev.sh`
