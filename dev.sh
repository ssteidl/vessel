#Setup the development environment by sourcing this script

export TCLLIBPATH="$PWD/src/lib/tcl $PWD/test"
export LD_LIBRARY_PATH=$PWD/build
export PATH=$PWD/src/apps:$PATH
ln -sf $PWD/build/libvesseltcl.so $PWD/src/lib/tcl/libvesseltcl.so
ln -sf $PWD/build/libvesselsqlite.so $PWD/src/lib/tcl/libvesselsqlite.so 

export EDITOR=emacs
