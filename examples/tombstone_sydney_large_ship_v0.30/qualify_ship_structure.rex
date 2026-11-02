/* ooRexx v0.30: locked one-camera structural reference, other camera held out.
 * V5V points to source ROIs; C reads original RGB24. No vessel identity proof.
 * Architecture: user. Code: ChatGPT GPT-6, 2026-11-02.
 */
numeric digits 18
parse arg input output
if input='' then input='features.psv'
if output='' then output='ship_structure_predictions.psv'
if input=output then call fail 'input/output collision'
if stream(input,'c','query exists')='' then call fail 'source evidence missing'
call stream input,'c','open read'
header=linein(input)
if header\=='camera|scene|frame|source_sha256|crop_x|crop_y|width|height|crop_rgb_sha256|bright160|bright180|hedge|vedge|mean_luma|evidence_state' then call fail 'schema or version mismatch'
rows=.directory~new
count=0
seen=.directory~new
frames=.array~of(150,450,750,900,1050,1350,1650)
do while lines(input)>0
 line=linein(input)
 if countPipes(line)<>14 then call fail 'field count mismatch'
 parse var line cam '|' scene '|' frame '|' source '|' x '|' y '|' width '|' height '|' crop '|' b160 '|' b180 '|' hedge '|' vedge '|' avg '|' state
 if cam\=='2' & cam\=='3' then call fail 'camera outside registered sources'
 if scene\=='cruise' & scene\=='baseline' then call fail 'unqualified source class'
 if state\=='OBSERVED_UNTESTED' then call fail 'forged evidence authority'
 if \datatype(frame,'W') then call fail 'frame is not whole-number index'
 if frame<0 | frame>=1800 then call fail 'frame bounds'
 if \frames~hasItem(frame) then call fail 'source frame is not in frozen evaluation sequence'
 if cam='2' then do
   if x<>365 | y<>365 | width<>150 | height<>134 then call fail 'camera2 source crop changed'
   if scene='cruise' then expected='6b180a1d9779a22dd770b8081a29d40c477b3b2e1f99e9b233b38be804838830'
   else expected='bf0dcef14da41b17b6b1214589e2a29067b58a85d4899078ccc51f9f0b700de0'
 end
 else do
   if x<>225 | y<>95 | width<>320 | height<>184 then call fail 'camera3 source crop changed'
   if scene='cruise' then expected='c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e'
   else expected='58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d'
 end
 if source\==expected then call fail 'forged video source digest'
 if length(crop)<>64 | verify(crop,'0123456789abcdef')<>0 then call fail 'malformed crop RGB digest'
 if frame=900 then do
    select
      when cam='2' & scene='cruise' then ref='e2738640ae7891690b60f554030112f15506fa3dff7be513de6d93a80edc2933'
      when cam='2' & scene='baseline' then ref='199b33525ab2a8630acefb9149f0381eb00c3ef113ddd978bf2e9e7fbe6d67d8'
      when cam='3' & scene='cruise' then ref='60e67bfd0428eb18030cdbafe0f0d9cb3d4c7179b22b1bb25034f34595cc129a'
      when cam='3' & scene='baseline' then ref='bf8c352d8816ed8f275c496ffbd37633233030d8627af5080820692025c8e851'
      otherwise call fail 'unexpected reference'
    end
    if crop\==ref then call fail 'historical source-crop hash changed'
 end
 metrics=.array~of(b160,b180,hedge,vedge,avg)
 do m over metrics
   if \datatype(m,'N') then call fail 'nonnumeric structural metric'
 end
 if b160<0 | b160>1 | b180<0 | b180>1 | hedge<0 | hedge>1 | vedge<0 | vedge>1 | avg<0 | avg>255 then call fail 'structural metric outside bounds'
 if b180>b160 then call fail 'monotonic brightness invariant violated'
 id=cam||'.'||scene||'.'||frame
 if seen~hasIndex(id) then call fail 'duplicate source-frame evidence'
 seen[id]=1
 r=.directory~new
 r['CAM']=cam; r['SCENE']=scene;r['FRAME']=frame;r['SOURCE']=source;r['CROP']=crop
 r['BRIGHT']=b160;r['HEDGE']=hedge;r['VEDGE']=vedge
 r['SCORE']=b160+vedge
 rows[id]=r
 count=count+1
