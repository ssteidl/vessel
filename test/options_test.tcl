load libappctcl.so
puts stderr $argv
puts [appc::parse_options $argv]

