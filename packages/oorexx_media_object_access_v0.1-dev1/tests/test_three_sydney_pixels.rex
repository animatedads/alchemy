/* Native ooRexx 5.3 pixel qualification, three independent MPEG-TS sources.
 * No Python/FFmpeg CLI; ooRexx owns demux/PTS, codec provider yields RGB24.
 * First create source-identity-bound index at resident node, then use saved
 * sidecar to jump to 5, 30 and 55 seconds without scanning from start.
 */
parse arg arguments
if arguments='' then do
 say 'USAGE rexx test_three_sydney_pixels.rex /path/to/stream1 /path/to/stream2 /path/to/stream3 [outputDir]'
 exit 2
end
files=.array~new
parse var arguments a b c outputDir
files~append(a);files~append(b);files~append(c)
if outputDir='' then outputDir='.'
anchors=.array~new
allPass=0
say 'MOONSAULT MEDIA H264 NATIVE PIXEL TEST - ooRexx 5.3 r13196'
do camera=1 to 3
 filename=files[camera]
 local=.LocalVideoSource~new(filename)
 ts=.MediaTsFile~new(local)
 if ts~videoPid<>256 | ts~videoCodec<>'H264_ANNEXB' then call fail 'wrong PMT codec for stream' camera
 points=ts~buildIndexLocal(.true,local~sizeBytes)
 if points<>12 then call fail 'expected twelve IDR candidates' camera points
 manifest=ts~exportIndexText
 receiver=.LocalVideoSource~new(filename)
 loaded=.MediaTsFile~new(receiver)
 baseRead=receiver~readBytes
 if loaded~loadIndexText(manifest)<>points then call fail 'TS index restore' camera
 if receiver~readBytes<>baseRead then call fail 'restored sidecar incorrectly read source'
 decoder=.MediaTsVideoFrames~new(loaded)
 do seconds over .array~of(55,5,30)
   ticks=seconds*90000
   before=receiver~readBytes
   image=decoder~frameAt(ticks,1048576,240)
   transfer=receiver~readBytes-before
   if image==.nil then call fail 'no image at' camera seconds
   if image~presentationTicks<ticks | image~presentationTicks>=ticks+9000 then -
     call fail 'wrong decoded frame PTS' camera seconds image~presentationTicks
   if image~pixels~length<>image~width*image~height*3 then call fail 'RGB24 buffer size'
   if transfer<188 | transfer>1048576 then call fail 'source transfer outside 1MiB budget' camera seconds transfer
   center=image~pixelAt(image~width % 2,image~height % 2)
   say 'PASS CAMERA' camera 'S' seconds 'RGB' image~width 'x' image~height -
       'PTS' image~presentationTicks 'RANGE_BYTES' transfer 'CENTER_RGB' center[1] center[2] center[3]
   allPass+=1
   if seconds=30 then do
      path=outputDir||'/sydney_camera'||camera||'_t30s.ppm'
      ignore=image~savePpm(path)
      say 'PIXEL_ARTIFACT' path
   end
 end
 say 'PASS CAMERA' camera 'SEEK_INDEX' points 'SIDECAR_BYTES' manifest~length -
    'REOPEN_METADATA_BYTES' baseRead
end
say 'PASS NATIVE ooRexx RGB24 decoded frame hot-seeks:' allPass
exit 0
fail: procedure
 use arg message
 say 'FAIL' message
 exit 2
::class LocalVideoSource subclass MediaByteSource public
::attribute readBytes get
::method init
 expose filename size readBytes identity
 use strict arg path
 filename=path
 size=stream(filename,'C','QUERY SIZE')
 if \datatype(size,'W') then raise syntax 88.900 array('cannot open source',path)
 /* The test fixture file is immutable; production must use Storage Fabric IDs. */
 identity=filename||'|'||size||'|TEST_IMMUTABLE'
 readBytes=0
::method sizeBytes
 expose size
 return size
::method sourceIdentity
 expose identity
 return identity
::method readAt
 expose filename size readBytes
 use strict arg offset,count
 if \datatype(offset,'W') | \datatype(count,'W') | offset<0 | count<0 | -
    count>65536 | offset+count>size then raise syntax 88.900 array('unbounded source read',offset,count)
 data=charin(filename,offset+1,count)
 if data~length<>count then raise syntax 88.900 array('short source read',offset,count)
 readBytes+=count
 return data
::requires '../src/MediaByteSource.cls'
::requires '../src/MediaSeekIndex.cls'
::requires '../src/MediaTsFile.cls'
::requires '../src/MediaH264Frames.cls'
::requires '../src/MediaTsVideoFrames.cls'