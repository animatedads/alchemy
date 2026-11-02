/* Full-native-cadence ooRexx V5V Sydney frames to SLAM candidate node/edge series.
   Each decoded source frame participates (no fps=5 filter). Source PTS via
   ffprobe input; FFmpeg only decodes/crops/downsamples RGB, not motion logic.
   V5V KEYFRAME payload = packed VisionSurface; DELTA payload = packed
   VisionSurfaceDelta mask + changed values, with off/length TSV index.
   Motion-only water mask counts changes but NEVER edits V5V source.
   No SLAM SQL mutation and no implicit TESTED/identity promotion.
 */
numeric digits 22
parse arg inputFile ptsFile maskFile outRoot sourceHash maxFrames
if maxFrames='' then maxFrames=0
if inputFile='' | ptsFile='' | maskFile='' | outRoot='' then call bad 'missing input'
if length(sourceHash)<>64 then call bad 'source sha256 missing'
if verify(sourceHash,'0123456789abcdef')<>0 then call bad 'source sha256 bad'
if \datatype(maxFrames,'W') then call bad 'maxFrames must be whole'
if maxFrames<0 then call bad 'maxFrames negative'
w=80;h=45;count=3600;bytesPerFrame=count*3
left=.array~new(h);right=.array~new(h)
if stream(maskFile,'c','query exists')='' then call bad 'mask absent'
call stream maskFile,'c','open read'
if linein(maskFile)\=='row|first_x|last_x|authority' then call bad 'mask header'
do i=0 to h-1
 row=linein(maskFile)
 parse var row y '|' xl '|' xr '|' authority
 if \datatype(y,'W') | \datatype(xl,'W') | \datatype(xr,'W') then call bad 'mask noninteger'
 if y<>i | xl<0 | xl>80 | xr< -1 | xr>=80 then call bad 'mask bounds'
 if authority\=='PROVISIONAL_WATER_MOVEMENT_ONLY' then call bad 'mask authority'
 left[i+1]=xl;right[i+1]=xr
end
if lines(maskFile)>0 then call bad 'extra mask rows'
call stream maskFile,'c','close'
colours='150,180,214 120,157,207 100,135,185 175,197,222 191,202,217 88,124,175' ,
 '34,67,108 52,84,124 71,105,137 87,121,151 107,140,162 40,92,133 57,104,142 75,128,160' ,
 '229,185,77 212,173,71 245,211,122 192,150,54 225,202,112 174,133,63' ,
 '144,145,143 181,171,155 206,192,166 112,110,103 82,102,79 62,70,72'
r=.array~new(26);g=.array~new(26);b=.array~new(26)
do i=1 to 26
 rgb=word(colours,i)
 parse var rgb rr ',' gg ',' bb
 r[i]=rr;g[i]=gg;b[i]=bb
end
model=.VisionColourModel~new(r,g,b)
lookup=.array~new(4096)
do ri=0 to 15
 do gi=0 to 15
  do bi=0 to 15
   vr=ri*16+8;vg=gi*16+8;vb=bi*16+8
   nearest=0;minDist=-1
   do q=1 to 26
    dr=vr-r[q];dg=vg-g[q];db=vb-b[q]
    d2=dr*dr+dg*dg+db*db
    if minDist=-1 | d2<minDist then do
     minDist=d2;nearest=q-1
    end
   end
   lookup[ri*256+gi*16+bi+1]=nearest
  end
 end
