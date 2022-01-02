

# Feature Highlights
This table should go in the main readme file with links to the documentation of each feature

|Feature                                  | Implemented|
|-----------------------------------------|------------|
| Image Description File                  | yes        |
| Volume Management                       | yes        |
| Image Import/Export                     | yes        |
| Image Push/Pull Repositories (s3)       | yes        |
| Jail monitoring and auto cleanup        | yes        |
| DNS Service Discovery                   | Not yet    |
| Internal (Bridged) Networking           | Not yet    |
| Resource control                        | yes        |

## Image Definition Files

Similar to a DockerFile, a VesselFile allows for defining how a container image should be built.  A realworld example:

```
   FROM "FreeBSD:12.1-RELEASE"

   RUN env ASSUME_ALWAYS_YES=yes pkg update
   RUN env ASSUME_ALWAYS_YES=yes pkg install postgresql11-server
   RUN sysrc postgresql_enable="YES"
```

## Volume Management

### Null Mounting Directories
It is often useful to null mount (or bind mount) a directory from the host system into the container.  This is particularly useful for development purposes when you want to use an editor or IDE for the source code on the host system but test that code within a running container.  This type of mounting can be done with the -v or --volume flag given to the run command.
* `vessel run -v <host directory>:<container directory>`

### Jailing ZFS Datasets
TODO

