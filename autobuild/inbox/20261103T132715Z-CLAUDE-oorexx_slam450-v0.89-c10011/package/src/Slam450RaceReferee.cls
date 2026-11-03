/* SLAM 450 shared-world duel referee.
 * Simultaneous aircraft motion, real swept safety, first-to-hit claim, shared
 * target removal, and exactly one common 5-step fixed-camera throttle.
 * Controllers get only their own rendered frames, restricted sensor packets,
 * public claim events. Referee's poses, targets, wind vector remain private.
 */
::requires 'Slam450RaceTactics.cls'

::class Slam450RaceReferee public
::attribute world get
::attribute clock get
::attribute claimed get
::attribute events get
::attribute status get
::attribute fixedRequests get
::method init
  expose world clock poseA poseB claimed events status windOn windField camera fixedRequests fixedLast fixedUsed sensorA sensorB
  use strict arg courseSeed=45042,mode='LOOP',withWind=.false
  world=.Slam450World~new(courseSeed,mode,.false)
  windOn=withWind;windField=.nil
  if windOn then windField=.Slam450WindField~new(courseSeed)
  /* Both launch simultaneously, separated by 10.000 metres. */
  base=world~pose
  poseA=.array~of(base[1]-5,base[2],base[3],base[4])
  poseB=.array~of(base[1]+5,base[2],base[3],base[4])
  if \world~safePoint(poseA,2.5) | \world~safePoint(poseB,2.5) then ,
     raise syntax 88.900 array('race launch aircraft intersects structure')
  clock=0;claimed=.directory~new;events=.array~new
  status=.directory~new;status['A1']='FLYING';status['A2']='FLYING'
  camera=.Slam450Camera~new(world)
  fixedLast=0;fixedUsed=.false;fixedRequests=0
  sensorA=.nil;sensorB=.nil
::method ownPose private
  expose poseA poseB
  use strict arg aircraftID
  if aircraftID=='A1' then return poseA
  if aircraftID=='A2' then return poseB
  raise syntax 88.900 array('unknown aircraft')
::method frame
  expose camera claimed
  use strict arg aircraftID,width=720,height=181
  if aircraftID=='A1' then other='A2'
  else if aircraftID=='A2' then other='A1'
  else raise syntax 88.900 array('invalid aircraft frame request')
  own=self~ownPose(aircraftID);rival=self~ownPose(other)
  return camera~renderAt(own,width,height,.false,claimed,rival)
::method sensors
  expose sensorA sensorB
  use strict arg aircraftID
  if aircraftID=='A1' then return sensorA
  if aircraftID=='A2' then return sensorB
  raise syntax 88.900 array('bad sensor recipient')
::method requestFixed
  expose world clock fixedLast fixedUsed fixedRequests camera claimed
  use strict arg aircraftID,cameraID
  r=.directory~new;r['STEP']=clock;r['CAMERA']=cameraID;r['STATUS']='DENIED'
  if aircraftID\=='A1' & aircraftID\=='A2' then do
    r['REASON']='BAD_AIRCRAFT';return r
  end
  if clock-fixedLast<5 | fixedUsed then do
    r['REASON']='SHARED_FIVE_STEP_LIMIT';return r
  end
  /* A fixed-camera request never moves that camera, and the first request
   * by either aircraft consumes this cycle's one global slot. */
  valid=.false
  do name over .array~of('CAFE_SYDNEY','OPERA_WEST_WALK','KIRRIBILLI','NORTH_PTZ','BLUES_PT')
    if name==cameraID then valid=.true
  end
  if \valid then do;r['REASON']='UNKNOWN_STATIONARY_CAMERA';return r;end
  pano=.HarbourOcclusionPanorama~new
  pano~configure
  pt=pano~siteCamera(cameraID)
  fixedPose=.array~of(pt[1],pt[2],pt[3],0)
  r['FRAME']=camera~renderAt(fixedPose,720,181,.false,claimed)
  r['STATUS']='GRANTED';r['REASON']='ONE_FIXED_PANORAMA'
  fixedLast=clock;fixedUsed=.true;fixedRequests+=1
  return r
::method propose private
  expose world windOn
  use strict arg pose,command,wind
  if command~items<3 then raise syntax 88.900 array('incomplete flight controls')
  yaw=max(-25,min(25,command[1]));forward=max(-3,min(7,command[2]))
  climb=max(-4,min(4,command[3]));side=0
  if command~items>=4 then side=max(-3,min(3,command[4]))
  hdg=pose[4]+yaw
  do while hdg<0;hdg+=360;end
  do while hdg>=360;hdg-=360;end
  de=forward*RxCalcSin(hdg)+side*RxCalcCos(hdg)
  dn=forward*RxCalcCos(hdg)-side*RxCalcSin(hdg)
  if windOn then do
    de+=0.45*wind['EAST_MPS'];dn+=0.45*wind['NORTH_MPS']
  end
  return .array~of(pose[1]+de,pose[2]+dn,pose[3]+climb,hdg)
