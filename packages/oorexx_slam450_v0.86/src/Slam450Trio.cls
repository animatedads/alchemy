/* SLAM450 v0.6 two-aircraft race referee. Architecture: Tom Dyer.
 * Aircraft receive their OWN indexed onboard panorama, private memories,
 * restricted airflow packets and public claims only. Referee contains all
 * model XYZ, exact wind, swept collision and interception timestamps.
 * Neither pilot has a reference to this object.
 */
::requires 'Slam450Flight.cls'
::requires 'Slam450Battery.cls'

::class Slam450TrioReferee public
::attribute world get
::attribute tick get
::attribute status get
::attribute claims get
::attribute events get
::attribute lastPackets get
::attribute lastWind get
::attribute lastHit get
::attribute minSeparation get
::attribute batteryEnabled get
::method init
  expose world tick status claims events poses lastPackets lastWind lastHit windField minSeparation batteryEnabled batteries
  use strict arg scenario,windOn=.true,batteryOn=.false
  world=scenario
  tick=0;status='RUNNING';lastHit='';claims=.directory~new
  events=.array~new;lastPackets=.directory~new;lastWind=.directory~new
  batteryEnabled=batteryOn;batteries=.directory~new
  if batteryEnabled then do
    do id over .array~of('A1','A2','A3');batteries[id]=.Slam450Battery~new;end
  end
  windField=.nil
  if windOn then windField=.Slam450WindField~new(world~seed+904)
  /* Three distinct physical craft start together, at pairwise 10m spacing.
   * Private simulator poses never enter pilot or buddy radio objects. */
  first=world~targets[1];start=world~pose
  dx=start[1]-first[1];dy=start[2]-first[2]
  rr=HSqrt(dx*dx+dy*dy)
  if rr<0.1 then raise syntax 88.900 array('invalid triple start')
  ux=dx/rr;uy=dy/rr
  a=.array~of(start[1],start[2],start[3],start[4])
  b=.array~of(start[1]+10*ux,start[2]+10*uy,start[3],start[4])
  /* Equilateral triangle with two orientations; accept safe one. */
  c=.array~of(start[1]+5*ux-8.660254037844386*uy,,
     start[2]+5*uy+8.660254037844386*ux,start[3],start[4])
  if \world~safePoint(c,2.2) then c=.array~of(,
     start[1]+5*ux+8.660254037844386*uy,,
     start[2]+5*uy-8.660254037844386*ux,start[3],start[4])
  if \world~safePoint(a,2.2) | \world~safePoint(b,2.2) | \world~safePoint(c,2.2) then ,
    raise syntax 88.900 array('unsafe triple start')
  poses=.directory~new
  poses['A1']=a;poses['A2']=b;poses['A3']=c
  minSeparation=min(world~distance(a,b),world~distance(a,c),world~distance(b,c))
  if abs(minSeparation-10)>0.00001 then raise syntax 88.900 array('start triangle spacing')
::method batteryReport
  expose batteryEnabled batteries
  use strict arg id
  if \batteryEnabled then raise syntax 88.900 array('battery disabled on this referee')
  if \batteries~hasIndex(id) then raise syntax 88.900 array('unknown craft meter')
  return batteries[id]~report
::method debitRadio
  expose batteryEnabled batteries
  use strict arg id
  if \batteryEnabled then return .true
  if \batteries~hasIndex(id) then return .false
  b=batteries[id]
  return b~debit('RADIO',b~radioCost)
