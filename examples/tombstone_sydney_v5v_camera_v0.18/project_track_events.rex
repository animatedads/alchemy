/* Sydney Harbour V5V / Camera Behaviour -> evidence-only SLAM candidate events.
   No semantic identity, authority escalation, coordinate calibration or SLAM
   database mutation. Input is externally qualified by native receipt verifier. */
numeric digits 18
parse arg trackFile outFile
if trackFile='' | outFile='' then do
 say 'USAGE: project_track_events.rex tracks.psv events.psv'
 exit 2
end
if trackFile=outFile then call fail 'output overlaps source'
if stream(trackFile,'c','query exists')='' then call fail 'track file absent'
call stream trackFile,'c','open read'
header=linein(trackFile)
if header\=='track_id|first_frame|last_frame|observations|dx_cells|dy_cells|path_cells|motion_gate|gate_score|gate_reason|edge_share|size_ratio|source_ref|evidence_state' then call fail 'invalid input schema'
rows=.array~new
seen=.directory~new
admitted=0;rejected=0
do while lines(trackFile)>0
 line=linein(trackFile)
 if line='' then call fail 'empty track row'
 parse var line id '|' first '|' last '|' observations '|' dx '|' dy '|' path '|' gate '|' score '|' reason '|' share '|' ratio '|' source '|' state
 if length(id)<3 then call fail 'track ID missing'
 if \datatype(first,'W') | \datatype(last,'W') | \datatype(observations,'W') then call fail 'nonnumeric frame/observation'
 if \datatype(dx,'N') | \datatype(dy,'N') | \datatype(path,'N') | \datatype(score,'N') then call fail 'nonnumeric movement values'
 if length(source)<>71 then call fail 'invalid source reference length'
 if substr(source,1,7)\=='sha256:' then call fail 'invalid source scheme'
 digest=substr(source,8)
 if verify(digest,'0123456789abcdef')<>0 then call fail 'invalid source hash'
 if state\=='OBSERVED_UNTESTED' then call fail 'input authority elevated'
 if first<1 | last<first | observations<1 then call fail 'time/observation bounds'
 if path<0 then call fail 'negative path'
 if gate='ADMITTED_MOTION' then do
  if reason\=='ADMIT' then call fail 'inconsistent admitted gate'
  kind='VISION.MOTION.QUALITY_ADMITTED'
  admitted=admitted+1
 end
 else if gate='REJECTED_MOTION' then do
  if reason='ADMIT' then call fail 'inconsistent rejected gate'
  kind='VISION.MOTION.QUALITY_REJECTED'
  rejected=rejected+1
 end
 else call fail 'unknown motion gate'
 eventId='SYDNEY.V5V.'||substr(digest,1,16)||'.'||id
 if seen~hasIndex(eventId) then call fail 'duplicate event identity'
 seen[eventId]=1
 /* Frame indices refer to 5fps reduced media, not native capture frames. */
 firstMs=first*200
 lastMs=last*200
 rows~append(eventId||'|'||kind||'|'||source||'|'||id||'|'||first||'|'||last||'|'||observations||'|'||firstMs||'|'||lastMs||'|'||dx||'|'||dy||'|'||path||'|'||score||'|'||reason||'|IMAGE_LATTICE_80x45|UNSURVEYED_WATER_PLANE|OBSERVED_UNTESTED|VISION_V5V_CAMERA_TEMPORAL')
end
call stream trackFile,'c','close'
if rows~items=0 then call fail 'empty observation collection'
call stream outFile,'c','open write replace'
call lineout outFile,'event_id|kind|source_ref|track_id|first_frame|last_frame|observations|first_media_ms|last_media_ms|dx_cells|dy_cells|path_cells|gate_score|gate_reason|space|geometry_state|evidence_state|algorithm'
do row over rows
 call lineout outFile,row
end
call stream outFile,'c','close'
say 'SYDNEY V5V SLAM EVIDENCE PROJECTION PASS events='rows~items 'admittedMotion='admitted 'rejectedMotion='rejected
say 'PROJECTION ONLY: SLAM GRAPH TESTED=0, FERRY IDENTITY=UNRESOLVED, GEO=UNSURVEYED'
exit 0
fail: procedure
 use arg message
 say 'SYDNEY V5V SLAM EVIDENCE PROJECTION FAIL:' message
 exit 3
