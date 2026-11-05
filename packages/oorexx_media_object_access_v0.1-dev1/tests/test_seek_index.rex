::requires '../src/MediaSeekIndex.cls'
index=.MediaSeekIndex~new('immutable-1gb-file',7,90000)
index~addAccessPoint(.MediaAccessPoint~new(0,0,4096,1,0))
index~addAccessPoint(.MediaAccessPoint~new(90000,87000,1048576,31,2))
index~addAccessPoint(.MediaAccessPoint~new(180000,177000,2097152,61,2))
index~seal
if index~atOrBefore(179999)~byteOffset<>1048576 then exit 1
if index~atOrBefore(180000)~byteOffset<>2097152 then exit 1
if index~atOrBefore(-1)<>.nil then exit 1
say 'PASS: exact integer timestamp lookup without scan'
exit 0
