Streaming Logs
==============
Most applications need to support streaming logs and different log requirements.  There are very good projects that solve this problem, 
like fluent-bit, syslog-ng logstash etc.  If you just need to centralize logging and rotate log files, syslog and newsyslog will work fine. It can be
very nice to ship logs to a managed log service.  

We generally use logz.io which provides an elk stack for log management.  It has a community tier and various ways to ship the logs.  We made a simple log
streamer that can use tls to ship formatted logs.  We've needed this multiple times so it seemed like a good idea to just open source it.

Requirements
------------

* Integrate with FreeBSD's syslog (use |exec)
* attempt to parse messages that start { or [ as json messages
* non json messages are formatted into a json object with a top level "msg" property
* syslog attributes will added to the json object as strings
* hard coded attribute values can be added to each json object by providing them in a configuration file `/usr/local/etc/vessel/logattrs.conf`
* logs are sent in json lines format.
