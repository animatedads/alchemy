/* Evidence-only Camera Behaviour shortlist, no vessel recognition. */
numeric digits 18
parse arg input output limit
if input='' | output='' then do; say 'USAGE top_motion_tracks.rex tracks.psv shortlist.psv [limit]'; exit 2;end
if limit='' then limit=20
if \datatype(limit,'W') then call bad 'limit must be whole number'
if limit<1 | limit>1000 | input=output then call bad 'invalid limit/overlapping output'
call stream input,'c','open read'
header=linein(input)
if header\=='track_id|first_frame|last_frame|observations|dx_cells|dy_cells|path_cells|motion_gate|gate_score|gate_reason|edge_share|size_ratio|source_ref|evidence_state' then call bad 'invalid header'
all=.array~new
used=.directory~new
do while lines(input)>0
 row=linein(input)
 parse var row id '|' first '|' last '|' observations '|' dx '|' dy '|' path '|' gate '|' score '|' reason '|' edge '|' size '|' source '|' state
 if gate\=='ADMITTED_MOTION' then iterate
 if state\=='OBSERVED_UNTESTED' then call bad 'evidence state promotion'
 if \datatype(observations,'W') | \datatype(score,'N') | \datatype(path,'N') then call bad 'nonnumeric value'
 all~append(.array~of(observations,score,path,row))
end
call stream input,'c','close'
call stream output,'c','open write replace'
call lineout output,header
emitted=0
do i=1 to min(limit,all~items)
 best=0; bestObs=-1; bestScore=-1; bestPath=-1
 do j=1 to all~items
  if used~hasIndex(j) then iterate
  rec=all[j]
  obs=rec[1];score=rec[2];path=rec[3]
  if obs>bestObs | (obs=bestObs & score>bestScore) | (obs=bestObs & score=bestScore & path>bestPath) then do
   best=j;bestObs=obs;bestScore=score;bestPath=path
  end
 end
 if best=0 then leave
 used[best]=1
 call lineout output,all[best][4]
 emitted=emitted+1
end
call stream output,'c','close'
say 'TOP MOTION TRACKS PASS: admitted='all~items 'shortlisted='emitted 'vessel_identity=UNRESOLVED'
exit 0
bad: procedure
 use arg m
 say 'TOP MOTION TRACKS FAIL:'m
 exit 3
