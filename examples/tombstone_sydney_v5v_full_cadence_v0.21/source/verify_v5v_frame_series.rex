/* Qualify complete source-frame Vision/V5V SLAM-candidate node/edge stream.
   No SLAM TESTED mutation, camera classification, or vessel identity claims.
*/
numeric digits 22
parse arg nodes edges blob sourceSha expectedFrames
if nodes='' | edges='' | blob='' | sourceSha='' | expectedFrames='' then do
 say 'USAGE verify_v5v_frame_series.rex nodes.psv edges.psv stream.v5b source_sha256 frame_count'
 exit 2
end
if length(sourceSha)<>64 then call bad 'source sha length'
if verify(sourceSha,'0123456789abcdef')<>0 then call bad 'source sha alphabet'
if \datatype(expectedFrames,'W') then call bad 'noninteger frame total'
if expectedFrames<2 then call bad 'frame total too small'
if stream(nodes,'c','query exists')='' | stream(edges,'c','query exists')='' | stream(blob,'c','query exists')='' then call bad 'missing input'
source='sha256:'||sourceSha
call stream nodes,'c','open read'
call stream edges,'c','open read'
if linein(nodes)\=='node_id|frame_index|timestamp_seconds|v5v_record|changed_cells|water_changed|excluded_changed|payload_offset|payload_bytes|source_ref|evidence_state' then call bad 'node header'
if linein(edges)\=='from_id|to_id|dt_seconds|relation|evidence_state' then call bad 'edge header'
previousId='';previousTime=.nil
frame=0;offset=0;water=0;excluded=0;keys=0;deltas=0;edgesRead=0
do while lines(nodes)>0
 row=linein(nodes)
 if countBar(row)<>10 then call bad 'node field count'
 parse var row id '|' seq '|' timestamp '|' kind '|' changes '|' wchanges '|' xchanges '|' recordOffset '|' recordSize '|' ref '|' status
 if \datatype(seq,'W') | \datatype(timestamp,'N') | \datatype(changes,'W') | \datatype(wchanges,'W') | \datatype(xchanges,'W') | \datatype(recordOffset,'W') | \datatype(recordSize,'W') then call bad 'nonnumeric node fields'
 if seq<>frame then call bad 'frame order'
 expectedId='SF.'||substr(sourceSha,1,16)||'.'||right('000000'||frame,6)
 if id\==expectedId then call bad 'node identity'
 if ref\==source | status\=='OBSERVED_UNTESTED' then call bad 'node source/authority'
 if changes<>wchanges+xchanges | changes<0 | changes>3600 then call bad 'change conservation'
 if recordOffset<>offset | recordSize<1 then call bad 'binary payload offset/size'
 if frame//30=0 then do
  if kind\=='KEYFRAME' | recordSize<>2250 then call bad 'expected full keyframe'
  keys=keys+1
 end
 else do
  if kind\=='DELTA' | recordSize<450 | recordSize>2700 then call bad 'expected delta'
  deltas=deltas+1
 end
 if previousTime\==.nil then do
  if timestamp<=previousTime then call bad 'source frame timestamps unordered'
  if lines(edges)=0 then call bad 'missing NEXT edge'
  link=linein(edges)
  if countBar(link)<>4 then call bad 'edge field count'
  parse var link from '|' to '|' deltaT '|' relation '|' edgeStatus
  if \datatype(deltaT,'N') then call bad 'edge dt nonnumeric'
  if from\==previousId | to\==id | relation\=='NEXT_SOURCE_FRAME' | edgeStatus\=='OBSERVED_UNTESTED' then call bad 'edge relation provenance'
  if abs((timestamp-previousTime)-deltaT)>0.000001 then call bad 'edge delta time mismatch'
  edgesRead=edgesRead+1
 end
 else do
  if frame<>0 | timestamp<>0 | changes<>0 then call bad 'first source frame invariant'
 end
 previousId=id;previousTime=timestamp
 frame=frame+1;offset=offset+recordSize;water=water+wchanges;excluded=excluded+xchanges
end
if lines(edges)>0 then call bad 'extra edge'
call stream nodes,'c','close';call stream edges,'c','close'
if frame<>expectedFrames then call bad 'source frame count incomplete'
if edgesRead<>expectedFrames-1 then call bad 'edge count incomplete'
if keys+deltas<>frame then call bad 'record mode count wrong'
actualSize=stream(blob,'c','query size')
if \datatype(actualSize,'W') then call bad 'binary size unavailable'
if actualSize<>offset then call bad 'payload blob byte conservation'
say 'SLAM FRAME SERIES QUALIFICATION PASS: SOURCE_FRAMES='frame 'NEXT_EDGES='edgesRead 'KEYFRAMES='keys 'DELTAS='deltas
say 'MOTION_ONLY_WATER_CHANGES='water 'EXCLUDED_CHANGES='excluded 'V5V_PAYLOAD_BYTES='offset
say 'STATUS=OBSERVED_UNTESTED; CANDIDATE SLAM GRAPH ONLY; FERRY_IDENTITY=UNRESOLVED'
exit 0
countBar: procedure
 use strict arg text
 n=0
 do i=1 to length(text)
  if substr(text,i,1)='|' then n=n+1
 end
 return n
bad: procedure
 use arg why
 say 'SLAM FRAME SERIES QUALIFICATION FAIL:'why
 exit 4
