/* Real-camera edit-list timeline regression without MP4 payload transfer.
 * A two-entry edit has 89 ms of empty movie time followed by the samples.
 * Movie timescale 1000, track timebase 90000 -> 8010 ticks. */
numeric digits 30
z=x2c('00000000')
stsd=box('stsd',z||u32(1)||u32(8)||'alaw')
stts=box('stts',z||u32(1)||u32(4)||u32(3000))
stsc=box('stsc',z||u32(1)||u32(1)||u32(4)||u32(1))
stsz=box('stsz',z||u32(0)||u32(4)||u32(5)||u32(6)||u32(7)||u32(8))
stco=box('stco',z||u32(1)||u32(1000000000))
stss=box('stss',z||u32(1)||u32(1))
stbl=box('stbl',stsd||stts||stsc||stsz||stco||stss)
elst=box('elst',z||u32(2)||u32(89)||u32(4294967295)||x2c('00010000')|| -
                   u32(5000)||u32(0)||x2c('00010000'))
src=.ElstSyntheticSource~new(stbl||elst)
boxes=.Mp4AtomScanner~scan(src,0,src~metadataBytes)
t=.MediaMp4SampleTable~new(boxes[1],7,90000,boxes[2],1000)
call eq 4,t~sampleCount,'unmodified raw sample count'
call eq 4,t~presentationCount,'presented sample count'
call eq 0,t~sample(1)~decodeTicks,'media DTS preserved'
call eq 0,t~sample(1)~mediaPresentationTicks,'raw media PTS preserved'
call eq 8010,t~sample(1)~presentationTicks,'empty edit moves first frame +89ms'
call eq 11010,t~sample(2)~presentationTicks,'second sample shifted'
call eq 1000000000,t~sample(1)~byteOffset,'sample byte offset unchanged'
call eq 1000000005,t~sample(2)~byteOffset,'VBR offsets unchanged'
call eq 2,t~atOrAfter(11000)~ordinal,'movie timeline find sample'
plan=t~planTime(8010)
call eq 1,plan~anchor~ordinal,'GOP anchor unchanged'
ranges=t~rangesForPlan(plan,100,4)
call eq 1,ranges~items,'packed samples remain contiguous'
call eq 5,ranges[1]~length,'sample size retained'
if src~bytesRead>8192 then call fail 'unexpected metadata bytes'

/* Trim first sample using nonempty media-time edit, zero movie start. */
elstTrim=box('elst',z||u32(1)||u32(1000)||u32(3000)||x2c('00010000'))
src2=.ElstSyntheticSource~new(stbl||elstTrim)
boxes2=.Mp4AtomScanner~scan(src2,0,src2~metadataBytes)
trim=.MediaMp4SampleTable~new(boxes2[1],7,90000,boxes2[2],1000)
call eq 3,trim~presentationCount,'one sample excluded by trim edit'
call eq 2,trim~atOrAfter(0)~ordinal,'trimmed movie starts at second sample'
call eq 0,trim~sample(2)~presentationTicks,'media sample 2 remapped to movie zero'
call eq 3000,trim~sample(2)~mediaPresentationTicks,'media PTS stays unchanged'
if trim~sample(1)~presentationVisible then call fail 'trimmed sample still indexed'

/* Extended 64-bit edit list with a leading 89 ms empty edit. */
elst64=box('elst',x2c('01000000')||u32(2)||u64(89)||u64(18446744073709551615)||x2c('00010000')|| -
  u64(5000)||u64(0)||x2c('00010000'))
src3=.ElstSyntheticSource~new(stbl||elst64)
boxes3=.Mp4AtomScanner~scan(src3,0,src3~metadataBytes)
extended=.MediaMp4SampleTable~new(boxes3[1],7,90000,boxes3[2],1000)
call eq 8010,extended~sample(1)~presentationTicks,'version 1 signed64 empty edit'

say 'PASS: elst v0/v1 +89ms, trim, intact media PTS/DTS/offsets; only metadata read'
exit 0
eq: procedure
  use strict arg expected,actual,label
  if expected<>actual then call fail label||' expected='||expected||' actual='||actual
  return
fail: procedure
  use strict arg message
  say 'FAIL:' message
  exit 1
u32: procedure
  use strict arg number
  return x2c(d2x(number,8))
u64: procedure
  use strict arg number
  numeric digits 30
  return x2c(d2x(number,16))
box: procedure
  use strict arg kind,payload
  return x2c(d2x(8+payload~length,8))||kind||payload

::class ElstSyntheticSource subclass MediaByteSource public
::attribute bytesRead get
::attribute metadataBytes get
::method init
  expose data metadataBytes bytesRead
  use strict arg text
  data=text; metadataBytes=text~length
  bytesRead=0
::method sizeBytes
  return 1073741824
::method sourceIdentity
  return 'fixture:immutable:elst-v1'
::method readAt
  expose data metadataBytes bytesRead
  use strict arg offset,count
  if offset+count>metadataBytes then -
    raise syntax 88.900 array('attempted media payload fetch',offset,count)
  bytesRead=bytesRead+count
  return substr(data,offset+1,count)

::requires '../src/MediaByteSource.cls'
::requires '../src/Mp4File.cls'
::requires '../src/Mp4SampleTable.cls'
