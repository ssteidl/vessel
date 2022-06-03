# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require vessel::env
package require vessel::zfs
package require defer
package require fileutil
package require json
package require json::write
package require logger
package require struct::matrix

namespace eval vessel::imageutil {

    proc parse_image_name {image_name {default_tag {latest}}} {
        # Parse an image name with the optional tag format.
        # A dict will be returned with both "name" and "tag"
        # set to the appropriate values.
        #
        # Params:
        #
        # image_name str <image>[:tag]
        #
        # default_tag str Optional parameter to specify the default tag if
        # none is given. 

        if {[string first / $image_name] != -1} {
            return -code error -errorcode {IMAGENAME ILLEGAL SLASH} "Image names cannot contain '/'"   
        }
        
        set image_parts_d [dict create]

        set image_components [split $image_name :]
        dict set image_parts_d "name" [lindex $image_components 0]
        dict set image_parts_d "tag" $default_tag
      
        if {[llength $image_components] > 1} {
            dict set image_parts_d "tag" [lindex $image_components 1]
        }

        return $image_parts_d
    }
}

#NOTE: The metadata db was going to be an sqlite database that
# held metadata for images and containers.  That may still happen but
# initially it makes more sense to just have a directory of json files
# that can be easily transformed into jail files.

namespace eval vessel::metadata_db {
    #The matadata_db module is an interface to get all metadata from
    #images and containers.  The actual store for the metadata varies.
    #We try to not duplicate data.  For instance, if metadata can be found
    #via the filesystem or zfs command, we aren't going to duplicate that
    #data in a database or json file.

    logger::initNamespace [namespace current] debug
    variable log [logger::servicecmd [string trimleft [namespace current] :]]
    
    namespace eval _ {

        proc dict_get_value {dict key default_value} {

            if {[dict exists $dict $key]} {
                return [dict get $dict $key]
            }

            return $default_value
        }

        proc create_metadata_json {metadata_dict} {
            # metadata_dict params:
            #    name: Name of the image.  Required
            #    tag: Tag of the image.  Defaults to latest
            #    command: command to be ran /etc/rc by default
            #    cwd: Initial working directory
            #    parent_images: Currently will always be some version of FreeBSD defaults
            #                  to FreeBSD:12.1.  In the future we can make it a sorted list
            #                  of images. This is expected to be a list with a single element

            set name [dict_get_value $metadata_dict {name} {}]
            if {$name eq {}} {
                return -code error -errorcode {METADATA REQUIRED NAME} \
                    "name field must exist in dictionary"
            }

            set tag [dict_get_value $metadata_dict {tag} {latest}]
            set command [dict_get_value $metadata_dict {command} {/etc/rc}]
            set cwd [dict_get_value $metadata_dict {cwd} {/}]
            set parent_images [dict_get_value $metadata_dict {parent_images} {FreeBSD:12.1}]

            set json_str [json::write object \
                "name" [json::write string $name] \
                "tag" [json::write string $tag] \
                "command" [json::write array \
                {*}[lmap l $command {json::write string $l}]] \
                "cwd" [json::write string $cwd] \
                "parent_images" [json::write array \
                {*}[lmap l $parent_images {json::write string $l}]]]

            return $json_str
        }

        proc read_metadata_json {dataset} {

            # params:
            #
            # dataset: The complete name of the dataset.  zroot/vessel-test/FreeBSD:12.1

            set components [split $dataset /]
            set child_name [lrange $components end end]
            set filename [file join [vessel::env::metadata_db_dir] "${child_name}.json"]

            set json [fileutil::cat $filename]

            set metadata_dict [json::json2dict $json]
            return $metadata_dict
        }

        proc list_images {output_chan} {

            #Output script consumable fields for each image to output_chan.

            variable ::vessel::metadata_db::log
            
            set headers [list ID PARENT COMMAND]
            set vessel_dataset [vessel::env::get_dataset]

            set dataset_list [vessel::zfs::dataset_children $vessel_dataset]

            #We don't care about the parent dataset
            set children_list [lrange $dataset_list 1 end]

            set matrix_name {image_output_matrix}
            struct::matrix $matrix_name
            $matrix_name add columns 3

            set image_data [list]
            foreach child_dict $children_list {
                set dataset_name [dict get $child_dict {name}]

                #We don't want to list container images here. So we only use
                #images with 3 parts when we split on /.  An example
                #container image is:
                #zroot/jails/minimal:hackathon/0bdefddd-a753-48a8-bd85-750d5031464d
                #
                #TODO: This is yet another reason why we should just iterate the
                #images in the metadata_db dir and verify they have a corresponding
                #dataset.
                set component_count [llength [split $dataset_name /]]
                if {$component_count == 4} {
                    continue
                }

                try {
                    set dataset_metadata [read_metadata_json $dataset_name]
                } trap {} msg {
                    ${log}::warn "Could not read db file for dataset: $dataset_name"
                    continue
                }
                set command [dict get $dataset_metadata command]
                set parent_image [lindex [dict get $dataset_metadata parent_images] 0]
                set dataset_output_list [list $dataset_name \
                    $command \
                    $parent_image]

                set image_data [lappend image_data ${dataset_output_list}]
            }

            set matrix_cmd {output_matrix}
            struct::matrix $matrix_cmd
            defer::defer [list matrix_cmd] {
                $matrix_cmd destroy
            }

            $matrix_cmd add columns 3
            $matrix_cmd add row [list DATASET CMD PARENT]
            foreach row $image_data {
                $matrix_cmd add row $row
            }


            puts $output_chan [$matrix_cmd format 2chan]
        }
    }

    proc metadata_file_path {image_name tag} {
        set metadata_dir [vessel::env::metadata_db_dir]
        set metadata_file [file join $metadata_dir "${image_name}:${tag}.json"]
        return $metadata_file
    }

    proc write_metadata_file {image_name tag cwd cmd parent_images} {

        #params:
        #
        # image_name: the image name without the tag appended
        # tag: The tag for the image
        # cwd: current working directory when the container is started
        # cmd: Command to run by default
        # parent_image: The one parent image


        set json_content [_::create_metadata_json [dict create \
            name $image_name \
            tag $tag \
            command $cmd \
            cwd $cwd \
            parent_images $parent_images]]

        try {
            #Tempfile rename to avoid corruption
            #TODO: If I'm going to be doing this stuff, I might as well just use sqlite
            set tmp_file_chan [file tempfile file_path "${image_name}.json"]
            puts $tmp_file_chan $json_content
            flush $tmp_file_chan
            set metadata_file [metadata_file_path $image_name $tag]
            file rename -force $file_path $metadata_file

        } finally {

            catch {close $file_chan}
        }

        return $metadata_file
    }

    proc image_exists {image tag} {

        set metadata_file [metadata_file_path $image $tag]
        return [file exists $metadata_file]
    }

    proc image_command {args_dict} {

        set do_list [_::dict_get_value $args_dict "list" false]
        if {$do_list} { 
            _::list_images stdout
            return
        }

        set rm_image [_::dict_get_value $args_dict "rm" {}]
        if {$rm_image ne {}} {
            # Get the dataset from the environment module
            # recursively destroy the dataset with the zfs module
            set image_parts [vessel::imageutil::parse_image_name $rm_image]
            set image_name [dict get $image_parts "name"]
            set tag [dict get $image_parts "tag"]
            set dataset [vessel::env::get_dataset_from_image_name $image_name $tag]

            catch {vessel::zfs::destroy_recursive $dataset}
            catch {file delete [metadata_file_path $image_name $tag]}
        }
    }
}

package provide vessel::metadata_db 1.0.0
