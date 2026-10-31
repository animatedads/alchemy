/* Tombstone Sydney / Vision V5V + Camera Behaviour consumer, v0.15.
   Uses first-party VisionSurface/V5VTemporalCodec + CameraLumaTemporalTrackSet
   and CameraLumaPrimitiveQuality; no OpenCV, no second tracking implementation.
   Source adapter: native FFmpeg emitted fixed-size RGB24; never identifies ships.
   All output is OBSERVED_UNTESTED.  No geographic/identity promotion.
*/
numeric digits 18
parse arg inputFile outputFile sourceHash expectedFrames
if expectedFrames='' then expectedFrames=0
if \datatype(expectedFrames,'W') then call bad 'expected frame count must be integer'
if expectedFrames<0 then call bad 'negative frame count'
if inputFile='' | outputFile='' then call bad 'USAGE input.rgb output.psv mp4_sha256'
if inputFile=outputFile then call bad 'input equals output'
if length(sourceHash)<>64 then call bad 'source SHA256 required'
if verify(sourceHash,'0123456789abcdef')<>0 then call bad 'invalid source SHA256'
if stream(inputFile,'c','query exists')='' then call bad 'no input file'
w=80;h=45;pix=w*h;frameBytes=pix*3
r=.array~new(26);g=.array~new(26);b=.array~new(26)
palette='150,180,214 120,157,207 100,135,185 175,197,222 191,202,217 88,124,175' ,
 '34,67,108 52,84,124 71,105,137 87,121,151 107,140,162 40,92,133 57,104,142 75,128,160' ,
 '229,185,77 212,173,71 245,211,122 192,150,54 225,202,112 174,133,63' ,
 '144,145,143 181,171,155 206,192,166 112,110,103 82,102,79 62,70,72'
do k=1 to 26
 parse var palette colours
 parse var colours wordColour ' ' palette
 parse var wordColour cr ',' cg ',' cb
 r[k]=cr;g[k]=cg;b[k]=cb
end
model=.VisionColourModel~new(r,g,b)
lookup=.array~new(4096)
do ri=0 to 15
 do gi=0 to 15
  do bi=0 to 15
   red=ri*16+8;green=gi*16+8;blue=bi*16+8
   best=-1;minDist=-1
   do q=1 to 26
    dr=red-r[q];dg=green-g[q];db=blue-b[q]
    dist=dr*dr+dg*dg+db*db
    if minDist=-1 | dist<minDist then do
     minDist=dist;best=q-1
    end
   end
   lookup[ri*256+gi*16+bi+1]=best
  end
 end
end
source='sha256:'||sourceHash
encoder=.V5VTemporalCodec~new(.V5VCodecPolicy~new(10))
decoder=.V5VTemporalCodec~new(.V5VCodecPolicy~new(10))
extractor=.VisionChangeRegionExtractor~new(8,3)
movement=.CameraLumaTemporalTrackSet~new(source,w,h,4)
/* Source adapter admits all decoded frames; optional count is an integrity check. */
call stream inputFile,'c','open read'
rows=.array~new
previous=.nil
keyframes=0;deltaFrames=0;frame=0;changedTotal=0
ferryPaletteTotal=0
do forever
 rgb=charin(inputFile,,frameBytes)
 if length(rgb)=0 then leave
 if length(rgb)<>frameBytes then call bad 'truncated frame'
 if frame>=5000 then call bad 'frame bound exceeded'
 s=.VisionSurface~new(w,h,5,26,model)
 s~sourceRef=source;s~timestamp=frame/5;s~generation=frame
 yellows=0
 do i=0 to pix-1
  off=i*3
  cr=c2d(substr(rgb,off+1,1));cg=c2d(substr(rgb,off+2,1));cb=c2d(substr(rgb,off+3,1))
  key=(cr%16)*256+(cg%16)*16+(cb%16)+1
  value=lookup[key]
  s~packed~put(i,value)
  if value>=14 & value<=19 then yellows=yellows+1
 end
 record=encoder~encodeSurface(s)
 if record~recordType='KEYFRAME' then keyframes=keyframes+1
 else deltaFrames=deltaFrames+1
 back=decoder~decodeRecord(record)
 if back~packedBytes\==s~packedBytes then call bad 'V5V reconstruction changed surface'
 if back~sourceRef\==source then call bad 'V5V source ref changed'
 if back~timestamp<>frame/5 then call bad 'V5V timestamp changed'
 changes=0;regions=0;motionRegions=0
 if previous\==.nil then do
  /* Use reconstructed surfaces so keyframe cadence does not hide movement. */
  visualDelta=.VisionSurfaceDelta~new(previous,back)
  changes=visualDelta~changedCount
  reg=extractor~extract(visualDelta)
  regions=reg~items
  deltas=.array~new(pix)
  do i=0 to pix-1
   deltas[i+1]=visualDelta~changedMask~at(i)
  end
  /* Canonical Camera Behaviour temporal connected regions / association. */
  motionRegions=movement~observeComparison(deltas,1,frame)
 end
 previous=back
 changedTotal=changedTotal+changes
 ferryPaletteTotal=ferryPaletteTotal+yellows
 rows~append(frame||'|'||record~recordType||'|'||changes||'|'||regions||'|'||motionRegions||'|'||yellows||'|1|'||source||'|OBSERVED_UNTESTED')
 frame=frame+1
end
call stream inputFile,'c','close'
if frame<2 then call bad 'insufficient source frames'
if expectedFrames>0 then if frame<>expectedFrames then call bad 'declared frame count mismatch'
expectedKeys=((frame-1)%10)+1
if keyframes<>expectedKeys | deltaFrames<>frame-expectedKeys then call bad 'incorrect keyframe cadence'
/* Apply existing Camera Behaviour movement quality gates, not invented labels. */
qualities=.CameraLumaBehaviourBridge~quality(movement,w,h,3,4)
if qualities~totalCount<>movement~trackCount then call bad 'movement/quality mismatch'
call stream outputFile,'c','open write replace'
call lineout outputFile,'frame|v5v_record|changed_cells|vision_regions|camera_regions|palette14_19_cells|roundtrip_exact|source_ref|evidence_state'
do row over rows
 call lineout outputFile,row
end
call stream outputFile,'c','close'
say 'SYDNEY V5V CAMERA MOVEMENT PASS frames='frame 'keyframes='keyframes 'deltas='deltaFrames
say 'VISION_CHANGED_CELLS='changedTotal 'CAMERA_TRACKS='movement~trackCount 'PERSISTENT='movement~persistentTrackCount
say 'CAMERA_QUALITY_ADMITTED='qualities~admittedCount 'REJECTED='qualities~rejectedCount 'PALETTE_14_19='ferryPaletteTotal
say 'IMPORTANT: colour palette cells, change regions and motion tracks are NOT ferry identities.'
exit 0
bad: procedure
 parse arg reason
 say 'SYDNEY V5V CAMERA MOVEMENT FAIL:'reason
 exit 2
::requires 'V5VCodec.cls'
::requires 'CameraLumaBehaviourBridge.cls'
