/* Held-out next-original-frame V5V movement inside forecast search boxes.
 * Never identifies an object: any contained movement is only a search hit. */
numeric digits 18
parse arg eventsFile componentsFile outFile expectedHash
if eventsFile='' | componentsFile='' | outFile='' | expectedHash='' then call fail 'USAGE follow.psv water_components.psv score.psv sourceSHA256'
expectedRef='sha256:'||expectedHash
byFrame=.directory~new
call stream eventsFile,'c','open read'
if linein(eventsFile)\=='track_id|event|trigger_gate|source_frame|source_timestamp_seconds|target_frame|target_timestamp_seconds|observed_x|observed_y|component_cells|search_left|search_top|search_right|search_bottom|search_area_cells|reason|source_ref|evidence_state' then call fail 'event header invalid'
requests=0;indices=.directory~new
requestsList=.array~new
do while lines(eventsFile)>0
 row=linein(eventsFile)
 parse var row tid '|' event '|' gate '|' origin '|' obsTime '|' target '|' targetPts '|' cx '|' cy '|' cells '|' xl '|' yt '|' xr '|' yb '|' area '|' why '|' source '|' state
 if source\==expectedRef | state\=='OBSERVED_UNTESTED' then call fail 'source forged'
 if event\=='LOCAL_SEARCH_REQUESTED' then iterate
 if \datatype(target,'W') | \datatype(targetPts,'N') | \datatype(area,'W') then call fail 'forecast not numeric'
 if target<>origin+1 | targetPts<=obsTime then call fail 'noncausal forecast'
 if xl<0 | xr>79 | yt<0 | yb>44 | area<>(xr-xl+1)*(yb-yt+1) | area>289 then call fail 'forecast area invalid'
 requestId=tid||'@'||target
 if indices~hasIndex(requestId) then call fail 'duplicate request identity'
 requests=requests+1;indices[requestId]=requests
 r=.array~of(requestId,tid,gate,origin,target,targetPts,xl,yt,xr,yb,area,0,0,0)
 requestsList~append(r)
 key=target
 if byFrame~hasIndex(key) then idxs=byFrame[key]
 else do;idxs=.array~new;byFrame[key]=idxs;end
 idxs~append(requests)
end
call stream eventsFile,'c','close'
call stream componentsFile,'c','open read'
if linein(componentsFile)\=='frame|timestamp_seconds|component_id|left|top|right|bottom|cells|centre_x|centre_y|gate_ids|source_ref|evidence_state' then call fail 'water component schema invalid'
do while lines(componentsFile)>0
 row=linein(componentsFile)
 parse var row frame '|' pts '|' comp '|' left '|' top '|' right '|' bottom '|' count '|' x '|' y '|' gates '|' source '|' state
 if source\==expectedRef | state\=='OBSERVED_UNTESTED' then call fail 'movement source forged'
 if \byFrame~hasIndex(frame) then iterate
 do index over byFrame[frame]
  request=requestsList[index]
  if pts<>request[6] then call fail 'target frame timestamp differs from source'
  if x>=request[7] & x<=request[9] & y>=request[8] & y<=request[10] then do
   request[12]=request[12]+1
   request[13]=request[13]+count
  end
  else if right>=request[7] & left<=request[9] & bottom>=request[8] & top<=request[10] then request[14]=request[14]+1
 end
end
call stream componentsFile,'c','close'
call stream outFile,'c','open write replace'
call lineout outFile,'request_id|trigger_gate|observation_frame|target_frame|target_pts|box_left|box_top|box_right|box_bottom|box_area|centroid_hits|contained_change_cells|overlap_only_components|source_ref|evidence_state'
anyHits=0;totalCells=0;outside=0;totalArea=0
 do request over requestsList
  if request[12]>0 then anyHits=anyHits+1
  totalCells=totalCells+request[13]
  outside=outside+request[14]
  totalArea=totalArea+request[11]
  call lineout outFile, request[1]||'|'||request[3]||'|'||request[4]||'|'||request[5]||'|'||request[6]||'|'||request[7]||'|'||request[8]||'|'||request[9]||'|'||request[10]||'|'||request[11]||'|'||request[12]||'|'||request[13]||'|'||request[14]||'|'||expectedRef||'|OBSERVED_UNTESTED'
 end
call stream outFile,'c','close'
say 'V5V_NEXT_FRAME_SEARCH_PASS requests='requests 'with_any_change_centroid='anyHits 'contained_changed_cells='totalCells 'overlap_only='outside 'searched_cells='totalArea
say 'ANY CHANGE IS NOT AN OBJECT MATCH; SOURCE AND SEMANTIC AUTHORITY PRESERVED'
exit 0
fail: procedure
 parse arg msg
 say 'V5V_NEXT_FRAME_SEARCH_FAIL:' msg
 exit 7
