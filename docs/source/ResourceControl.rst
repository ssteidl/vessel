Resource Limits
==================

Vessel integrates tightly with FreeBSDs resource limits.  One or multiple resource limits can be specified
in a vessel ini file.  For useful information on freebsd resource limits see `rctl(8) <https://www.freebsd.org/cgi/man.cgi?query=rctl&sektion=8>`_


.. note::
    Resource limits must be enabled in the kernel.  Before freebsd 12.2 this required adding :code:`kern.racct.enable=1`
    to /boot/loader.conf

.. code-block:: ini
   :linenos:

    [resource:maxprocesses]
    #Provide the rctl string without the 'jail:<jailname>' subject and subject-id.
    #Those will be added by vessel.

    #Deny more then concurrent 10 processes
    rctl="maxproc:deny=10"

    [resource:maxruntime]
    rctl=wallclock:devctl=5
    devctl-action=shutdown

    [resource:maxmemoryuse]
    rctl=vmemoryuse:devctl=128M
    devctl-action=exec=logger -t vessel "this could be any application.  Generally used for observability and monitoring"


Using Resource Limits
^^^^^^^^^^^^^^^^^^^^^^
* Each resource needs to be defined in a separate section named :code:`[resource:<name>]`.
* The :code:`rctl` key can be set to a valid rctl string.  The rctl string should not contain the subject or subjectid as those will be
  added by vessel.
* There is a second optional key :code:`devctl-action`.  If you use devctl as the resource string action then a custom
  action can be taken.  The supported actions are
    * :code:`shutdown`.  Cleanly shutdown the jail.
    * :code:`exec=<command params>`.  Execute an arbitrary process that can be very useful for monitoring and alerting.

