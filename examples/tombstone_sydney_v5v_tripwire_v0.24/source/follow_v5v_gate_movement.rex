/* Source-linked, threshold-admitted tripwire-to-local-search workflow.
   All original frames scanned by native V5V gate extractor. ooRexx owns
   candidate association, time/velocity/uncertainty checks and local requests.
   No semantic vessel label, SLAM TESTED transition or source crop is asserted. */
numeric digits 18
parse arg nodesFile componentFile gateFile outFile sourceHash
if nodesFile='' | componentFile='' | gateFile='' | outFile='' | sourceHash='' then call die 'USAGE nodes.psv water_components.psv gates.psv out.psv SHA256'
if length(sourceHash)<>64 | verify(sourceHash,'0123456789abcdef')<>0 then call die 'invalid source hash'
if nodesFile=outFile | componentFile=outFile | gateFile=outFile then call die 'output overlaps input'
expectedSource='sha256:'||sourceHash
/* Preserve actual VFR timestamps; never infer from frame/5 or frame/30. */
pts=.array~new
call stream nodesFile,'c','open read'
if linein(nodesFile)\=='node_id|frame_index|timestamp_seconds|v5v_record|changed_cells|water_changed|excluded_changed|payload_offset|payload_bytes|source_ref|evidence_state' then call die 'source nodes header invalid'
do while lines(nodesFile)>0
 row=linein(nodesFile)
 parse var row id '|' frame '|' ptime '|' typ '|' changes '|' water '|' excluded '|' offset '|' bytes '|' source '|' state
 if \datatype(frame,'W') | \datatype(ptime,'N') then call die 'source node timing invalid'
 if frame<>pts~items | source\==expectedSource | state\=='OBSERVED_UNTESTED' then call die 'source node identity/order invalid'
 if frame>0 then if ptime<=pts[pts~items] then call die 'timestamps not increasing'
 pts~append(ptime)
end
call stream nodesFile,'c','close'
if pts~items<2 then call die 'insufficient source frames'
/* Validate all gate identifiers are configured; no inferred screenshot geometry. */
gateIds=.directory~new
call stream gateFile,'c','open read'
if linein(gateFile)\=='gate_id|x1|y1|x2|y2|radius|authority' then call die 'gate geometry header invalid'
do while lines(gateFile)>0
 row=linein(gateFile)
 parse var row gateId '|' x1 '|' y1 '|' x2 '|' y2 '|' r '|' authority
 if gateIds~hasIndex(gateId) | gateId='' | authority='' then call die 'duplicate or missing gate'
 gateIds[gateId]=1
end
call stream gateFile,'c','close'
if gateIds~items=0 then call die 'no gates configured'
call stream componentFile,'c','open read'
if linein(componentFile)\=='frame|timestamp_seconds|component_id|left|top|right|bottom|cells|centre_x|centre_y|gate_ids|source_ref|evidence_state' then call die 'component header invalid'
call stream outFile,'c','open write replace'
call lineout outFile,'track_id|event|trigger_gate|source_frame|source_timestamp_seconds|target_frame|target_timestamp_seconds|observed_x|observed_y|component_cells|search_left|search_top|search_right|search_bottom|search_area_cells|reason|source_ref|evidence_state'
active=.array~new
currentFrame=-1; frameComponents=.array~new; observed=0; seeds=0; admitted=0; matches=0; missed=0; requests=0; totalArea=0; gateTouched=0; nextTrack=1; lastCompId=0
/* component rows are sorted by native frame and component number */
do while lines(componentFile)>0
 row=linein(componentFile)
 parse var row frame '|' ptime '|' cid '|' xl '|' yt '|' xr '|' yb '|' cells '|' cx '|' cy '|' ids '|' source '|' state
 if \datatype(frame,'W') | \datatype(cid,'W') | \datatype(cells,'W') | \datatype(cx,'N') | \datatype(cy,'N') then call die 'invalid component numeric'
 if frame<1 | frame>=pts~items | cells<1 | source\==expectedSource | state\=='OBSERVED_UNTESTED' then call die 'component source/limits invalid'
 if ptime<>pts[frame+1] then call die 'component timestamp not equal source PTS'
 if xl<0 | xr>79 | yt<0 | yb>44 | xr<xl | yb<yt then call die 'component box out of bounds'
 if frame<>currentFrame then do
  if currentFrame>=0 then call processFrame
  if frame<currentFrame then call die 'nonmonotonic component frames'
  currentFrame=frame;frameComponents=.array~new;lastCompId=0
 end
 if cid<=lastCompId then call die 'duplicate component id in frame'
 lastCompId=cid
 if ids\=='-' then do
  parse var ids g1 ',' remaining
  if \gateIds~hasIndex(g1) then call die 'unconfigured trigger line'
  /* One water component may intersect multiple gates: source is not duplicated. */
  gateTouched=gateTouched+1
 end
 frameComponents~append(.array~of(frame,ptime,cx,cy,xr-xl+1,yb-yt+1,cells,ids,source))
 observed=observed+1