end
encoder=.V5VTemporalCodec~new(.V5VCodecPolicy~new(30))
decoder=.V5VTemporalCodec~new(.V5VCodecPolicy~new(30))
source='sha256:'||sourceHash
call stream inputFile,'c','open read'
call stream ptsFile,'c','open read'
if stream(inputFile,'c','query exists')='' then call bad 'raw file absent'
if stream(ptsFile,'c','query exists')='' then call bad 'PTS file absent'
nodeFile=outRoot||'.nodes.psv';edgeFile=outRoot||'.edges.psv';v5bFile=outRoot||'.v5b'
call stream nodeFile,'c','open write replace'
call lineout nodeFile,'node_id|frame_index|timestamp_seconds|v5v_record|changed_cells|water_changed|excluded_changed|payload_offset|payload_bytes|source_ref|evidence_state'
call stream edgeFile,'c','open write replace'
call lineout edgeFile,'from_id|to_id|dt_seconds|relation|evidence_state'
/* No masked pixel is removed from this V5V serialized stream. */
call charout v5bFile,'',1
previous=.nil;previousId='';previousTime=.nil
frame=0;offset=0;exact=0;waterSum=0;blockedSum=0;keyframes=0;deltas=0;payloadTotal=0
startWall=time('R')
do forever
 if maxFrames>0 then if frame>=maxFrames then leave
 raw=charin(inputFile,,bytesPerFrame)
 if length(raw)=0 then leave
 if length(raw)<>bytesPerFrame then call bad 'short rgb frame'
 if lines(ptsFile)=0 then call bad 'source PTS exhausted'
 timestamp=linein(ptsFile)
 if \datatype(timestamp,'N') then call bad 'nonnumeric PTS'
 if previousTime\==.nil then if timestamp<=previousTime then call bad 'PTS not increasing'
 surface=.VisionSurface~new(w,h,5,26,model)
 surface~sourceRef=source
 surface~timestamp=timestamp
 surface~generation=frame
 do i=0 to count-1
  off=i*3
  pr=c2d(substr(raw,off+1,1));pg=c2d(substr(raw,off+2,1));pb=c2d(substr(raw,off+3,1))
  address=(pr%16)*256+(pg%16)*16+(pb%16)+1
  surface~packed~put(i,lookup[address])
 end
 record=encoder~encodeSurface(surface)
 reconstructed=decoder~decodeRecord(record)
 if reconstructed~packedBytes\==surface~packedBytes then call bad 'V5V exactness failed'
 if reconstructed~timestamp<>timestamp then call bad 'V5V timestamp failed'
 if reconstructed~sourceRef\==source then call bad 'V5V source provenance failed'
 exact=exact+1
 changed=0;inside=0;excluded=0
 if previous\==.nil then do
  do i=0 to count-1
   if previous~packed~at(i)<>reconstructed~packed~at(i) then do
    changed=changed+1
    x=i//w;y=i%w
    if x>=left[y+1] & x<=right[y+1] then inside=inside+1
    else excluded=excluded+1
   end
  end
 end
 if changed<>inside+excluded then call bad 'mask changed-cell conservation failed'
 waterSum=waterSum+inside;blockedSum=blockedSum+excluded
 if record~recordType='KEYFRAME' then do
  payload=record~payload~packedBytes
  keyframes=keyframes+1
 end
 else if record~recordType='DELTA' then do
  delta=record~payload
  payload=delta~changedMask~packedBytes||delta~changedValues~packedBytes
  deltas=deltas+1
 end
 else call bad 'unknown V5V record type'
 size=length(payload)
 if size<1 then call bad 'empty V5V record'
 call charout v5bFile,payload
 payloadTotal=payloadTotal+size
 id='SF.'||substr(sourceHash,1,16)||'.'||right('000000'||frame,6)
 call lineout nodeFile,id||'|'||frame||'|'||timestamp||'|'||record~recordType||'|'||changed||'|'||inside||'|'||excluded||'|'||offset||'|'||size||'|'||source||'|OBSERVED_UNTESTED'
 if previousId<>'' then do
  dt=timestamp-previousTime
  call lineout edgeFile,previousId||'|'||id||'|'||dt||'|NEXT_SOURCE_FRAME|OBSERVED_UNTESTED'
 end
 previous=reconstructed;previousId=id;previousTime=timestamp
 offset=offset+size;frame=frame+1
 if frame//100=0 then say 'SOURCE_FRAME_PROGRESS frames='frame 'seconds_elapsed='time('E') 'water_changes='waterSum 'blocked_changes='blockedSum
end
call stream inputFile,'c','close'
call stream ptsFile,'c','close'
call stream nodeFile,'c','close'
call stream edgeFile,'c','close'
call stream v5bFile,'c','close'
if maxFrames=0 then if lines(ptsFile)>0 then call bad 'input ends before PTS'
if frame=0 then call bad 'no video frames'
if keyframes+deltas<>frame then call bad 'V5V frame conservation failed'
say 'FULL_SOURCE_V5V PASS frames='frame 'exact='exact 'keyframes='keyframes 'deltas='deltas 'water_changed='waterSum 'excluded_changed='blockedSum 'v5b_bytes='payloadTotal
say 'GRAPH_STATE=OBSERVED_UNTESTED (CANDIDATE NODES/EDGES ONLY; no SLAM DB ingest)'
exit 0
bad: procedure
 use arg reason
 say 'FULL_SOURCE_V5V FAIL:' reason
 exit 4
::requires 'V5VCodec.cls'
