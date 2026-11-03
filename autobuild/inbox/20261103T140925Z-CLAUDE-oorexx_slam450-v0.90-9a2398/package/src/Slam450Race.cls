/* SLAM450 v0.6 two-aircraft race referee. Architecture: Tom Dyer.
 * Aircraft receive their OWN indexed onboard panorama, private memories,
 * restricted airflow packets and public claims only. Referee contains all
 * model XYZ, exact wind, swept collision and interception timestamps.
 * Neither pilot has a reference to this object.
 */
::requires 'Slam450Flight.cls'

::class Slam450RaceReferee public
::attribute world get
::attribute tick get
::attribute status get
::attribute claims get
::attribute events get
::attribute lastPackets get
::attribute lastWind get
::attribute lastHit get
::attribute minSeparation get
::method init
  expose world tick status claims events poses lastPackets lastWind lastHit windField minSeparation
  use strict arg scenario,windOn=.true
  world=scenario
  tick=0;status='RUNNING';lastHit='';claims=.directory~new
  events=.array~new;lastPackets=.directory~new;lastWind=.directory~new
  windField=.nil
  if windOn then windField=.Slam450WindField~new(world~seed+904)
  /* Referee-only initial placement: A1 is 10 m nearer the first target.
     Both craft receive their onboard image, not this placement rule. */
  first=world~targets[1];start=world~pose
  dx=start[1]-first[1];dy=start[2]-first[2]
  rr=HSqrt(dx*dx+dy*dy)
  if rr<0.1 then raise syntax 88.900 array('invalid race starting geometry')
  a=.array~of(start[1],start[2],start[3],start[4])
  b=.array~of(start[1]+10*dx/rr,start[2]+10*dy/rr,start[3],start[4])
  if \world~safePoint(a,2.2) | \world~safePoint(b,2.2) then ,
    raise syntax 88.900 array('unsafe race start')
  if world~distance(a,b)<9.999 then raise syntax 88.900 array('race start must be 10m')
  poses=.directory~new;poses['A1']=a;poses['A2']=b
  minSeparation=world~distance(a,b)
::method poseOf
  expose poses
  use strict arg id
  if \poses~hasIndex(id) then raise syntax 88.900 array('unknown craft')
  return poses[id]
::method available
  expose claims
  use strict arg target
  if target<1 | target>5 then return .false
  return \claims~hasIndex(target)
::method nextAvailable
  expose claims
  use strict arg after=0
  do i=after+1 to 5
    if \claims~hasIndex(i) then return i
  end
  return 0
::method contactFraction
  /* First time the swept centre enters the target capture sphere. */
  use strict arg a,b,p,radius=2.5
  dx=b[1]-a[1];dy=b[2]-a[2];dz=b[3]-a[3]
  px=a[1]-p[1];py=a[2]-p[2];pz=a[3]-p[3]
  A=dx*dx+dy*dy+dz*dz
  C=px*px+py*py+pz*pz-radius*radius
  if C<=0 then return 0
  if A<0.00000001 then return -1
  B=2*(px*dx+py*dy+pz*dz)
  disc=B*B-4*A*C
  if disc<0 then return -1
  t=(-B-HSqrt(disc))/(2*A)
  if t<0 | t>1 then return -1
  return t
::method closestConcurrent
  use strict arg a,b,c,d
  /* Relative swept motion; both craft move across the SAME time interval. */
  rx=a[1]-c[1];ry=a[2]-c[2];rz=a[3]-c[3]
  vx=(b[1]-a[1])-(d[1]-c[1])
  vy=(b[2]-a[2])-(d[2]-c[2])
  vz=(b[3]-a[3])-(d[3]-c[3])
  sq=vx*vx+vy*vy+vz*vz
  t=0
  if sq>0.00000001 then t=max(0,min(1,-(rx*vx+ry*vy+rz*vz)/sq))
  return HSqrt((rx+t*vx)**2+(ry+t*vy)**2+(rz+t*vz)**2)
::method candidate private
  use strict arg old,command,wind
  yaw=max(-25,min(25,command[1]))
  fwd=max(-3,min(7,command[2]))
  climb=max(-4,min(4,command[3]))
  side=0
  if command~items>=4 then side=max(-3,min(3,command[4]))
  heading=old[4]+yaw
  do while heading<0;heading+=360;end
  do while heading>=360;heading-=360;end
  e=fwd*RxCalcSin(heading)+side*RxCalcCos(heading)
  n=fwd*RxCalcCos(heading)-side*RxCalcSin(heading)
  windE=0;windN=0
  if wind\==.nil then do
    windE=wind['EAST_MPS'];windN=wind['NORTH_MPS']
  end
  next=.array~of(old[1]+e+0.45*windE,old[2]+n+0.45*windN,old[3]+climb,heading)
  packet=.nil
  if wind\==.nil then packet=(.Slam450AirflowInstruments~new)~sample(,
    e-0.55*windE,n-0.55*windN,heading,wind['LEVEL'])
  return .array~of(next,packet)
