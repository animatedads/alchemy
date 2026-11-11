/* ooRexx 5.3 TS parser invariants and content-sniff regression.
 * Execute against supplied resident MKV-named MPEG-TS recording.
 * The scan is explicitly local; never run it across Storage Fabric.
 */

parse arg filename
if filename='' then do
  say 'Usage: rexx test_ts_contract.rex /resident/file/stream1_*.mkv'
  exit 2
end
if .MediaTsWire~pts(x2c("210007D861"))<>126000 then call fail "90kHz integer PTS decode"
source=.TestLocalSource~new(filename,'test|resident|immutable-v1')
if .MediaFileProbe~detect(source)<>'MPEG_TS_188' then call fail 'extension-independent sniff'
file=.MediaFileProbe~open(source)
if file~timeScale<>90000 | file~videoCodec<>'H264_ANNEXB' then call fail 'TS PMT codec/timebase'
if file~videoPid<0 then call fail 'missing video PID'
bytes=source~sizeBytes
say 'MPEG-TS FILE' filename 'bytes' bytes 'pid' file~videoPid
found=file~buildIndexLocal(.true,bytes)
if found<1 then call fail 'no IDR candidate points indexed'
manifest=file~exportIndexText
next=.MediaFileProbe~open(source)
read=next~loadIndexText(manifest)
if read<>found then call fail 'index count differs after restore'
plan=next~planTime(9999999999)
if plan==.nil | plan~status<>'UNVERIFIED_DECODER_PREROLL' then call fail 'candidate-only hot-seek contract'
range=next~planBoundedRange(9999999999,65536)
if range==.nil | range['bytes']>65536 then call fail 'unbounded seek transfer'
/* SeekTime must never claim exact decoded output before native verification. */
first=.MediaTsWire~packet(source~readAt(0,188))
if first['pid']<0 then call fail 'invalid first TS packet'
say 'PASS: resident TS index and sidecar round trip, candidate anchors:' found
exit 0
fail: procedure
  use arg why
  say 'FAIL:' why
  exit 1

::class TestLocalSource subclass MediaByteSource public
::method init
  expose path size identity
  use strict arg fn,strongIdentity
  path=fn; identity=strongIdentity
  size=stream(path,'C','QUERY SIZE')
  if \datatype(size,'W') then raise syntax 88.900 array('file not available',path)
::method sizeBytes
  expose size
  return size
::method sourceIdentity
  expose identity
  return identity
::method readAt
  expose path size
  use strict arg offset,count
  if offset<0 | count<0 | offset+count>size | count>65536 then -
    raise syntax 88.900 array('local test range invalid',offset,count)
  if count=0 then return ''
  data=charin(path,offset+1,count)
  if data~length<>count then raise syntax 88.900 array('short read',offset,count)
  return data

::requires '../src/MediaByteSource.cls'
::requires '../src/Mp4File.cls'
::requires '../src/MediaSeekIndex.cls'
::requires '../src/MediaTsFile.cls'
::requires '../src/MediaFileProbe.cls'
