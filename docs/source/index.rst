.. FBSDAppContainers documentation master file, created by
   sphinx-quickstart on Sat Jan  2 23:54:32 2021.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to FBSDAppContainers's documentation!
=============================================
FBSDAppContainers is a project that aims to unleash all of the amazing features
of the FreeBSD operating system to application developers.  FreeBSD has many amazing
features that go unused because there is no great way of exposing them to application
developers.

In my opinion, FBSD is completely underutilized in the application space and generally
is used in the more classic operations space where custom applications are not being used.
Ignoring the fact that FBSD also has a niche in appliances.  There is This makes
sense as Linux has mostly won battle of developer focus.

In the last 5 years or so, Linux development has mostly meant working with Docker.
FBSDAppContainers is definitely influenced by Docker.  However, there are many things
that I disagree with with Docker and this project diverges from dockers influence.

.. note::
   The program name for FBSDAppContainers is *vessel*.  This project started as a prototype
   and has continued to grow.  The initial name of the program was *appc* but that
   has been used by a similar project.  So if you still see references to appc in the
   source code, that's why.

Quickstart
^^^^^^^^^^^^^^^^^^^^
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

    sudoe -E vessel run --interactive vesseldev:local sh



.. toctree::
   :maxdepth: 2
   :caption: Contents:



Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