::method firstContact private
  use strict arg before,after,point,radius=2.5
  dx=after[1]-before[1];dy=after[2]-before[2];dz=after[3]-before[3]
  ax=before[1]-point[1];ay=before[2]-point[2];az=before[3]-point[3]
  a=dx*dx+dy*dy+dz*dz;b=2*(ax*dx+ay*dy+az*dz)
  c=ax*ax+ay*ay+az*az-radius*radius
  if c<=0 then return 0
  if a<0.000000001 then return -1
  disc=b*b-4*a*c
  if disc<0 then return -1
  t=(-b-HSqrt(disc))/(2*a)
  if t>=0 & t<=1 then return t
  return -1
::method crossing private
  /* Minimum separation of two moving aircraft during this SAME tick. */
  use strict arg beforeA,afterA,beforeB,afterB
  rx=beforeA[1]-beforeB[1];ry=beforeA[2]-beforeB[2];rz=beforeA[3]-beforeB[3]
  vx=(afterA[1]-beforeA[1])-(afterB[1]-beforeB[1])
  vy=(afterA[2]-beforeA[2])-(afterB[2]-beforeB[2])
  vz=(afterA[3]-beforeA[3])-(afterB[3]-beforeB[3])
  a=vx*vx+vy*vy+vz*vz
  t=0
  if a>0.000000001 then t=max(0,min(1,0-(rx*vx+ry*vy+rz*vz)/a))
  return HSqrt((rx+t*vx)**2+(ry+t*vy)**2+(rz+t*vz)**2)
::method stepBoth
  expose world clock poseA poseB claimed events status windOn windField sensorA sensorB fixedUsed
  use strict arg commandA,commandB
  /* Referee evaluates both from same instant before committing either. */
  if status['A1']\=='FLYING' | status['A2']\=='FLYING' then return 'RACE_STOPPED'
  oldA=poseA;oldB=poseB
  wA=.nil;wB=.nil
  if windOn then do
    wA=windField~advance(oldA[3],clock+1)
    if windField~levelAt(oldA[3])==windField~levelAt(oldB[3]) then wB=wA
    else wB=windField~advance(oldB[3],clock+1)
  end
  candidateA=self~propose(oldA,commandA,wA)
  candidateB=self~propose(oldB,commandB,wB)
  if \world~safeLine(oldA,candidateA) | \world~safePoint(candidateA,2.5) then do
    status['A1']='COLLISION_WITH_SCENE';return 'COLLISION_WITH_SCENE_A1'
  end
  if \world~safeLine(oldB,candidateB) | \world~safePoint(candidateB,2.5) then do
    status['A2']='COLLISION_WITH_SCENE';return 'COLLISION_WITH_SCENE_A2'
  end
  /* Approximate 2m radius per craft + safety buffer of 1m. */
  if self~crossing(oldA,candidateA,oldB,candidateB)<5 then do
    status['A1']='AIRCRAFT_SEPARATION_VIOLATION'
    status['A2']='AIRCRAFT_SEPARATION_VIOLATION'
    return 'AIRCRAFT_SEPARATION_VIOLATION'
  end
  poseA=candidateA;poseB=candidateB;clock+=1;fixedUsed=.false
  if windOn then do
    s=.Slam450AirflowInstruments~new
    sensorA=s~sample(candidateA[1]-oldA[1]-wA['EAST_MPS'],,
       candidateA[2]-oldA[2]-wA['NORTH_MPS'],candidateA[4],wA['LEVEL'])
    sensorB=s~sample(candidateB[1]-oldB[1]-wB['EAST_MPS'],,
       candidateB[2]-oldB[2]-wB['NORTH_MPS'],candidateB[4],wB['LEVEL'])
  end
  /* First physical contact within the SAME tick wins. Both target order and
   * claim eligibility are independent: an aircraft can anticipate #2. */
  do i=1 to world~targets~items
    if claimed~hasIndex(i) then iterate
    target=world~targets[i]
    at=self~firstContact(oldA,candidateA,target)
    bt=self~firstContact(oldB,candidateB,target)
    if at<0 & bt<0 then iterate
    winner='A1';time=at
    if at<0 | (bt>=0 & bt<at) then do;winner='A2';time=bt;end
    if at>=0 & bt>=0 & abs(at-bt)<0.0000001 then do
      e=.directory~new;e['STEP']=clock;e['TARGET']=i
      e['WINNER']='NONE';e['STATUS']='EXACT_SIMULTANEOUS_TIE'
      events~append(e)
      iterate
    end
    claimed[i]=winner
    e=.directory~new;e['STEP']=clock;e['TARGET']=i
    e['WINNER']=winner;e['TIME_WITHIN_STEP']=time;e['STATUS']='CLAIMED_AND_REMOVED'
    events~append(e)
  end
  if claimed~items==world~targets~items then do
    status['A1']='FINISHED';status['A2']='FINISHED'
    return 'ALL_TARGETS_CLAIMED'
  end
  return 'RUNNING'
::method result
  expose claimed status events clock
  r=.directory~new;r['STEP']=clock;r['CLAIMS']=claimed~items
  r['EVENTS']=events;r['A1_STATUS']=status['A1'];r['A2_STATUS']=status['A2']
  return r

::method oracleSnapshot
  expose poseA poseB clock claimed
  /* RECORDER ONLY. Never pass this return value to either pilot or memory. */
  d=.directory~new;d['STEP']=clock
  d['A1']=poseA~copy;d['A2']=poseB~copy;d['CLAIM_COUNT']=claimed~items
  return d
