/* Tombstone Sydney evidence adapter 0.8; native ooRexx, no SLAM core mutation.
   Strictly observations, NEVER Tested SLAM graph edges or identity proofs.
   First validates all sources/predictions, then writes an evidence PSV.
   Input trust: source hashes from independent file measurement; this adapter
   checks shape and linkage, NOT raw JPEG SHA verification (caller must do so).
*/
numeric digits 20
parse arg featuresFile videoFile predictionsFile sourceFile outputFile
if featuresFile='' | videoFile='' | predictionsFile='' | sourceFile='' | outputFile='' then call fail 'USAGE feature.psv video.psv predictions.psv sources.sha256.psv output.psv'
if featuresFile=outputFile | videoFile=outputFile | predictionsFile=outputFile | sourceFile=outputFile then call fail 'output must not overwrite input'
seenSource=.directory~new
sourceHashes=.directory~new
seenObject=.directory~new
seenPrediction=.directory~new
count=0;predCount=0;sourceCount=0;reviews=0
call readSources sourceFile
call readFeatures featuresFile, 'PHOTO'
call readFeatures videoFile, 'VIDEO'
call readPredictions predictionsFile
expectedPredictions=count-reviews
if predCount<>expectedPredictions then call fail 'prediction count mismatch'
do i=1 to count
 if truth.i='review' then iterate
 if \seenPrediction~hasIndex(id.i) then call fail 'prediction absent for 'id.i
end
/* No output is written unless every check above passes. */
call stream outputFile,'c','open write replace'
call lineout outputFile, 'observation_id|source_kind|source_group|source_sha256|crop_sha256|hypothesis|decision|support_indicator|evidence_state|geometry_state|correlation_group|algorithm'
do i=1 to count
 if truth.i='review' then do
   decision='REVIEW_ONLY'; score='NA'
 end
 else do
   decision=predDecision.i; score=predSupport.i
 end
 if sourceKind.i='VIDEO' then corr='MANLY_CLIP_1000066232'
 else corr='PHOTO_FRAME_'||sourceGroup.i
 /* No ground-truth label, vessel identity or proof-state escalation is written. */
 call lineout outputFile, id.i||'|'||sourceKind.i||'|'||sourceGroup.i||'|'||sourceHashes[sourceName.i]||'|'||cropHash.i||'|TRADITIONAL_YELLOW_GREEN_FERRY|'||decision||'|'||score||'|OBSERVED_UNTESTED|UNSURVEYED_WATER_PLANE|'||corr||'|HSV_FRACTION_0.7'
end
call stream outputFile,'c','close'
say 'TOMBSTONE VISION ADAPTER/0.8 PASS SOURCES='sourceCount 'OBSERVATIONS='count 'SCORED='predCount 'REVIEW='reviews
say 'EVIDENCE_STATE=OBSERVED_UNTESTED; GEOMETRY=UNSURVEYED; SLAM_TESTED_GRAPH_EDGES=0'
exit 0
readSources: procedure expose seenSource sourceHashes sourceCount
 parse arg file
 if stream(file,'c','query exists')='' then call fail 'missing source manifest'
 if linein(file)<>'source|sha256' then call fail 'source header invalid'
 do while lines(file)>0
  rec=linein(file)
  if rec='' then iterate
  if length(rec)-length(changestr('|',rec,''))<>1 then call fail 'source columns'
  parse var rec src '|' hash
  if \isToken(src) | \isSha(hash) then call fail 'source identifier or sha invalid'
  if seenSource~hasIndex(src) then call fail 'duplicated source'
  seenSource[src]=1;sourceHashes[src]=hash;sourceCount=sourceCount+1
 end
 call stream file,'c','close'
 if sourceCount=0 then call fail 'empty source list'
 return