end
if currentFrame>=0 then call processFrame
call stream componentFile,'c','close'
call stream outFile,'c','close'
say 'V5V_TRIPWIRE_FOLLOW_PASS frames='pts~items 'observed_water_components='observed 'touching_gate='gateTouched 'candidate_seeds='seeds 'threshold_admitted='admitted 'follow_matches='matches 'local_next_frame_requests='requests 'search_cells='totalArea
say 'NO PROVED WAVE/BOAT IDENTITY; ONLY SOURCE-LINKED OBSERVED_UNTESTED; ALL V5V SCENE PIXELS RETAINED'
exit 0
processFrame: procedure expose pts active frameComponents currentFrame outFile expectedSource nextTrack seeds admitted matches missed requests totalArea
 /* Every candidate track competes for no more than one new source component. */
 now=pts[currentFrame+1];used=.directory~new;alive=.array~new
 do tr over active
  last=tr['last'];first=tr['previous']
  if now-last[2]>0.45 then iterate
  found=0;bestDistance=999;bestPred=.nil
  if first==.nil then do
   px=last[3];py=last[4];left=max(0,trunc(px-3));right=min(79,trunc(px+3.999));top=max(0,trunc(py-3));bottom=min(44,trunc(py+3.999))
  end
  else do
   bestPred=.V5VTripwireFollow~predict(first,last,now)
   if bestPred['admit']=0 then do
    alive~append(tr);iterate
   end
   left=bestPred['left'];right=bestPred['right'];top=bestPred['top'];bottom=bestPred['bottom']
   px=last[3]+(last[3]-first[3])*(now-last[2])/(last[2]-first[2])
   py=last[4]+(last[4]-first[4])*(now-last[2])/(last[2]-first[2])
  end
  do k=1 to frameComponents~items
   if used~hasIndex(k) then iterate
   c=frameComponents[k]
   if c[3]<left | c[3]>right | c[4]<top | c[4]>bottom then iterate
   /* Before admission, remain tied to the trigger band's observations. */
   if tr['confirmed']=0 & pos(tr['gate'],c[8])=0 then iterate
   distance=abs(c[3]-px)+abs(c[4]-py)
   if distance<bestDistance then do
    found=k;bestDistance=distance
   end
  end
  if found=0 then do
   alive~append(tr)
   iterate
  end
  used[found]=1;c=frameComponents[found]
  check=.V5VTripwireFollow~threshold(last,c)
  if check['admit']=0 then do
   /* Do not fabricate continuity across an unstable step. */
   if tr['confirmed']=0 then do
    tr['last']=c
    alive~append(tr)
   end
   else do
    tr['reason']=check['reason']
   end
   iterate
  end
  tr['previous']=last;tr['last']=c
  if tr['confirmed']=0 then do
   tr['confirmed']=1;admitted=admitted+1
   call record tr,'THRESHOLD_ADMITTED',c,0,0,0,0,0,check['reason']
  end
  else do
   matches=matches+1
   call record tr,'FOLLOW_MATCH',c,left,top,right,bottom,(right-left+1)*(bottom-top+1),'MATCH_IN_BOUNDED_SEARCH'
  end
  call requestNext tr,c
  alive~append(tr)
 end
 /* Once old tracks have had their chance, seed new candidate motion at lines. */
 do k=1 to frameComponents~items
  if used~hasIndex(k) then iterate
  c=frameComponents[k]
  if c[8]='-' then iterate
  gates=c[8];parse var gates gate ',' unused
  duplicate=0
  do tr over alive
   last=tr['last']
   if tr['gate']<>gate then iterate
   if now-last[2]>0.3 then iterate
   if abs(last[3]-c[3])+abs(last[4]-c[4])<=2 then do
    duplicate=1;leave
   end
  end
  if duplicate then iterate
  tr=.directory~new
  tr['id']='GT'||nextTrack;nextTrack=nextTrack+1
  tr['gate']=gate;tr['last']=c;tr['previous']=.nil;tr['confirmed']=0
  seeds=seeds+1
  alive~append(tr)
  call record tr,'GATE_SEED_UNCONFIRMED',c,0,0,0,0,0,'AWAIT_SECOND_POSITION_AND_THRESHOLD'
 end
 active=alive
 return
requestNext: procedure expose pts currentFrame outFile expectedSource requests totalArea
 use arg tr,c
 if currentFrame+1>=pts~items then return
 first=tr['previous'];last=tr['last']
 forecast=.V5VTripwireFollow~predict(first,last,pts[currentFrame+2])
 if forecast['admit']<>1 then return
 requests=requests+1;totalArea=totalArea+forecast['area']
 call record tr,'LOCAL_SEARCH_REQUESTED',c,forecast['left'],forecast['top'],forecast['right'],forecast['bottom'],forecast['area'],'NEXT_SOURCE_FRAME_BOUNDED',currentFrame+1,pts[currentFrame+2]
 return
record: procedure expose outFile expectedSource
 use arg tr,event,c,l,t,r,b,area,reason,targetFrame='-',targetTime='-'
 sayLine=tr['id']||'|'||event||'|'||tr['gate']||'|'||c[1]||'|'||c[2]||'|'||targetFrame||'|'||targetTime||'|'||c[3]||'|'||c[4]||'|'||c[7]||'|'||l||'|'||t||'|'||r||'|'||b||'|'||area||'|'||reason||'|'||expectedSource||'|OBSERVED_UNTESTED'
 call lineout outFile,sayLine
 return
die: procedure
 parse arg msg
 say 'V5V_TRIPWIRE_FOLLOW_FAIL:' msg
 exit 4
::requires 'V5VTripwireFollow.cls'
