/* ooRexx 5.3.0 : Independent source-linked bridge between causal V5V
   candidate regions, actual original-resolution crop features and historical
   RGB temporal evidence. Does not admit a ferry ID, coordinate or TESTED edge. */
numeric digits 18
parse arg imageFile motionFile outputFile
if imageFile='' | motionFile='' | outputFile='' then do
 say 'USAGE verify_v031.rex auto_features.psv temporal_features.psv decisions.psv';exit 2
end
if imageFile=motionFile | imageFile=outputFile | motionFile=outputFile then call bad 'output/input collision'
imgs=.directory~new
mtn=.directory~new
if stream(imageFile,'c','query exists')='' | stream(motionFile,'c','query exists')='' then call bad 'missing input'
call stream imageFile,'c','open read'
expected='camera|period|frame|pts|rank|source_sha256|v5v_x0|v5v_y0|v5v_x1|v5v_y1|actual_source_x|actual_source_y|actual_source_width|actual_source_height|rgb24_sha256|bright160|bright180|hedge|vedge|mean_luma|proposal_score100|evidence_state'
if linein(imageFile)\==expected then call bad 'structural schema unexpected'
count=0
 do while lines(imageFile)>0
  line=linein(imageFile)
  if countPipes(line)<>21 then call bad 'structural field count'
  parse var line cam '|' period '|' frame '|' pts '|' rank '|' source '|' x0 '|' y0 '|' x1 '|' y1 '|' sx '|' sy '|' sw '|' sh '|' digest '|' bright '|' bright180 '|' hedge '|' vedge '|' mean '|' score '|' authority
  call checkBase cam,period,frame,rank,source,digest,authority
  nums=.array~of(pts,x0,y0,x1,y1,sx,sy,sw,sh,bright,bright180,hedge,vedge,mean,score)
  do n over nums
   if \datatype(n,'N') then call bad 'nonnumeric structural field'
  end
  if abs(pts-(1.4+frame/30))>0.00001 then call bad 'actual PTS inconsistent with source frame'
  if cam='2' then scale=16
  else scale=8
  if x0<0 | x1>80 | y0<0 | y1>45 | x0>=x1 | y0>=y1 then call bad 'V5V box bounds'
  if sx<>max(0,x0-2)*scale | sy<>max(0,y0-2)*scale | sw<>(min(80,x1+2)-max(0,x0-2))*scale | sh<>(min(45,y1+2)-max(0,y0-2))*scale then call bad 'pixel box not V5V-bounded'
  if (x1-x0)*(y1-y0)>256 then call bad 'unbounded search area'
  if bright<0 | bright>1 | bright180<0 | bright180>bright | hedge<0 | hedge>1 | vedge<0 | vedge>1 | mean<0 | mean>255 | score<0 then call bad 'image feature out of range'
  id=cam||'.'||period||'.'||frame||'.'||rank
  if imgs~hasIndex(id) then call bad 'duplicate structural observation'
  o=.array~of(source,digest,bright+vedge,pts,sw,sh,score)
  imgs[id]=o;count=count+1
 end
call stream imageFile,'c','close'
if count<>60 then call bad 'incomplete 60 structural proposals'
call stream motionFile,'c','open read'
if linein(motionFile)\=='camera|period|frame|rank|source_sha256|crop_rgb24_sha256|change5s|change10s|both_changes|dynamic_bright|dynamic_vertical_edges|all_bright|coherent_blocks|total_blocks|state' then call bad 'temporal schema unexpected'
countT=0
 do while lines(motionFile)>0
  line=linein(motionFile)
  if countPipes(line)<>14 then call bad 'temporal field count'
  parse var line cam '|' period '|' frame '|' rank '|' source '|' digest '|' delta5 '|' delta10 '|' both '|' dynamicBright '|' dynamicEdge '|' allbright '|' blocks '|' blockTotal '|' authority
  call checkBase cam,period,frame,rank,source,digest,authority
  id=cam||'.'||period||'.'||frame||'.'||rank
  if \imgs~hasIndex(id) then call bad 'unmatched temporal observation'
  if mtn~hasIndex(id) then call bad 'duplicate temporal observation'
  o=imgs[id]
  if o[1]\==source | o[2]\==digest then call bad 'temporal source/crop digest mismatch'
  metrics=.array~of(delta5,delta10,both,dynamicBright,dynamicEdge,allbright,blocks,blockTotal)
  do v over metrics
   if \datatype(v,'N') then call bad 'nonnumeric motion feature'
  end
  do v over .array~of(delta5,delta10,both,dynamicBright,dynamicEdge,allbright)
   if v<0 | v>1 then call bad 'motion feature out of [0,1]'
  end
  if both>min(delta5,delta10)+.00000002 then call bad 'intersection cannot exceed source delta'
  if dynamicBright>allbright+.00000002 then call bad 'dynamic light cannot exceed total light'
  if \datatype(blocks,'W') | \datatype(blockTotal,'W') | blocks<0 | blockTotal<1 | blocks>blockTotal then call bad 'coherent block count invalid'
  mtn[id]=.array~of(delta5,delta10,both,dynamicBright,dynamicEdge,allbright)
  countT=countT+1
 end