::method debitRemote
  expose batteryEnabled batteries
  use strict arg id
  if \batteryEnabled then return .true
  if \batteries~hasIndex(id) then return .false
  b=batteries[id]
  return b~debit('LOOKUP',b~remoteCost)
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
  expose world tick status claims events poses lastPackets lastWind lastHit windField minSeparation batteryEnabled batteries
  use strict arg cmd1,cmd2,cmd3
  if status\=='RUNNING' then return .array~new
  ids=.array~of('A1','A2','A3')
  cmds=.directory~new
  cmds['A1']=cmd1;cmds['A2']=cmd2;cmds['A3']=cmd3
  before=.directory~new;after=.directory~new
  windPackets=.directory~new;sensorPackets=.directory~new
  windsByLevel=.directory~new
  prices=.directory~new
  if batteryEnabled then do
    do id over ids
      q=batteries[id]~quote(cmds[id])
      prices[id]=q['TOTAL']
      if \batteries[id]~affordable(prices[id]) then do
        status='POWER_STOP';lastHit=id||'_BATTERY';return .array~new
      end
    end
  end
  do id over ids
    p=poses[id];before[id]=p
    wind=.nil
    if windField\==.nil then do
      level=windField~levelAt(p[3])
      if windsByLevel~hasIndex(level) then wind=windsByLevel[level]
      else do
        wind=windField~advance(p[3],tick+1)
        windsByLevel[level]=wind
      end
    end
    movement=self~candidate(p,cmds[id],wind)
    after[id]=movement[1];sensorPackets[id]=movement[2]
    windPackets[id]=wind
    if \world~safeLine(p,after[id]) | \world~safePoint(after[id],2) then do
      status='COLLISION';lastHit=id||'_SCENE';return .array~new
    end
  end
  do i=1 to ids~items-1
    do j=i+1 to ids~items
      first=ids[i];second=ids[j]
      gap=self~closestConcurrent(before[first],after[first],before[second],after[second])
      minSeparation=min(minSeparation,gap)
      if gap<4 then do
        status='COLLISION';lastHit=first||'_'||second||'_SEPARATION'
        return .array~new
      end
    end
  end
  if batteryEnabled then do
    do id over ids;ignored=batteries[id]~debit('FLIGHT',prices[id]);end
  end
  tick+=1
  poses=after;lastPackets=sensorPackets;lastWind=windPackets
  arrivals=.array~new
  do num=1 to 5
    if claims~hasIndex(num) then iterate
    target=world~targets[num]
    winner='';time=2;tie='NONE'
    do id over ids
      fraction=self~contactFraction(before[id],after[id],target)
      if fraction<0 then iterate
      if abs(fraction-time)<0.00000001 then do
        tie='SIMULTANEOUS_ENTRY'
        /* Tie order rotates across target IDs, never a permanent lead. */
        if ((num+id~substr(2,1))//3)<((num+winner~substr(2,1))//3) then winner=id
      end
      else if fraction<time then do
        time=fraction;winner=id;tie='NONE'
      end
    end
    if winner=='' then iterate
    claims[num]=winner
    event=.directory~new
    event['STEP']=tick;event['TARGET']=num;event['WINNER']=winner
    event['INTERCEPT_FRACTION']=time;event['TIE']=tie
    arrivals~append(event);events~append(event)
  end
  if claims~items==5 then status='COMPLETE'
  return arrivals

::class Slam450TrioCameraService public
::attribute grants get
::attribute denies get
::attribute lastGrant get
::attribute views get
::method init
  expose grants denies lastGrant views camera panorama flexible lastByID batteryAuthority
  use strict arg world,flexibleAccess=.false,authority=.nil
  flexible=flexibleAccess;lastByID=.directory~new;batteryAuthority=authority
  grants=0;denies=0;lastGrant=0
  camera=.Slam450Camera~new(world)
  panorama=.HarbourOcclusionPanorama~new
  panorama~configure
  views=.array~of('CAFE_SYDNEY','OPERA_WEST_WALK','KIRRIBILLI','NORTH_PTZ','BLUES_PT')
::method request
  expose grants denies lastGrant views camera panorama flexible lastByID batteryAuthority
  use strict arg id,view,step,claimed,ownPose,rivalPose
  answer=.directory~new;answer['STATUS']='DENIED';answer['REASON']=''
  if id\=='A1' & id\=='A2' & id\=='A3' then raise syntax 88.900 array('invalid caller')
  allowed=.false
  do name over views
    if name==view then allowed=.true
  end
  if \allowed then do;denies+=1;answer['REASON']='UNKNOWN_CAMERA';return answer;end
  if flexible then do
    if lastByID~hasIndex(id) then do
      if lastByID[id]==step then do
        denies+=1;answer['REASON']='ONE_REQUEST_PER_CRAFT_PER_TURN';return answer
      end
    end
  end
  else do
    if step<5 | step-lastGrant<5 then do
      denies+=1;answer['REASON']='GLOBAL_FIVE_STEP_LIMIT';return answer
    end
  end
  /* Charge on the server boundary, after validation but before rendering. */
  if batteryAuthority\==.nil then do
    if \batteryAuthority~debitRemote(id) then do
      denies+=1;answer['REASON']='DENIED_LOW_BATTERY';return answer
    end
  end
  if flexible then lastByID[id]=step
  lastGrant=step;grants+=1
  fixed=panorama~siteCamera(view)
  eye=.array~of(fixed[1],fixed[2],fixed[3],0)
  answer['FRAME']=camera~renderAt(eye,480,121,.true,claimed,rivalPose,ownPose)
  answer['STATUS']='GRANTED';answer['REASON']='ONE_FIXED_PANORAMA'
  return answer
