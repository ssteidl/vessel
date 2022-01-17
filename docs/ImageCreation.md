# Overview

There is an [example VesselFile and invocation](/README.md#quickstart) in the quick start guide.

# Supported Commands

VesselFiles support a small but powerful number of commands.  It is formatted similarly to a DockerFile file.

> 🕵️ Fun fact... DockerFiles are valid tcl files.  Commands in Vessel are actually implemented using a tcl sub interpreter.

## 'FROM' Command

The `From` command tells vessel the base image to use.  Currently this image needs to be a FreeBSD.

**Example**

`FROM FreeBSD:12.3-RELEASE`

> 🕵️ The FROM command pulls a base tarball from "https://ftp.freebsd.org/pub/FreeBSD/releases/$arch/$version/base.txz".  This base image is extracted into a new
> dataset and a snapshot is created.

## 'COPY' Command

The copy command accepts a `source` and `dest`.  The source is relative to the current working directory of the host system.  The dest is relative to the current
working directory in the jail which defaults to /.

**Example**

`COPY . /app`

## 'CWD' Command

Change the current working directory of the jail.  This is a stateful command that only affects the COPY command.  It does not carry over when an image is run using `vessel run` (this is different then docker).

**Example**

`CWD /app`

## 'RUN' Command

Execute a command in the new image.

**Example**
`RUN env ASSUME_ALWAYS_YES=yes pkg install nginx`

> 🕵️ Each run command runs within a separate container (jail) on the new images dataset.  So commands use the dataset of the image not the host filesystem.  The 
> jail inherits the host networking stack and the resolv.conf file is copied from the host into the jail.

# Impage Publish and Pull

`vessel` supports `publish` and `pull` commands to transfer images to an image repository.  Vessel's image repositories are configured using the `VESSEL_REPO_URL` environment variable.  Vessel supports the following repository schemas:

* `file://` - The schema of the default repository.
* `s3://` - Uses an s3 bucket and key prefix for the image repository.

> 🕵️ When a repository uses the s3 schema, The `s3cmd` program is used to interface with the bucket.  Therefore, it's not only amazon's s3 object storage that can
> be used.  It's any object storage that s3cmd can interface with (including digital ocean).  Note `s3cmd` must be configured outside of the context of vessel
> before the s3 repository schema can be used.

After an image is published to a repository, it can then be pulled from another machine.

**Example**

```
env VESSEL_REPO_URL=s3://reweb-1234/images sudo -E vessel publish --tag=1.0 reweb
```

and from a different machine:

```
env VESSEL_REPO_URL=s3://reweb-1234/images sudo -E vessel pull --tag=1.0 reweb
```

or to export an image for manual transfer

```
env VESSEL_REPO_URL=file:///usr/home/shane/images sudo -E vessel pull --tag=1.0 reweb
```
