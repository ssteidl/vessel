# Notes on Sqlite Amalgamation

* I got the amalgamation file from the fossil repo of sqlite.
* The amalgamation tarball doesn't include the tcl extension
* The commands were something like:
  * ./configure
  * make tclsqlite3.c
* Then I edited tclsqlite3.c to use Vesselsqlite3_Init and package name.