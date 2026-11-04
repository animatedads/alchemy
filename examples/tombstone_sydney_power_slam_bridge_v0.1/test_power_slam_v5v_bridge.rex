/* Native r13196 additive seam test against 12 actual source crop receipts.
 * Synthetic inversions are NOT proof of the real camera's world pose.
 */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg input
if input=='' then input='observations.psv'
checks=0
b=.PowerSlamV5VBridge~new
n=b~load(input)
call check n=12,'12 actual reviewed source observations admitted'
obs=b~observations
count2=0;count3=0
last2=-1;last3=-1
first2=.nil;first3=.nil
do o over obs
  if o['CAMERA']='2' then do
    count2+=1
    call check o['FRAME']>last2,'source 2 monotonic frame'
    last2=o['FRAME']
    if first2==.nil then first2=o
  end
  else do
    count3+=1
    call check o['FRAME']>last3,'source 3 monotonic frame'
    last3=o['FRAME']
    if first3==.nil then first3=o
  end
  call check o['WORLD']=='BLOCKED_UNCALIBRATED','no inferred world location'
  call check o['IDENTITY']=='CROSS_CAMERA_HYPOTHESIS_UNVERIFIED','no inferred vessel identity'
end
call check count2=6 & count3=6,'both source streams present'
cell2=b~v5vCellCentre('2',40,20)
cell3=b~v5vCellCentre('3',40,20)
call check cell2[1]=648 & cell3[1]=324,'V5V cell source resolution scales by camera'
call check cell2[2]=328 & cell3[2]=164,'V5V cell height scales by camera'
call check b~worldIntersection(first3,.array~of(0,0,30,0,0,900),0,'UNVERIFIED')=='BLOCKED_UNCALIBRATED','real geographic output blocked'
call check b~worldIntersection(first3,.array~of(0,0,30,0,0,900),0,'POWER_SLAM_SURVEYED_POSE_CERTIFICATE_UNIMPLEMENTED')=='BLOCKED_NO_POSE_CERTIFICATE_VERIFIER','cannot bypass missing pose verifier'
/* Forward pinhole camera -> inverse ray on a SYNTHETIC known plane point. */
f=.HarbourPerspectiveFit~new
pose=.array~of(10,20,30,18,-3,1400)
world=.array~of(110,380,0)
px=f~project(world,pose,640,360)
call check px\==.nil,'synthetic known point is in front of candidate camera'
syn=.directory~new
syn['X']=px[1];syn['Y']=px[2];syn['WIDTH']=640;syn['HEIGHT']=360
syn['CAMERA']='3';syn['FRAME']=0;syn['EVIDENCE']='OBSERVED_UNTESTED'
ray=b~diagnosticRay(syn,pose)
vector=ray['VECTOR']
call check vector[3]<0,'synthetic ray looks downward at water plane'
k=(world[3]-pose[3])/vector[3]
predE=pose[1]+k*vector[1];predN=pose[2]+k*vector[2]
call check abs(predE-world[1])<0.000001,'synthetic inverse east matches Power SLAM project'
call check abs(predN-world[2])<0.000001,'synthetic inverse north matches Power SLAM project'
call check ray['STATUS']=='DIAGNOSTIC_UNCALIBRATED_RAY','ray remains non-authoritative'
call check n=obs~items,'12 validated observations retained'
outfile='power_slam_v5v_candidates.psv'
call check b~exportCandidates(outfile)=12,'12 fail-closed camera/SLAM seam rows exported'
call stream outfile,'C','OPEN READ'
countOutput=0
do while lines(outfile)>0
  exported=linein(outfile)
  countOutput+=1
end
call stream outfile,'C','CLOSE'
call check countOutput=13,'12 plus one header written'
say 'POWER SLAM / V5V OBSERVATION BRIDGE PASS ('checks' checks); WORLD=BLOCKED_UNCALIBRATED; IDENTITY=UNVERIFIED'
exit 0
check: procedure expose checks
  use arg ok,why
  if \ok then do
    say 'FAIL:' why
    exit 3
  end
  checks+=1
  return
::requires 'PowerSlamV5VBridge.cls'
::requires 'SlamHarbourPerspectiveFit.cls'