::method advance
  expose world tick status claims events poses lastPackets lastWind lastHit windField minSeparation
  use strict arg cmd1,cmd2
  if status\=='RUNNING' then return .array~new
  old1=poses['A1'];old2=poses['A2']
  w1=.nil;w2=.nil
  if windField\==.nil then do
    w1=windField~advance(old1[3],tick+1)
    if windField~levelAt(old2[3])==windField~levelAt(old1[3]) then w2=w1
    else w2=windField~advance(old2[3],tick+1)
  end
  p1=self~candidate(old1,cmd1,w1);p2=self~candidate(old2,cmd2,w2)
  new1=p1[1];new2=p2[1]
  if \world~safeLine(old1,new1) | \world~safePoint(new1,2) then do
    status='COLLISION';lastHit='A1_SCENE';return .array~new
  end
  if \world~safeLine(old2,new2) | \world~safePoint(new2,2) then do
    status='COLLISION';lastHit='A2_SCENE';return .array~new
  end
  gap=self~closestConcurrent(old1,new1,old2,new2)
  minSeparation=min(minSeparation,gap)
  if gap<4 then do
    status='COLLISION';lastHit='AIRCRAFT_SEPARATION';return .array~new
  end
  tick+=1
  poses['A1']=new1;poses['A2']=new2
  lastPackets['A1']=p1[2];lastPackets['A2']=p2[2]
  lastWind['A1']=w1;lastWind['A2']=w2
  arrivals=.array~new
  do num=1 to 5
    if claims~hasIndex(num) then iterate
    target=world~targets[num]
    t1=self~contactFraction(old1,new1,target)
    t2=self~contactFraction(old2,new2,target)
    if t1<0 & t2<0 then iterate
    who='A1';time=t1
    if t1<0 | (t2>=0 & t2<t1) then do
      who='A2';time=t2
    end
    /* Exact simultaneous entry is explicitly audited; deterministic
     * alternate arbitration prevents permanent systematic A1 bias. */
    tie='NONE'
    if t1>=0 & t2>=0 & abs(t1-t2)<0.00000001 then do
      tie='SIMULTANEOUS_ENTRY'
      if num//2==0 then who='A2'
    end
    claims[num]=who
    event=.directory~new
    event['STEP']=tick;event['TARGET']=num;event['WINNER']=who
    event['INTERCEPT_FRACTION']=time;event['TIE']=tie
    arrivals~append(event);events~append(event)
  end
  if claims~items==5 then status='COMPLETE'
  return arrivals

::class Slam450RaceCameraService public
::attribute grants get
::attribute denies get
::attribute lastGrant get
::attribute views get
::method init
  expose grants denies lastGrant views camera panorama
  use strict arg world
  grants=0;denies=0;lastGrant=0
  camera=.Slam450Camera~new(world)
  panorama=.HarbourOcclusionPanorama~new
  panorama~configure
  views=.array~of('CAFE_SYDNEY','OPERA_WEST_WALK','KIRRIBILLI','NORTH_PTZ','BLUES_PT')
::method request
  expose grants denies lastGrant views camera panorama
  use strict arg id,view,step,claimed,ownPose,rivalPose
  answer=.directory~new;answer['STATUS']='DENIED';answer['REASON']=''
  if id\=='A1' & id\=='A2' then raise syntax 88.900 array('invalid caller')
  allowed=.false
  do name over views
    if name==view then allowed=.true
  end
  if \allowed then do;denies+=1;answer['REASON']='UNKNOWN_CAMERA';return answer;end
  if step<5 | step-lastGrant<5 then do
    denies+=1;answer['REASON']='GLOBAL_FIVE_STEP_LIMIT';return answer
  end
  lastGrant=step;grants+=1
  fixed=panorama~siteCamera(view)
  eye=.array~of(fixed[1],fixed[2],fixed[3],0)
  answer['FRAME']=camera~renderAt(eye,480,121,.true,claimed,rivalPose,ownPose)
  answer['STATUS']='GRANTED';answer['REASON']='ONE_FIXED_PANORAMA'
  return answer