end
call stream input,'c','close'
if count<>28 then call fail 'incomplete source evidence 28 required'
do cam over .array~of('2','3')
 do scene over .array~of('cruise','baseline')
  do frame over frames
   if \rows~hasIndex(cam||'.'||scene||'.'||frame) then call fail 'missing source/camera/frame row'
  end
 end
end
/* Training uses ONLY camera2 original frame 900 cruise-vs-normal pair. */
trainPos=rows['2.cruise.900']['SCORE']
trainNeg=rows['2.baseline.900']['SCORE']
if trainPos<=trainNeg then call fail 'training pair not separable'
threshold=(trainPos+trainNeg)/2
margin=0.010
pred=.array~new
heldCorrect=0; heldWrong=0; heldAbstain=0; heldCamera3=0; heldTemporal2=0
minPos=100;maxNeg=-100
 do cam over .array~of('2','3')
  do scene over .array~of('cruise','baseline')
   do frame over frames
    id=cam||'.'||scene||'.'||frame
    r=rows[id];score=r['SCORE']
    role='HELDOUT'
    if cam='2' & frame=900 then role='TRAIN_CAMERA2_ONLY'
    if score>=threshold+margin then claim='LARGE_SHIP_STRUCTURE_SUPPORT'
    else if score<=threshold-margin then claim='NO_LARGE_SHIP_STRUCTURE_SUPPORT'
    else claim='ABSTAIN_UNCERTAIN_STRUCTURE'
    expected='LARGE_SHIP_STRUCTURE_SUPPORT'
    if scene='baseline' then expected='NO_LARGE_SHIP_STRUCTURE_SUPPORT'
    if role='HELDOUT' then do
      if claim='ABSTAIN_UNCERTAIN_STRUCTURE' then heldAbstain=heldAbstain+1
      else if claim<>expected then heldWrong=heldWrong+1
      else heldCorrect=heldCorrect+1
      if cam='3' then heldCamera3=heldCamera3+1
      else heldTemporal2=heldTemporal2+1
      if scene='cruise' & score<minPos then minPos=score
      if scene='baseline' & score>maxNeg then maxNeg=score
    end
    pred~append(cam||'|'||scene||'|'||frame||'|'||r['SOURCE']||'|'||r['CROP']||'|'||r['BRIGHT']||'|'||r['HEDGE']||'|'||r['VEDGE']||'|'||format(score,3,8)||'|'||format(threshold,3,8)||'|'||claim||'|'||role||'|OBSERVED_UNTESTED')
   end
  end
 end
if heldCamera3<>14 | heldTemporal2<>12 then call fail 'invalid train/heldout partition'
/* Complete qualification is not classifier certification. Scores and outcomes
 * remain IMAGE_OBSERVATION-only; video source classes are human-reviewed.
 */
call stream output,'c','open write replace'
call lineout output,'camera|source_scene|frame|original_source_sha256|crop_rgb24_sha256|bright160_lower_half|horizontal_edges_lower_half|vertical_edges_lower_half|structure_score|training_midpoint|decision|evaluation_partition|evidence_state'
do line over pred
 call lineout output,line
end
call stream output,'c','close'
say 'SYDNEY STRUCTURE BRIDGE PASS source_rows=' || count || ' train_rows=2 heldout=' || (heldCorrect+heldWrong+heldAbstain)
say 'HELDOUT correct=' || heldCorrect || ' wrong=' || heldWrong || ' abstain=' || heldAbstain || ' cam3=' || heldCamera3 || ' cam2_temporal=' || heldTemporal2
say 'SCORE threshold=' || threshold || ' margin=' || margin || ' min_heldout_ship=' || minPos || ' max_heldout_normal=' || maxNeg
say 'STATUS=OBSERVED_UNTESTED; CAMERA_SITE_SPECIFIC; NOT_INDEPENDENT_RECORDINGS; NO_SHIP_IDENTITY_OR_SLAM_TESTED_EDGES'
exit 0
countPipes: procedure
 use arg t
 n=0
 do i=1 to length(t)
  if substr(t,i,1)=='|' then n=n+1
 end
 return n
fail: procedure
 use arg err
 say 'V030_EVIDENCE_REJECT:' err
 exit 3
