Vessel Supervisor
=============================================
Deploying, managing and supervising vessel containers.

The vessel supervisor and be used to easily deploy containers by monitoring a filesystem directory for
vessel deployment files.  This feature was inspired by uwsgi emperor mode.  It provides similar features to
emperor mode as well as supervisord but is more tightly integrated with vessel.

Deployment Workflow
^^^^^^^^^^^^^^^^^^^
A container can be quickly deployed (and perhaps more importantly) and safely re-deployed using the following workflow:

1. Build a container locally or in CI
2. Publish container to registry
3. Place deployment file in monitored directory using :code:`ansible` or :code:`scp`.  If redeploying, overwrite the existing deployment
   file.

Deployment File
^^^^^^^^^^^^^^^

Deployment files are ini files that explain to the vessel-supervisor how to start, shutdown or reconfigure the container.
They are used to, among other things, generate the jail file used to run the container.

*Example*

.. code-block:: ini
   :linenos:

   [vessel-supervisor]
   # The name of the image without the tag in the repository
   repository=s3://reapp/
   image=supercooldjangoapp
   tag=1.3.1
   command=sh /etc/rc

   [dataset:upload-images]
   pool=reappdata
   dataset=upload-images
   mount=/var/db/uploaded-images

   [jail]
   # anything in this section is treated as a jail parameter and will
   # be added to the generated jail file.
   sysvshm=new

