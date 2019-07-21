package require appc::native

#URL parts is a dictionary with the parts of the url
set url_parts [appc::url::parse {s3://sf02.digitaloceanspaces.com/appc-images/mytest_image:0.zip}]

puts stderr "$url_parts"
