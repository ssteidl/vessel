package require sqlite3

sqlite3 db {} -create true

db eval {
 
    create table if not exists network (
        name text primary key not null,
        vlan integer not null
    );
}


