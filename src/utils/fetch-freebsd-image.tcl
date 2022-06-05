#!/usr/local/bin/tclsh8.6
# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require vessel::bsd
package require vessel::metadata_db
package require vessel::repo

set env(VESSEL_DOWNLOAD_DIR) [pwd]

set name "FreeBSD"
set version [vessel::bsd::host_version_without_patch]
vessel::repo::fetch_base_image ${name} ${version}