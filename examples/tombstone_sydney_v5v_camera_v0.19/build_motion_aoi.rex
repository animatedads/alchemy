/* Produce selective source-resolution requests from native Camera motion
   fragment ENDPOINTS, using first-party VisionHighResolutionRequest.  This
   does NOT fulfill requests or infer a ferry. */
numeric digits 18
parse arg shortlistFile regionFile outputFile
if shortlistFile='' | regionFile='' | outputFile='' then do
 say 'USAGE build_motion_aoi.rex shortlist.psv regions.psv output.psv'; exit 2
end
if outputFile=shortlistFile | outputFile=regionFile then call bad 'overlapping input/output'
if stream(shortlistFile,'c','query exists')='' | stream(regionFile,'c','query exists')='' then call bad 'missing input'
needed=.directory~new
expectedSource=''
if linein(shortlistFile)\=='track_id|first_frame|last_frame|observations|dx_cells|dy_cells|path_cells|motion_gate|gate_score|gate_reason|edge_share|size_ratio|source_ref|evidence_state' then call bad 'shortlist schema invalid'
do while lines(shortlistFile)>0
 row=linein(shortlistFile)
 parse var row id '|' first '|' last '|' observations '|' dx '|' dy '|' path '|' gate '|' score '|' reason '|' edge '|' size '|' source '|' state
 if state\=='OBSERVED_UNTESTED' | gate\=='ADMITTED_MOTION' | reason\=='ADMIT' then call bad 'unadmitted/forged shortlist'
 if \datatype(first,'W') | \datatype(last,'W') then call bad 'shortlist time fields invalid'
 if expectedSource='' then expectedSource=source
 else if source\==expectedSource then call bad 'mixed source hashes in shortlist'
 if needed~hasIndex(id) then call bad 'duplicate shortlist track'
 needed[id]=.array~of(first,last,0,0)
end
call stream shortlistFile,'c','close'
if needed~items=0 then call bad 'shortlist is empty'
if linein(regionFile)\=='track_id|frame|left|top|right|bottom|cells|max_delta|source_ref|evidence_state' then call bad 'region schema invalid'
requests=.array~new
seen=.directory~new
do while lines(regionFile)>0
 row=linein(regionFile)
 parse var row id '|' frame '|' left '|' top '|' right '|' bottom '|' cells '|' maxDelta '|' source '|' state
 if \needed~hasIndex(id) then iterate
 if source\==expectedSource | state\=='OBSERVED_UNTESTED' then call bad 'region source/state mismatched'
 entry=needed[id]
 if frame<>entry[1] & frame<>entry[2] then iterate
 if \datatype(frame,'W') | \datatype(left,'W') | \datatype(top,'W') | \datatype(right,'W') | \datatype(bottom,'W') then call bad 'region coordinates nonnumeric'
 if left<1 | top<1 | right>80 | bottom>45 | right<left | bottom<top then call bad 'region coordinates out of bounds'
 requestId='HR-SYDNEY-'||substr(source,8,16)||'-'||id||'-F'||frame
 if seen~hasIndex(requestId) then call bad 'duplicate endpoint region'
 seen[requestId]=1
 /* Exact mobile-video source region: webcam crop x=210..2129;
    80x45 evidence cells correspond to 24x24 pixels in 1920x1080. */
 x0=max(210,210+(left-1)*24-24)
 x1=min(2130,210+right*24+24)
 y0=max(0,(top-1)*24-24)
 y1=min(1080,bottom*24+24)
 w=x1-x0;h=y1-y0
 if w<1 | h<1 then call bad 'invalid source ROI'
 t0=frame/5;t1=(frame+1)/5
 region=.VisionRegion~new(x0,y0,w,h,t0,t1)
 request=.VisionHighResolutionRequest~new(source,region,t0,t1,'MOTION_REFINEMENT',requestId)
 if request~sourceRef\==source | request~state\=='REQUESTED' then call bad 'Vision request invariant broken'
 if request~region~x<>x0 | request~region~width<>w then call bad 'ROI projection invariant broken'
 requests~append(requestId||'|'||source||'|'||id||'|'||frame||'|'||t0||'|'||t1||'|'||x0||'|'||y0||'|'||w||'|'||h||'|MOTION_REFINEMENT|REQUESTED|OBSERVED_UNTESTED')
 if frame=entry[1] then entry[3]=entry[3]+1
 if frame=entry[2] then entry[4]=entry[4]+1
end
call stream regionFile,'c','close'
do id over needed
 entry=needed[id]
 if entry[3]<>1 | entry[4]<>1 then call bad 'missing unique endpoints for 'id
end
call stream outputFile,'c','open write replace'
call lineout outputFile,'request_id|source_ref|track_id|frame|start_seconds|end_seconds|source_x|source_y|source_width|source_height|reason|request_state|evidence_state'
do row over requests
 call lineout outputFile,row
end
call stream outputFile,'c','close'
say 'NATIVE VISION HIGH-RES REQUEST PASS: motion_fragments='needed~items 'endpoint_requests='requests~items
say 'SOURCE_MATERIAL_NOT_RETRIEVED; FERRY_IDENTITY=UNRESOLVED; EVIDENCE=OBSERVED_UNTESTED'
exit 0
bad: procedure
 use arg m
 say 'VISION HIGH-RES REQUEST FAIL:' m
 exit 3
::requires 'VisionHighResolutionRequest.cls'
