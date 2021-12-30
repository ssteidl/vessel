Quickstart
===========
Let's get started.  FBSDAppContainers uses a file to define and build a container
image.  The file is similar to a DockerFile.  A very simple VesselFile is shown below

.. code-block:: guess

    FROM FreeBSD:12.1-RELEASE

    RUN env ASSUME_ALWAYS_YES=yes pkg update
    RUN env ASSUME_ALWAYS_YES=yes pkg install tcllib curl bash cmake

This is the VesselFile used for developing *vessel* itself.  Now that you have a VesselFile,
let's build the container image

.. code-block:: shell

    sudo -E vessel build --file=./VesselFile --name=vesseldev --tag=local

The above command will build an image named *vesseldev* with the special tag local.
Finally, let's run a *sh* in the new container.

.. code-block:: shell

    sudo -E vessel run --interactive vesseldev:local sh

There you have it, you have built and are running a persistent application container.
This is really the simplest use case, see the rest of the documentation for more
advanced use cases.

.. note::
   The program name for FBSDAppContainers is *vessel*.  This project started as a prototype
   and has continued to grow.  The initial name of the program was *appc* but that
   has been used by a similar project.  So if you still see references to appc in the
   source code, that's why.

