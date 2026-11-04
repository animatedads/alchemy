/* Sydney Ferry V5V + Camera Behaviour: immutable observation receipt audit.
   Validates direct native frame, region and temporal-track evidence.  Not a
   semantic vessel test, map calibration or SLAM graph test. */
numeric digits 18
parse arg frameFile trackFile sourceHash expectedFrames
if frameFile='' | trackFile='' | sourceHash='' | expectedFrames='' then do
 say 'USAGE: verify_v5v_camera_tracks.rex frames.psv tracks.psv SHA256 expectedFrames'
 exit 2
end
if \datatype(expectedFrames,'W') then call fail 'invalid expected frame count'
if expectedFrames<2 then call fail 'expected frame count too small'
if length(sourceHash)<>64 then call fail 'invalid hash length'
if verify(sourceHash,'0123456789abcdef')<>0 then call fail 'invalid source hash'
expectedSource='sha256:'||sourceHash
if stream(frameFile,'c','query exists')='' then call fail 'frame file missing'
if stream(trackFile,'c','query exists')='' then call fail 'track file missing'
call stream frameFile,'c','open read'
header=linein(frameFile)
if header\=='frame|v5v_record|changed_cells|vision_regions|camera_regions|palette14_19_cells|roundtrip_exact|source_ref|evidence_state' then call fail 'frame header invalid'
frames=0; regions=0; changes=0; keys=0; deltas=0
do while lines(frameFile)>0
 row=linein(frameFile)
 if countSeparators(row)<>8 then call fail 'frame field count invalid'
 parse var row frame '|' record '|' changed '|' regionCount '|' cameraRegions '|' warmCells '|' exact '|' source '|' state
 if \datatype(frame,'W') | \datatype(changed,'W') | \datatype(regionCount,'W') | \datatype(cameraRegions,'W') | \datatype(warmCells,'W') then call fail 'nonnumeric frame fields'
 if frame<>frames then call fail 'frame sequence noncontiguous'
 if changed<0 | changed>3600 | regionCount<0 | regionCount>changed | cameraRegions<0 | cameraRegions>changed | warmCells<0 | warmCells>3600 then call fail 'invalid frame bounds'
 if source\==expectedSource | exact\=='1' | state\=='OBSERVED_UNTESTED' then call fail 'frame provenance or status invalid'
 if frames//10=0 then do
  if record\=='KEYFRAME' then call fail 'frame expected keyframe'
  keys=keys+1
 end
 else do
  if record\=='DELTA' then call fail 'frame expected delta'
  deltas=deltas+1
 end
 if frames=0 then if cameraRegions<>0 | changed<>0 then call fail 'initial frame has movement'
 frames=frames+1
 regions=regions+cameraRegions
 changes=changes+changed
end
call stream frameFile,'c','close'
if frames<>expectedFrames then call fail 'frame count mismatch'
call stream trackFile,'c','open read'
header=linein(trackFile)
if header\=='track_id|first_frame|last_frame|observations|dx_cells|dy_cells|path_cells|motion_gate|gate_score|gate_reason|edge_share|size_ratio|source_ref|evidence_state' then call fail 'track header invalid'
seen=.directory~new
tracks=0; admitted=0; rejected=0; persistent=0; totalObservations=0; longest=0
do while lines(trackFile)>0
 row=linein(trackFile)
 if countSeparators(row)<>13 then call fail 'track field count invalid'
 parse var row trackId '|' first '|' last '|' observations '|' dx '|' dy '|' path '|' gate '|' score '|' reason '|' edgeShare '|' sizeRatio '|' source '|' state
 if length(trackId)<3 then call fail 'track id too short'
 if substr(trackId,1,2)\=='LT' then call fail 'unexpected track namespace'
 tid=substr(trackId,3)
 if \datatype(tid,'W') then call fail 'invalid track serial'
 if tid<1 then call fail 'track serial not positive'
 if seen~hasIndex(trackId) then call fail 'duplicate track id'
 seen[trackId]=1
 if \datatype(first,'W') | \datatype(last,'W') | \datatype(observations,'W') then call fail 'non-integer track bounds'
 if first<1 | last>=frames | last<first | observations<1 then call fail 'track chronology invalid'
 if observations>last-first+1 then call fail 'more observations than frame slots'
 if \datatype(dx,'N') | \datatype(dy,'N') | \datatype(path,'N') | \datatype(score,'N') | \datatype(edgeShare,'N') | \datatype(sizeRatio,'N') then call fail 'invalid movement numeric fields'
 if path<0 | edgeShare<0 | edgeShare>1 | sizeRatio<1 | score<0 | score>7 then call fail 'invalid movement magnitudes'
 if source\==expectedSource | state\=='OBSERVED_UNTESTED' then call fail 'track provenance or status invalid'
 if gate='ADMITTED_MOTION' then do
  if reason\=='ADMIT' then call fail 'admitted reason mismatch'
  if observations<3 | score<4 | path=0 then call fail 'invalid admitted motion'
  admitted=admitted+1
 end
 else if gate='REJECTED_MOTION' then do
  if reason='ADMIT' then call fail 'rejected reason mismatch'
  rejected=rejected+1
 end
 else call fail 'unknown gate value'
 tracks=tracks+1
 if observations>=2 then persistent=persistent+1
 if observations>longest then longest=observations
 totalObservations=totalObservations+observations
end
call stream trackFile,'c','close'
if totalObservations<>regions then call fail 'regions != track observations'
if admitted+rejected<>tracks then call fail 'gate count inconsistency'
say 'SYDNEY NATIVE CAMERA RECEIPT PASS: frames='frames 'keys='keys 'deltas='deltas 'changed='changes
say 'REGIONS='regions 'TRACKS='tracks 'PERSISTENT='persistent 'LONGEST='longest 'ADMITTED_MOTION='admitted 'REJECTED_MOTION='rejected
say 'EVIDENCE STATUS: OBSERVED_UNTESTED; no ferry identity or SLAM graph test'
exit 0
countSeparators: procedure
 use strict arg line
 n=0
 do i=1 to length(line)
  if substr(line,i,1)='|' then n=n+1
 end
 return n
fail: procedure
 use strict arg message
 say 'SYDNEY NATIVE CAMERA RECEIPT FAIL:' message
 exit 3
