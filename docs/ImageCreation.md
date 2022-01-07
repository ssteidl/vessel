# Overview

There is an [example VesselFile and invocation](/README.md#quickstart) in the quick start guide.

# Supported Commands

VesselFiles support a small but powerful number of commands.  It is formatted similarly to a DockerFile file.

> 🕵️ Each command is 

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

Execute a command within the context of an image.

* commands
* Note on DNS
* common uses and commands
* Firstboot jails