readFeatures: procedure expose seenSource sourceHashes seenObject count reviews sourceName. sourceKind. sourceGroup. id. truth. cropHash. featYellow. featDark.
 parse arg file,kind
 if stream(file,'c','query exists')='' then call fail 'missing features'
 header='source|source_group|object_id|truth|view|width|height|yellow|dark|green|white|edges|aspect|sha256_crop'
 if linein(file)<>header then call fail 'feature header invalid'
 do while lines(file)>0
  rec=linein(file)
  if rec='' then iterate
  if length(rec)-length(changestr('|',rec,''))<>13 then call fail 'feature columns'
  parse var rec source '|' grp '|' obj '|' tr '|' view '|' w '|' h '|' y '|' d '|' g '|' white '|' edges '|' aspect '|' hash
  if \isToken(source) | \isToken(grp) | \isToken(obj) | \isToken(view) then call fail 'invalid feature identifiers'
  if \seenSource~hasIndex(source) then call fail 'source missing from manifest'
  if seenObject~hasIndex(obj) then call fail 'duplicated observation id'
  if \isSha(hash) then call fail 'invalid crop SHA256'
  if \datatype(w,'W') | \datatype(h,'W') then call fail 'invalid dimensions'
  if w<=0 | h<=0 then call fail 'invalid dimensions'
  if \datatype(y,'N') | \datatype(d,'N') | \datatype(g,'N') | \datatype(white,'N') | \datatype(edges,'N') | \datatype(aspect,'N') then call fail 'nonnumeric feature'
  if y<0 | y>1 | d<0 | d>1 | g<0 | g>1 | white<0 | white>1 | edges<0 | edges>1 | aspect<=0 then call fail 'out of range feature'
  if kind='PHOTO' then do
    if tr<>'positive' & tr<>'negative' & tr<>'review' then call fail 'invalid PHOTO evaluation role'
    if source<>grp then call fail 'photo source_group mismatch'
  end
  else if tr<>'heldout_positive' | grp<>'video_manly' | source<>'1000066232.mp4' then call fail 'video role or identity mismatch'
  seenObject[obj]=1;count=count+1
  sourceName.count=source; sourceKind.count=kind; sourceGroup.count=grp
  id.count=obj;truth.count=tr;cropHash.count=hash;featYellow.count=y;featDark.count=d
  if tr='review' then reviews=reviews+1
 end
 call stream file,'c','close'
 return
readPredictions: procedure expose seenObject seenPrediction predCount count reviews id. truth. sourceGroup. featYellow. featDark. predDecision. predSupport.
 parse arg file
 if stream(file,'c','query exists')='' then call fail 'missing predictions'
 if linein(file)<>'object_id|truth|guess|score_support|raw_ratio|fold|feature_yellow|feature_dark' then call fail 'prediction header invalid'
 do while lines(file)>0
  rec=linein(file)
  if rec='' then iterate
  if length(rec)-length(changestr('|',rec,''))<>7 then call fail 'prediction columns'
  parse var rec obj '|' tr '|' guess '|' support '|' raw '|' fold '|' y '|' d
  if \seenObject~hasIndex(obj) then call fail 'unexpected prediction object'
  if seenPrediction~hasIndex(obj) then call fail 'duplicate prediction'
  i=0
  do j=1 to count
   if id.j=obj then do
    i=j;leave
   end
  end
  if i=0 then call fail 'missing indexed object'
  if truth.i='review' then call fail 'REVIEW must not acquire score'
  if truth.i<>tr then call fail 'truth role mismatch (evaluation only)'
  if \datatype(support,'N') | \datatype(raw,'N') | \datatype(y,'N') | \datatype(d,'N') then call fail 'nonnumeric prediction'
  if support<0 | support>1 | raw<0 then call fail 'out-of-range support'
  if abs(raw/(1+raw)-support)>0.000002 then call fail 'unsupported score mapping'
  if abs(y-featYellow.i)>0.0000001 | abs(d-featDark.i)>0.0000001 then call fail 'prediction feature mismatch'
  if truth.i='heldout_positive' then expectedFold='VIDEO_HELDOUT'
  else expectedFold=sourceGroup.i
  if fold<>expectedFold then call fail 'holdout provenance mismatch'
  if raw>1.1 then expectedDecision='ferry'
  else if raw<0.9 then expectedDecision='not_ferry'
  else expectedDecision='abstain'
  if guess<>expectedDecision then call fail 'decision contradicts support'
  if guess='ferry' then decision='FERRY_SUPPORT'
  else if guess='not_ferry' then decision='NOT_FERRY_SUPPORT'
  else decision='ABSTAIN'
  seenPrediction[obj]=1;predCount=predCount+1
  predDecision.i=decision; predSupport.i=support
 end
 call stream file,'c','close'
 return
isToken: procedure
 parse arg x
 if x='' then return 0
 allowed='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-'
 return verify(x,allowed)=0
isSha: procedure
 parse arg x
 return length(x)=64 & verify(x,'0123456789abcdef')=0
fail:
 parse arg msg
 say 'TOMBSTONE VISION ADAPTER/0.8 FAIL:' msg
 exit 2
