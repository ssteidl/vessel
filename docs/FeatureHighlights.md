

# Feature Highlights

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
There are two types of volume parameters that you can use via the `appc run` command:

* `vessel run -v <host directory>:<container directory>`
* `vessel run --dataset=?`

-v <host directory>:<container directory> --volume=<host directory>:<container directory>
   null mount a directory from the host filesystem to the container filesystem at the given paths