call stream motionFile,'c','close'
if countT<>60 then call bad 'temporal rows incomplete'
/* Rule v0.30 is locked in original manually selected ROI space. Here it is
   reported only as a transfer DIAGNOSTIC. A conservative motion rule with
   explicit thresholds chosen during this experiment produce an *exploratory*
   movement flag. They are NOT preregistered and this is not an independent
   accuracy qualification.
   Neither is a calibrated vessel classifier. */
call stream outputFile,'c','open write replace'
call lineout outputFile,'camera|period|frame|rank|source_sha256|crop_rgb24_sha256|static_structure_score|original_v030_gate|five_sec_change|ten_sec_change|persistent_change|dynamic_bright|motion_gate|fusion_result|authority'
counts=.directory~new
 do cam over .array~of('2','3')
  do period over .array~of('cruise','baseline')
   nMotion=0;nV030=0;nAbstain=0
   do frame over .array~of(450,900,1350)
    do rank=1 to 5
     id=cam||'.'||period||'.'||frame||'.'||rank
     if \imgs~hasIndex(id) | \mtn~hasIndex(id) then call bad 'incomplete key set'
     a=imgs[id];m=mtn[id]
     score=a[3]
     if score>=0.15064677 then fixed='STATIC_STRUCTURE_SUPPORT'
     else if score<=0.13064677 then fixed='STATIC_STRUCTURE_NEGATIVE'
     else do;fixed='STATIC_STRUCTURE_ABSTAIN';nAbstain=nAbstain+1;end
     if fixed='STATIC_STRUCTURE_SUPPORT' then nV030=nV030+1
     /* A temporal anomaly flag is not object recognition: static high
        scores cannot override weak or absent motion support. */
     if m[3]>=0.05 & m[4]>=0.02 then do
      motion='TEMPORAL_ANOMALY_PRESENT';nMotion=nMotion+1
      fusion='REVIEW_HIGH_RES_OBJECT'
     end
     else do
      motion='TEMPORAL_ANOMALY_UNRESOLVED'
      fusion='ABSTAIN_VESSEL_ID'
     end
     call lineout outputFile,cam||'|'||period||'|'||frame||'|'||rank||'|'||a[1]||'|'||a[2]||'|'||format(score,3,8)||'|'||fixed||'|'||m[1]||'|'||m[2]||'|'||m[3]||'|'||m[4]||'|'||motion||'|'||fusion||'|OBSERVED_UNTESTED'
    end
   end
   counts[cam||'.'||period]=nMotion
   say 'V031_CAMERA='cam 'PERIOD='period 'ROI=15 OLD_STATIC_SUPPORT='nV030 'STATIC_ABSTAIN='nAbstain 'TEMPORAL_ANOMALY='nMotion
  end
 end
call stream outputFile,'c','close'
say 'V5V_CAUSAL_BLIND_ADMISSION_PASS 60/60 source-bound ROIs, all geographic/ship labels ABSTAIN'
say 'SCENE_LABELS_DIAGNOSTIC_ONLY CAMERA3='counts['3.cruise']'/'counts['3.baseline'] 'CAMERA2='counts['2.cruise']'/'counts['2.baseline']
exit 0
checkBase: procedure
 use arg cam,period,frame,rank,source,digest,authority
 if cam\=='2' & cam\=='3' then call bad 'unregistered source camera'
 if period\=='cruise' & period\=='baseline' then call bad 'invalid labelled evaluation partition'
 if \datatype(frame,'W') | \datatype(rank,'W') then call bad 'invalid frame/rank integer'
 if frame<>450 & frame<>900 & frame<>1350 then call bad 'unapproved source test frame'
 if rank<1 | rank>5 then call bad 'invalid automatic proposal rank'
 if cam='2' & period='cruise' then expected='6b180a1d9779a22dd770b8081a29d40c477b3b2e1f99e9b233b38be804838830'
 if cam='2' & period='baseline' then expected='bf0dcef14da41b17b6b1214589e2a29067b58a85d4899078ccc51f9f0b700de0'
 if cam='3' & period='cruise' then expected='c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e'
 if cam='3' & period='baseline' then expected='58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d'
 if source\==expected then call bad 'source SHA mismatch'
 if length(digest)<>64 | verify(digest,'0123456789abcdef')<>0 then call bad 'crop digest malformed'
 if authority\=='OBSERVED_UNTESTED' then call bad 'false authority promotion'
 return
countPipes: procedure
 use arg t
 n=0
 do j=1 to length(t)
  if substr(t,j,1)=='|' then n=n+1
 end
 return n
bad: procedure
 use arg why
 say 'V031_EVIDENCE_REJECT:' why
 exit 3
