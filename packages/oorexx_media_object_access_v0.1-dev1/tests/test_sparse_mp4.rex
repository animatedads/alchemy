/* Synthetic 1 GiB media payload: prove metadata inspection does not walk it.
 * mp4 layout: ftyp(24), mdat(1 GiB + 8), moov(16 containing trak(8)). */

source=.SparseMp4Source~new
file=.MediaFile~openMp4(source)
if file~sizeBytes<>1073741872 then call fail 'wrong logical file size'
if file~layout<>'MOVIE' then call fail 'movie not found at end of 1 GiB payload'
if file~trackCount<>1 then call fail 'track not discovered'
if file~track(1)~indexStatus<>'NOT_INDEXED' then call fail 'unqualified seek misrepresented'
if source~bytesRequested>80 then call fail 'excessive transfer during metadata scan'
if source~calls>10 then call fail 'excessive byte-range requests'
say 'PASS: 1 GiB MP4 tail metadata located with' source~bytesRequested 'bytes'
exit 0

::routine fail
  use strict arg reason
  say 'FAIL:' reason
  exit 1

::class SparseMp4Source subclass MediaByteSource public
::attribute bytesRequested get
::attribute calls get
::method init
  expose bytesRequested calls
  bytesRequested=0; calls=0
::method sizeBytes
  return 1073741872
::method sourceIdentity
  return 'TEST|sparse1g|immutable'
::method readAt
  expose bytesRequested calls
  use strict arg at,count
  bytesRequested+=count; calls+=1
  if at=0 & count=8 then return x2c('0000001866747970')
  if at=24 & count=8 then return x2c('400000086D646174')
  if at=1073741856 & count=8 then return x2c('000000106D6F6F76')
  if at=1073741864 & count=8 then return x2c('000000087472616B')
  if at>=32 & at<1073741856 then call fail 'attempted to read mdat payload'
  call fail 'unexpected source range '||at||'+'||count
::requires '../src/Mp4File.cls'
::requires '../src/MediaByteSource.cls'
