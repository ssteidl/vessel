.. FBSDAppContainers documentation master file, created by
   sphinx-quickstart on Sat Jan  2 23:54:32 2021.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

FBSDAppContainers (vessel)
=============================================
Application containers for FreeBSD

Project Goals
^^^^^^^^^^^^^
Unleash all of the features of the FreeBSD operating system to application developers.

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


Features
=============

.. list-table:: List of current and future features
    :widths: 10 5
    :header-rows: 1
    :stub-columns: 1

    * - Feature
      - Implemented
    * - Image Description File
      - yes
    * - Volume Management
      - yes
    * - Image Import/Export
      - yes
    * - Image Push/Pull Repositories (s3)
      - yes
    * - Jail monitoring and auto cleanup
      - yes
    * - DNS Service Discovery
      - Not yet
    * - Internal (Bridged) Networking
      - Not yet
    * - Resource control
      - Not yet

Image Definition Files
^^^^^^^^^^^^^^^^^^^^^^
Similar to a DockerFile, a VesselFile allows for defining how a container image should be built.  A realworld example:

.. code-block::
   :linenos:

   FROM "FreeBSD:12.1-RELEASE"

   RUN env ASSUME_ALWAYS_YES=yes pkg update
   RUN env ASSUME_ALWAYS_YES=yes pkg install postgresql11-server
   RUN sysrc postgresql_enable="YES"


Volume Management
^^^^^^^^^^^^^^^^^
Tere are two types of volume parameters that you can use via the `appc run` command:

#. `vessel run -v <host directory>:<container directory>`
#. `vessel run --dataset=?`

-v <host directory>:<container directory> --volume=<host directory>:<container directory>
   null mount a directory from the host filesystem to the container filesystem at the given paths

.. toctree::
   :maxdepth: 2
   :caption: Contents:


Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
