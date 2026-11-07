/* Validate 64-bit chunk offsets across 4 GiB without accessing payload. */
numeric digits 30
z=x2c('00000000')
stsd=box('stsd',z||u32(1)||u32(8)||'avc1')
stts=box('stts',z||u32(1)||u32(1)||u32(3000))
stsc=box('stsc',z||u32(1)||u32(1)||u32(1)||u32(1))
stsz=box('stsz',z||u32(4)||u32(1))
co64=box('co64',z||u32(1)||u64(4294967300))
stss=box('stss',z||u32(1)||u32(1))
metadata=box('stbl',stsd||stts||stsc||stsz||co64||stss)
source=.Mp4LargeSource~new(metadata)
atoms=.Mp4AtomScanner~scan(source,0,source~metadataBytes)
atom=atoms[1]
table=.MediaMp4SampleTable~new(atom,1,90000)
if table~sample(1)~byteOffset<>4294967300 then do
  say 'FAIL co64 byte offset:' table~sample(1)~byteOffset
  exit 1
end
if table~sample(1)~sizeBytes<>4 then exit 1
plan=table~planTime(0)
if plan~anchor~byteOffset<>4294967300 then exit 1
say 'PASS: co64 >4 GiB sample address without media transfer'
exit 0
u32: procedure
  use strict arg n
  return x2c(d2x(n,8))
u64: procedure
  use strict arg n
  return x2c(d2x(n,16))
box: procedure
  use strict arg kind,payload
  return x2c(d2x(8+payload~length,8))||kind||payload
::class Mp4LargeSource subclass MediaByteSource public
::attribute metadataBytes get
::method init
  expose metadata metadataBytes
  use strict arg bytes
  metadata=bytes; metadataBytes=bytes~length
::method sourceIdentity
  return 'test:co64'
::method sizeBytes
  return 8589934592
::method readAt
  expose metadata metadataBytes
  use strict arg offset,count
  if offset+count>metadataBytes then raise syntax 88.900 array('attempted to fetch media payload')
  return substr(metadata,offset+1,count)
::requires '../src/MediaByteSource.cls'
::requires '../src/Mp4File.cls'
::requires '../src/Mp4SampleTable.cls'
