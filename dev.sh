#Setup the development environment by sourcing this script

export TCLLIBPATH=$PWD/src/lib/tcl
export LD_LIBRARY_PATH=$PWD/build
export PATH=$PWD/src/apps:$PATH
ln -sf $PWD/build/libappctcl.so $PWD/src/lib/tcl/libappctcl.so 
