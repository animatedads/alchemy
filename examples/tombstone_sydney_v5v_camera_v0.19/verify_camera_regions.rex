/* Native V5V/Camera bounding-region conservation, chronology and provenance.
   The emitted boxes are evidence fragments, never a verified vessel object. */
numeric digits 18
parse arg frameFile trackFile regionFile expectedHash expectedFrames
if frameFile='' | trackFile='' | regionFile='' | expectedHash='' | expectedFrames='' then do
 say 'USAGE verify_camera_regions.rex frames tracks regions SHA256 expectedFrames'; exit 2
end
if length(expectedHash)<>64 | verify(expectedHash,'0123456789abcdef')<>0 then call bad 'invalid hash'
if \datatype(expectedFrames,'W') then call bad 'invalid frame count'
source='sha256:'||expectedHash
fCount=.directory~new
regionsExpected=0
if stream(frameFile,'c','query exists')='' then call bad 'missing frames'
call stream frameFile,'c','open read'
head=linein(frameFile)
if head\=='frame|v5v_record|changed_cells|vision_regions|camera_regions|palette14_19_cells|roundtrip_exact|source_ref|evidence_state' then call bad 'invalid frame header'
count=0
do while lines(frameFile)>0
 row=linein(frameFile)
 parse var row frame '|' typ '|' changed '|' vision '|' camera '|' palette '|' exact '|' ref '|' state
 if \datatype(frame,'W') | \datatype(camera,'W') then call bad 'invalid frame data'
 if frame<>count then call bad 'frame chronology broken'
 if ref\==source | state\=='OBSERVED_UNTESTED' | exact\=='1' then call bad 'frame authority or hash forged'
 fCount[frame]=camera
 regionsExpected=regionsExpected+camera
 count=count+1
end
call stream frameFile,'c','close'
if count<>expectedFrames then call bad 'expected frame count mismatch'
if stream(trackFile,'c','query exists')='' then call bad 'missing tracks'
tracks=.directory~new
trackSeen=.directory~new
if linein(trackFile)\=='track_id|first_frame|last_frame|observations|dx_cells|dy_cells|path_cells|motion_gate|gate_score|gate_reason|edge_share|size_ratio|source_ref|evidence_state' then call bad 'invalid track header'
do while lines(trackFile)>0
 row=linein(trackFile)
 parse var row id '|' first '|' last '|' obs '|' dx '|' dy '|' path '|' gate '|' score '|' reason '|' edge '|' size '|' ref '|' state
 if tracks~hasIndex(id) then call bad 'duplicate track ID'
 if \datatype(first,'W') | \datatype(last,'W') | \datatype(obs,'W') then call bad 'invalid track bounds'
 if ref\==source | state\=='OBSERVED_UNTESTED' then call bad 'track authority/hash forged'
 tracks[id]=.array~of(first,last,obs)
 trackSeen[id]=0
end
call stream trackFile,'c','close'
if tracks~items=0 then call bad 'no tracks'
if stream(regionFile,'c','query exists')='' then call bad 'missing regions'
if linein(regionFile)\=='track_id|frame|left|top|right|bottom|cells|max_delta|source_ref|evidence_state' then call bad 'invalid region header'
perFrame=.directory~new
seen=.directory~new
n=0
do while lines(regionFile)>0
 row=linein(regionFile)
 parse var row id '|' frame '|' left '|' top '|' right '|' bottom '|' cells '|' maxDelta '|' ref '|' state
 if \tracks~hasIndex(id) then call bad 'region refers to missing track'
 if \datatype(frame,'W') | \datatype(left,'W') | \datatype(top,'W') | \datatype(right,'W') | \datatype(bottom,'W') | \datatype(cells,'W') | \datatype(maxDelta,'W') then call bad 'nonnumeric region fields'
 if frame<1 | frame>=count then call bad 'region frame outside source'
 if left<1 | top<1 | right>80 | bottom>45 | right<left | bottom<top then call bad 'region box outside V5V lattice'
 if cells<1 | cells>(right-left+1)*(bottom-top+1) | maxDelta<>1 then call bad 'region shape/delta invalid'
 t=tracks[id]
 if frame<t[1] | frame>t[2] then call bad 'region outside track span'
 key=id||':'||frame
 if seen~hasIndex(key) then call bad 'duplicate region per track/frame'
 seen[key]=1
 if ref\==source | state\=='OBSERVED_UNTESTED' then call bad 'region provenance/authority forged'
 trackSeen[id]=trackSeen[id]+1
 if perFrame~hasIndex(frame) then perFrame[frame]=perFrame[frame]+1
 else perFrame[frame]=1
 n=n+1
end
call stream regionFile,'c','close'
if n<>regionsExpected then call bad 'region rows not equal frame count total'
do k=0 to count-1
 observed=0
 if perFrame~hasIndex(k) then observed=perFrame[k]
 if observed<>fCount[k] then call bad 'frame region conservation failed'
end
do id over tracks
 t=tracks[id]
 if trackSeen[id]<>t[3] then call bad 'track region conservation failed'
end
say 'NATIVE CAMERA REGION RECEIPT PASS: source_frames='count 'track_count='tracks~items 'region_observations='n
say 'GEOMETRY=IMAGE_LATTICE_80x45; EVIDENCE=OBSERVED_UNTESTED; FERRY_IDENTITY=UNRESOLVED'
exit 0
bad: procedure
 use arg why
 say 'NATIVE CAMERA REGION RECEIPT FAIL:' why
 exit 3
