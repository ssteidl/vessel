package require vessel::env

package require vesselsqlite3

namespace eval vessel::networkdb {
    
    
    namespace eval _ {
    
        variable db {_vesseldb}
        
        proc open_db {path} {
            variable db
            
            sqlite3 $db $path -create true 
        }
        
        proc create_db_schema {} {
            
            variable db
            
            $db eval {
                create table if not exists networks (
                    name text not null,
                    interface text not null
                );
            }
        }
    }
    
    proc init_db {{path {:memory:}}} {
        variable db
        
        _::open_db [vessel::env::vessel_db_dir]
    }
}