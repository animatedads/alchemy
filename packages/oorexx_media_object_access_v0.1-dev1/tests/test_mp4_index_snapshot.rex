/* End-to-end MediaFile -> mvhd -> tkhd / edts/elst -> sample map.
 * 1 GiB sparse logical source, no compressed mdat read. */
numeric digits 30
z=x2c('00000000')
mvhd=box('mvhd',z||u32(0)||u32(0)||u32(1000)||u32(1000))
tkhd=box('tkhd',z||u32(0)||u32(0)||u32(7)||u32(0))
mdhd=box('mdhd',z||u32(0)||u32(0)||u32(90000)||u32(6000))
hdlr=box('hdlr',z||z||'soun')
stsd=box('stsd',z||u32(1)||u32(8)||'alaw')
stts=box('stts',z||u32(1)||u32(2)||u32(3000))
stsc=box('stsc',z||u32(1)||u32(1)||u32(2)||u32(1))
stsz=box('stsz',z||u32(0)||u32(2)||u32(5)||u32(7))
stco=box('stco',z||u32(1)||u32(1024))
stss=box('stss',z||u32(1)||u32(1))
stbl=box('stbl',stsd||stts||stsc||stsz||stco||stss)
minf=box('minf',stbl)
mdia=box('mdia',mdhd||hdlr||minf)
elst=box('elst',z||u32(2)||u32(89)||u32(4294967295)||x2c('00010000')|| -
  u32(1000)||u32(0)||x2c('00010000'))
edts=box('edts',elst)
trak=box('trak',tkhd||edts||mdia)
moov=box('moov',mvhd||trak)
ftyp=box('ftyp','isom'||u32(0)||'isom')
startMdat=ftyp~length+moov~length
mdatHeader=u32(1073741824-startMdat)||'mdat'
s=.SparseMovieSource~new(ftyp||moov||mdatHeader)
f=.MediaFile~openMp4(s)
call eq 1000,f~movieTimeScale,'movie timebase from mvhd'
call eq 'MOVIE',f~layout,'simple movie layout'
call eq 1,f~trackCount,'track count'
t=f~track(1)
call eq 7,t~trackId,'track ID'
call eq 'soun',t~kind,'handler'
call eq 90000,t~timeScale,'track timescale'
if \t~hasEdits then call fail 'elst not detected'
m=t~mapSamples
call eq 2,m~sampleCount,'mapped samples'
call eq 8010,m~sample(1)~presentationTicks,'movie PTS +89ms'
call eq 0,m~sample(1)~decodeTicks,'DTS stays native'
call eq 1024,m~sample(1)~byteOffset,'compressed offset unchanged'
call eq 1029,m~sample(2)~byteOffset,'sample 2 offset'
call eq 2,t~planTime(11000)~target~ordinal,'track presentation seek plan'
if s~bytesRead>4096 then call fail 'metadata bytes exceeded expected bound'
/* Persist then reload without touching MP4 metadata again. */
manifest=m~exportIndexText
before=s~bytesRead
snapshot=.MediaMp4IndexSnapshot~new(manifest,s,7,90000)
call eq 2,snapshot~sampleCount,'restored count'
call eq 8010,snapshot~sample(1)~presentationTicks,'restored edit list PTS'
call eq 1024,snapshot~sample(1)~byteOffset,'restored physical byte address'
call eq 2,snapshot~planTime(11000)~target~ordinal,'restored random presentation seek'
call eq before,s~bytesRead,'zero source reads for sidecar reload'
restored=t~installIndexText(manifest)
call eq 8010,restored~sample(1)~presentationTicks,'track install persisted sidecar'
call eq 2,t~planTime(11000)~target~ordinal,'track hot seek after restore'
call eq before,s~bytesRead,'no additional MP4 metadata fetch'
say 'PASS: MediaFile movie/track/edit integration, 1 GiB sparse, metadata reads='s~bytesRead
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
box: procedure
 use strict arg kind,payload
 return x2c(d2x(8+payload~length,8))||kind||payload

::class SparseMovieSource subclass MediaByteSource public
::attribute bytesRead get
::method init
  expose bytes bytesRead
  use strict arg header
  bytes=header; bytesRead=0
::method sizeBytes
  return 1073741824
::method sourceIdentity
  return 'fixture:immutable:moov-edts:1gb'
::method readAt
  expose bytes bytesRead
  use strict arg offset,count
  if offset+count>bytes~length then -
    raise syntax 88.900 array('unexpected compressed payload read',offset,count)
  bytesRead=bytesRead+count
  return substr(bytes,offset+1,count)

::requires '../src/MediaByteSource.cls'
::requires '../src/Mp4File.cls'
::requires '../src/Mp4SampleTable.cls'

::requires '../src/Mp4IndexSnapshot.cls'
