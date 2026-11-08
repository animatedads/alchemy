/* Native ooRexx real MPEG-TS hot-seek evidence. No Python, FFmpeg or OpenCV.
 * First indexing pass must be explicitly resident-authorized. Subsequent
 * time-to-byte queries reuse the compact sidecar and consume zero I/O.
 */
parse arg filename outputDir
if filename='' then do
 say 'ERROR: supply resident transport stream path'
 exit 2
end
if outputDir='' then outputDir='.'
local=.EvidenceByteSource~new(filename)
file=.MediaFileProbe~open(local)
if file~timeScale<>90000 then do
 say 'FAIL timeScale'
 exit 3
end
if file~videoCodec<>'H264_ANNEXB' then do
 say 'FAIL codec'
 exit 3
end
say 'INPUT' filename
say 'SIZE' local~sizeBytes 'PID' file~videoPid 'CODEC' file~videoCodec
found=file~buildIndexLocal(.true,local~sizeBytes)
if found<1 then do
 say 'FAIL no anchors'
 exit 4
end
readLocal=local~readBytes
manifest=file~exportIndexText
say 'BUILD index-points='found 'read-bytes='readLocal 'sidecar-bytes='manifest~length
base=lastpos('/',filename)
if base=0 then base=0
name=substr(filename,base+1)
out=outputDir||'/'||name||'.mtsidx'
call lineout out,manifest
call lineout out
local2=.EvidenceByteSource~new(filename)
restored=.MediaFileProbe~open(local2)
readHead=local2~readBytes
if restored~loadIndexText(manifest)<>found then do
 say 'FAIL restore count'
 exit 5
end
if local2~readBytes<>readHead then do
 say 'FAIL restore reads source unexpectedly'
 exit 5
end
last=restored~planTime(9999999999)
if last==.nil then do
 say 'FAIL last anchor'
 exit 5
end
lastTicks=last~anchor~presentationTicks
say 'INDEX final ticks='lastTicks 'offset='last~byteOffset 'duration-s='format(lastTicks/90000,,3)
queries=.array~of(0,5,10,15,20,30,40,45,50)
checks=0
do n over queries
  target=lastTicks-n*90000
  if target<0 then iterate
  plan=restored~planTime(target)
  if plan==.nil then iterate
  range=restored~planBoundedRange(target,65536)
  if range['offset']//188<>0 | range['bytes']>65536 | -
     range['offset']+range['bytes']>local2~sizeBytes then do
   say 'FAIL range for time' target
   exit 5
  end
  if plan~status<>'UNVERIFIED_DECODER_PREROLL' then do
   say 'FAIL decoder trust'
   exit 5
  end
  checks=checks+1
  say 'HOT-SEEK target='target 'anchor='plan~anchor~presentationTicks -
      'offset='range['offset'] 'bytes='range['bytes']
end
if checks<4 then do
 say 'FAIL insufficient hot-seek queries' checks
 exit 5
end
if local2~readBytes<>readHead then do
 say 'FAIL seek performed source reads' local2~readBytes-readHead
 exit 5
end
say 'PASS native TS persisted hot-seek checks='checks 'hot-path source bytes=0' -
    'reopen metadata bytes='readHead
exit 0

::class EvidenceByteSource subclass MediaByteSource public
::attribute readBytes get
::method init
  expose path identity size readBytes
  use strict arg filename
  path=filename
  size=stream(filename,'C','QUERY SIZE')
  if \datatype(size,'W') then raise syntax 88.900 array('unavailable source',filename)
  identity='resident:test:'||filename||':'||size
  readBytes=0
::method sizeBytes
  expose size
  return size
::method sourceIdentity
  expose identity
  return identity
::method readAt
  expose path size readBytes
  use strict arg offset,n
  if n<0 | n>65536 | offset<0 | offset+n>size then -
    raise syntax 88.900 array('out of bounded native range',offset,n)
  if n=0 then return ''
  data=charin(path,offset+1,n)
  if data~length<>n then raise syntax 88.900 array('short local read',offset,n)
  readBytes=readBytes+n
  return data

::requires '../src/MediaByteSource.cls'
::requires '../src/MediaSeekIndex.cls'
::requires '../src/MediaTsFile.cls'
::requires '../src/Mp4File.cls'
::requires '../src/MediaFileProbe.cls'

::options digits 30