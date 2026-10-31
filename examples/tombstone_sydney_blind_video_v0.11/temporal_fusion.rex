/* Tombstone 0.11: blind-trajectory temporal evidence, ooRexx 5.3.0.
   No truth labels, no manually supplied seed position, no geographic metres.
   Local evidence is HSV support; identity continuity is NOT independent recognition.
*/
numeric digits 16
parse arg detectionFile predictionFile outputFile
if detectionFile='' | predictionFile='' | outputFile='' then call bad 'USAGE detections.psv predictions.psv evidence.psv'
if detectionFile=outputFile | predictionFile=outputFile then call bad 'output overlaps inputs'
seen=.directory~new; seenPrediction=.directory~new
n=0; nPred=0; direct=0; low=0; uncertain=0
expected='frame|time_s|status|x_center|y_center|x|y|width|height|yellow_motion_area_half|n_candidates'
if stream(detectionFile,'c','query exists')='' then call bad 'detections absent'
if linein(detectionFile)<>expected then call bad 'detections header'
do while lines(detectionFile)>0
 rec=linein(detectionFile)
 if rec='' then iterate
 if length(rec)-length(changestr('|',rec,''))<>10 then call bad 'detection columns'
 parse var rec frame '|' timestamp '|' hit '|' cx '|' cy '|' bx '|' by '|' bw '|' bh '|' area '|' count
 if \datatype(frame,'W') | \datatype(timestamp,'N') then call bad 'invalid time/frame'
 if frame<0 | timestamp<0 then call bad 'negative frame or time'
 if seen~hasIndex(frame) then call bad 'duplicate frame'
 if hit<>'candidate' then call bad 'unobserved frame: explicit abstain required'
 if \datatype(cx,'N') | \datatype(cy,'N') | \datatype(bx,'W') | \datatype(by,'W') | \datatype(bw,'W') | \datatype(bh,'W') | \datatype(area,'W') | \datatype(count,'W') then call bad 'invalid geometry'
 if cx<0 | cy<0 | cx>=1920 | cy>=1080 | bx<0 | by<0 | bw<=0 | bh<=0 | bx+bw>1920 | by+bh>1080 | area<=0 | count<1 then call bad 'geometry bounds'
 if n>0 then do
   if frame<=frame.n | timestamp<=time.n then call bad 'time order'
   if frame-frame.n>12 then call bad 'frame gap'
   if timestamp-time.n>1 then call bad 'time gap'
   dx=cx-x.n;dy=cy-y.n
   if dx*dx+dy*dy>60*60 then call bad 'implausible trajectory step'
 end
 n=n+1; seen[frame]=n;frame.n=frame;time.n=timestamp;x.n=cx;y.n=cy; bw.n=bw;bh.n=bh
end
call stream detectionFile,'c','close'
if n<12 then call bad 'not enough temporal evidence'
if stream(predictionFile,'c','query exists')='' then call bad 'predictions absent'
if linein(predictionFile)<>'object_id|truth|guess|score_support|raw_ratio|fold|feature_yellow|feature_dark' then call bad 'predictions header'
do while lines(predictionFile)>0
 rec=linein(predictionFile)
 if rec='' then iterate
 if length(rec)-length(changestr('|',rec,''))<>7 then call bad 'prediction columns'
 parse var rec id '|' unusedTruth '|' decision '|' support '|' raw '|' fold '|' yellow '|' dark
 if left(id,6)<>'BLIND_' then iterate /* scored reference samples, never training truth */
 idx=substr(id,7)
 if \datatype(idx,'W') then call bad 'invalid candidate id'
 if \seen~hasIndex(idx) then call bad 'unmatched candidate prediction'
 if seenPrediction~hasIndex(idx) then call bad 'duplicate candidate prediction'
 if fold<>'VIDEO_HELDOUT' then call bad 'wrong fold'
 if decision<>'ferry' & decision<>'not_ferry' & decision<>'abstain' then call bad 'unknown decision'
 if \datatype(support,'N') | \datatype(raw,'N') | support<0 | support>1 | raw<0 then call bad 'invalid support'
 if abs(raw/(1+raw)-support)>0.000002 then call bad 'forged support'
 i=seen[idx]; seenPrediction[idx]=1;decision.i=decision;support.i=support
 nPred=nPred+1
 if decision='ferry' then direct=direct+1
 else if decision='not_ferry' then low=low+1
 else uncertain=uncertain+1
end
call stream predictionFile,'c','close'
if nPred<>n then call bad 'incomplete predictions'
/* Never infer identity from truth labels. Require at least six direct positive
   feature observations in first 12 frames, then track through appearance loss.
   A later low HSV score is a visual conflict, not automatically an identity swap. */
early=0
do i=1 to 12
 if decision.i='ferry' then early=early+1
end
if early>=6 then state='CONTINUITY_SUPPORTED'
else state='UNKNOWN'
call stream outputFile,'c','open write replace'
call lineout outputFile,'frame|time_s|x|y|direct_visual|track_state|support_indicator|evidence_state|geometry'
do i=1 to n
 if i<=12 then tstate='ACQUIRING'
 else tstate=state
 call lineout outputFile,frame.i||'|'||time.i||'|'||x.i||'|'||y.i||'|'||decision.i||'|'||tstate||'|'||support.i||'|OBSERVED_UNTESTED|UNSURVEYED_WATER_PLANE'
end
call stream outputFile,'c','close'
say 'TOMBSTONE TEMPORAL/0.11 PASS: frames='n 'direct_ferry='direct 'visual_nonferry='low 'abstain='uncertain
say 'EARLY_FERRY_OBSERVATIONS='early'/12 TRACK_STATE='state
say 'POST_ACQUISITION_CONTINUITY=' n-12 '/' n-12
say 'NOTE: trajectory identity is retained through low-feature frames; not fresh ferry recognition or SLAM tested score.'
exit 0
bad:
 parse arg msg
 say 'TOMBSTONE TEMPORAL/0.11 FAIL:' msg
 exit 2
