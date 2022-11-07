# Streaming Logs

Most applications need to support streaming logs and different log requirements.  There are very good projects that solve this problem, 
like fluent-bit, syslog-ng logstash etc.  If you just need to centralize logging and rotate log files, syslog and newsyslog will work fine. It can be
very nice to ship logs to a managed log service.  

We generally use logz.io which provides an elk stack for log management.  It has a community tier and various ways to ship the logs.  We made a simple log
streamer that can use tls to ship formatted logs.  We've needed this multiple times so it seemed like a good idea to just open source it.

## Requirements

* Integrate with FreeBSD's syslog (use |exec)
* TLS is required
* attempt to parse messages that start { or [ as json messages
* non json messages are formatted into a json object with a top level "msg" property
* syslog attributes will added to the json object as strings
* hard coded attribute values can be added to each json object by providing them in a configuration file `/usr/local/etc/vessel/logattrs.conf`
* logs are sent in json lines format.

## Implementation Options

There's a few options for implementation.

### TclTls with json lines
This would be ideal but tcltls required a change for FreeBSD 12.3-RELEASE and openssl.  I created a ticket with the fix but I don't think I'm going to use it as I would need to fork and maintain tcl tls.

### Curl Multi integrated with tcl

Curl multi works well and can be integrated with tcl pretty easily.  Integration with tcl is necessary so that I can parse and generate json objects
without pulling in another dependency.  This would mean using HTTP though.

### Raw OpenSSL with  KQueue and Json Lines
This wouldn't be that bad either but would require extra dependencies or integration with tcl again.  It would likely be less bandwidth if we just used json lines with TLS.  HTTPS is pretty inefficient.


### Notes
After iterating the options, forking tcltls migh not be that terrible of an idea.  I did it with UDP as well and that was fine.
