/* Independently validate causal source->target V5V search requests. */
numeric digits 18
parse arg nodesFile eventsFile gatesFile sourceHash
if nodesFile='' | eventsFile='' | gatesFile='' | sourceHash='' then call fail 'USAGE nodes events gates SHA256'
if length(sourceHash)<>64 | verify(sourceHash,'0123456789abcdef')<>0 then call fail 'source hash malformed'
sourceRef='sha256:'||sourceHash
pts=.array~new
call stream nodesFile,'c','open read'
if linein(nodesFile)\=='node_id|frame_index|timestamp_seconds|v5v_record|changed_cells|water_changed|excluded_changed|payload_offset|payload_bytes|source_ref|evidence_state' then call fail 'nodes schema'
do while lines(nodesFile)>0
 row=linein(nodesFile)
 parse var row id '|' frame '|' time '|' rec '|' changed '|' water '|' excluded '|' offset '|' length '|' source '|' evidence
 if \datatype(frame,'W') | \datatype(time,'N') then call fail 'node time invalid'
 if frame<>pts~items | source\==sourceRef | evidence\=='OBSERVED_UNTESTED' then call fail 'node authority/index invalid'
 if frame>0 then if time<=pts[pts~items] then call fail 'node PTS not increasing'
 pts~append(time)
end
call stream nodesFile,'c','close'
gates=.directory~new
call stream gatesFile,'c','open read'
if linein(gatesFile)\=='gate_id|x1|y1|x2|y2|radius|authority' then call fail 'gates header'
do while lines(gatesFile)>0
 row=linein(gatesFile)
 parse var row gate '|' a '|' b '|' c '|' d '|' radius '|' authority
 if gates~hasIndex(gate) then call fail 'duplicate gate'
 gates[gate]=1
end
call stream gatesFile,'c','close'
seeded=.directory~new;confirmed=.directory~new;lastTrackFrame=.directory~new;used=.directory~new
seeds=0;admitted=0;matches=0;requests=0;areaTotal=0
call stream eventsFile,'c','open read'
if linein(eventsFile)\=='track_id|event|trigger_gate|source_frame|source_timestamp_seconds|target_frame|target_timestamp_seconds|observed_x|observed_y|component_cells|search_left|search_top|search_right|search_bottom|search_area_cells|reason|source_ref|evidence_state' then call fail 'events header'
do while lines(eventsFile)>0
 row=linein(eventsFile)
 if length(row)-length(changestr('|',row,''))<>17 then call fail 'event fields invalid'
 parse var row tid '|' event '|' gate '|' frame '|' time '|' target '|' targetPts '|' ox '|' oy '|' cells '|' left '|' top '|' right '|' bottom '|' area '|' reason '|' source '|' state
 if source\==sourceRef | state\=='OBSERVED_UNTESTED' then call fail 'authority/source forged'
 if \gates~hasIndex(gate) | substr(tid,1,2)\=='GT' then call fail 'unknown gate/track'
 if \datatype(frame,'W') | \datatype(time,'N') | \datatype(cells,'W') then call fail 'frame/cell not numeric'
 if frame<1 | frame>=pts~items | time<>pts[frame+1] | cells<1 then call fail 'event source chronology'
 if \datatype(ox,'N') | \datatype(oy,'N') | ox<0 | ox>=80 | oy<0 | oy>=45 then call fail 'observation outside V5V'
 unique=tid||'|'||event||'|'||frame
 if used~hasIndex(unique) then call fail 'duplicate event'
 used[unique]=1
 if event='GATE_SEED_UNCONFIRMED' then do
  if seeded~hasIndex(tid) | target\=='-' | area<>0 then call fail 'seed contract failed'
  seeded[tid]=1;seeds=seeds+1
 end
 else if event='THRESHOLD_ADMITTED' then do
  if \seeded~hasIndex(tid) | confirmed~hasIndex(tid) | target\=='-' | reason\=='THRESHOLDS_PASS' then call fail 'admission contract failed'
  confirmed[tid]=1;admitted=admitted+1
 end
 else if event='FOLLOW_MATCH' then do
  if \confirmed~hasIndex(tid) | target\=='-' | area<1 then call fail 'match contract failed'
  matches=matches+1
 end
 else if event='LOCAL_SEARCH_REQUESTED' then do
  if \confirmed~hasIndex(tid) | \datatype(target,'W') | \datatype(targetPts,'N') then call fail 'uncausal local lookup'
  if target<>frame+1 | target>=pts~items | targetPts<>pts[target+1] then call fail 'wrong target original frame/PTS'
  if reason\=='NEXT_SOURCE_FRAME_BOUNDED' then call fail 'request reason invalid'
  requests=requests+1;areaTotal=areaTotal+area
 end
 else call fail 'unknown event state'
 if event='FOLLOW_MATCH' | event='LOCAL_SEARCH_REQUESTED' then do
  if \datatype(left,'W') | \datatype(top,'W') | \datatype(right,'W') | \datatype(bottom,'W') | \datatype(area,'W') then call fail 'bad predicted box fields'
  if left<0 | top<0 | right>79 | bottom>44 | right<left | bottom<top then call fail 'predicted box outside image'
  if area<>(right-left+1)*(bottom-top+1) | area>289 then call fail 'prediction area cap failed'
 end
end
call stream eventsFile,'c','close'
if seeds=0 | requests=0 then call fail 'empty qualification'
say 'V5V_GATE_RECEIPTS_PASS frames='pts~items 'seeds='seeds 'admitted='admitted 'matches='matches 'requests='requests 'requested_cells='areaTotal
say 'ONLY OBSERVED_UNTESTED; NO FERRY LABELS, NO SLAM TESTED'
exit 0
fail: procedure
 parse arg why
 say 'V5V_GATE_RECEIPTS_FAIL:' why
 exit 7
