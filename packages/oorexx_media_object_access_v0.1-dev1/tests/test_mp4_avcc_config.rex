/* Canonical MP4 H264 adapter: strict bounded avc1 sample entry / avcC.
 * Metadata-only fixture. No libavformat, codec, native library or media read.
 */
numeric digits 30
avc=x2c('0164001FFFE100046764001F01000268EE')
sampleEntry=box('avc1',copies('00'x,78)||box('avcC',avc))
stsd=box('stsd',x2c('00000000')||u32(1)||sampleEntry)
atom=.SyntheticStsd~new(stsd)
cfg=.MediaMp4AvcConfig~new(atom)
if cfg~sampleDescriptionCount<>1 then call fail 'sample count'
if cfg~nalLengthBytes<>4 then call fail 'NAL width'
if c2x(cfg~annexBPrefix)<>'000000016764001F0000000168EE' then -
  call fail 'SPS/PPS Annex-B prefix'
if atom~bytesRead>512 then call fail 'unbounded MP4 configuration read'
say 'PASS: strict avc1 child boxes, 4-byte NAL lengths, Annex-B SPS/PPS; bytes='atom~bytesRead
exit 0
fail: procedure
  use strict arg why
  say 'FAIL:' why
  exit 1
u32: procedure
  use strict arg number
  return x2c(d2x(number,8))
box: procedure
  use strict arg kind,payload
  return u32(8+payload~length)||kind||payload

::class SyntheticStsd public
::attribute kind get
::attribute length get
::attribute headerBytes get
::attribute bytesRead get
::method init
  expose kind length headerBytes raw bytesRead
  use strict arg blob
  kind='stsd'; length=blob~length; headerBytes=8
  raw=substr(blob,9); bytesRead=0
::method exactBytes
  expose raw bytesRead
  use strict arg offset,n
  if offset<0 | n<0 | offset+n>raw~length then -
    raise syntax 88.900 array('fixture metadata read outside stsd',offset,n)
  bytesRead=bytesRead+n
  return substr(raw,offset+1,n)

::requires '../src/MediaMp4AvcConfig.cls'
