/* Decode-order/DTS versus presentation-order/PTS; no mdat reads. */
numeric digits 30
zero=x2c('00000000')
stsd=box('stsd',zero||u32(1)||u32(8)||'avc1')
stts=box('stts',zero||u32(1)||u32(4)||u32(3000))
/* signed CTTS v1: 0, +3000, -3000, 0. PTS: 0,6000,3000,9000 */
ctts=box('ctts',x2c('01000000')||u32(4)||u32(1)||u32(0)||u32(1)||u32(3000)||u32(1)||u32(4294964296)||u32(1)||u32(0))
stsc=box('stsc',zero||u32(1)||u32(1)||u32(2)||u32(1))
stsz=box('stsz',zero||u32(0)||u32(4)||u32(5)||u32(6)||u32(7)||u32(8))
stco=box('stco',zero||u32(2)||u32(128)||u32(200))
stss=box('stss',zero||u32(2)||u32(1)||u32(4))
metadata=box('stbl',stsd||stts||ctts||stsc||stsz||stco||stss)
src=.Mp4FixtureSource~new(metadata,1024)
atoms=.Mp4AtomScanner~scan(src,0,src~metadataBytes)
stbl=atoms[1]
map=.MediaMp4SampleTable~new(stbl,7,90000)
call eq 4,map~sampleCount,'sample count'
call eq 'CANDIDATE_ONLY',map~indexStatus,'candidate status'
call eq 128,map~sample(1)~byteOffset,'first offset'
call eq 133,map~sample(2)~byteOffset,'second offset'
call eq 200,map~sample(3)~byteOffset,'third offset'
call eq 207,map~sample(4)~byteOffset,'fourth offset'
call eq 5,map~sample(1)~sizeBytes,'variable bitrate sample size'
call eq 8,map~sample(4)~sizeBytes,'variable bitrate final size'
call eq 6000,map~sample(2)~presentationTicks,'positive composition shift'
call eq 3000,map~sample(3)~presentationTicks,'negative composition shift'
call eq 6000,map~sample(3)~decodeTicks,'decode timestamp distinct'
call eq 3,map~atOrAfter(2999)~ordinal,'presentation index sorted outside DTS order'
call eq 2,map~atOrAfter(3001)~ordinal,'next presentation sample'
plan=map~planTime(3000)
call eq 3,plan~target~ordinal,'target frame by presentation time'
call eq 1,plan~anchor~ordinal,'sync anchor in decode order'
call eq 'UNVERIFIED_DECODER_PREROLL',plan~status,'no false exact seek'
ranges=map~rangesForPlan(plan,64,10)
call eq 2,ranges~items,'interleaved GOP requires two physical ranges'
call eq 128,ranges[1]~offset,'first span starts at sync sample'
call eq 11,ranges[1]~length,'adjacent samples merged into range'
call eq 200,ranges[2]~offset,'second span skips interleaved data'
call eq 7,ranges[2]~length,'second span excludes unrelated data'
if plan~canDecodeExactly then call fail 'exact decoder proof fabricated'
if map~planTime(10000)<>.nil then call fail 'EOF seek not rejected'
if src~bytesRequested>4096 then call fail 'metadata read budget exceeded'
say 'PASS: sample offsets, VBR, signed CTTS, PTS sorting, sync candidate; metadata bytes='src~bytesRequested
exit 0
eq: procedure
  use strict arg expected,actual,label
  if expected<>actual then call fail label||' expected='||expected||' actual='||actual
  return
fail: procedure
  use strict arg reason
  say 'FAIL: 'reason
  exit 1
u32: procedure
  use strict arg n
  return x2c(d2x(n,8))
box: procedure
  use strict arg kind,payload
  return x2c(d2x(8+payload~length,8))||kind||payload
::class Mp4FixtureSource subclass MediaByteSource public
::attribute metadataBytes get
::attribute bytesRequested get
::method init
  expose bytes size metadataBytes bytesRequested
  use strict arg sourceText,declaredSize
  bytes=sourceText; metadataBytes=bytes~length; size=declaredSize
  bytesRequested=0
::method sourceIdentity
  return 'test:synthetic-mp4'
::method sizeBytes
  expose size
  return size
::method readAt
  expose bytes metadataBytes bytesRequested
  use strict arg offset,count
  bytesRequested+=count
  if offset<0 | count<0 | offset+count>metadataBytes then -
    raise syntax 88.900 array('metadata parser attempted media payload read',offset,count)
  return substr(bytes,offset+1,count)
::requires '../src/MediaByteSource.cls'
::requires '../src/Mp4File.cls'
::requires '../src/Mp4SampleTable.cls'
