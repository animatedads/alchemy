/* SLAM 450: camera-only synthetic flight on the Power SLAM harbour cuboids.
 * Architecture: Tom Dyer. ooRexx implementation: ChatGPT GPT-6, 2026-11-03.
 * Training-policy input is an indexed colour panorama, NEVER the world state.
 * World position and collision truth are owned by the independent simulator.
 * Scene dependency: PowerSLAM v0.40, including v0.39 quay relocation.
 * Ground/shoreline are NOT surveyed/complete: synthetic-model safety only.
 */
::requires 'SlamHarbourOcclusion.cls'
::requires 'Slam450Wind.cls'
::requires 'MathFastLanes.cls'

::class Slam450World public
::attribute scene get
::attribute targets get
::attribute pose get
::attribute active get
::attribute status get
::attribute seed get
::attribute lastHit get
::attribute steps get
::attribute routeMode get
::attribute courseAreas get
::attribute collisionBounds get
::attribute windEnabled get
::attribute lastWindTruth get
::attribute lastSensorPacket get
::method init
  expose scene targets pose active status seed lastHit steps routeMode courseAreas collisionBounds windEnabled windField lastWindTruth lastSensorPacket lastAirE lastAirN
  use strict arg rnd=45042,selectedMode='LEGACY',useWind=.false
  windEnabled=useWind;windField=.nil;lastWindTruth=.nil;lastSensorPacket=.nil
  lastAirE=0;lastAirN=0
  if windEnabled then windField=.Slam450WindField~new(rnd)
  p=.HarbourOcclusionPanorama~new
  p~configure
  scene=p~scene
  /* Conservative AABB broad-phase only: final collision test remains the
   * unmodified PowerSLAM native oriented-cuboid segment intersection. */
  collisionBounds=.array~new
  do b over scene~boxes
    xlo=1e20;xhi=-1e20;ylo=1e20;yhi=-1e20;zlo=1e20;zhi=-1e20
    do v over b[2]
      xlo=min(xlo,v[1]);xhi=max(xhi,v[1])
      ylo=min(ylo,v[2]);yhi=max(yhi,v[2])
      zlo=min(zlo,v[3]);zhi=max(zhi,v[3])
    end
    collisionBounds~append(.array~of(b,xlo,xhi,ylo,yhi,zlo,zhi))
  end
  targets=.array~new
  seed=rnd
  /* This entire target generator is simulator-private. The pilot receives
   * just rendered colour/shade pixels and the current requested shade.
   * Region names are for oracle reporting, not steering or localisation.
   */
  routeMode=selectedMode~upper
  courseAreas=.array~new
  if routeMode=='LEGACY' then do
    do i=1 to 5
      accepted=.false
      do tries=1 to 500
        x=160+240*self~random
        y=-820+420*self~random
        z=10+140*self~random
        candidate=.array~of(x,y,z)
        if \self~safePoint(candidate,2.2) then iterate
        if targets~items>0 then do
          old=targets[targets~items]
          if self~distance(old,candidate)<65 then iterate
          if \self~safeLine(old,candidate) then iterate
        end
        targets~append(candidate);courseAreas~append('LEGACY');accepted=.true;leave
      end
      if \accepted then raise syntax 88.900 array('legacy waypoint generation exhausted')
    end
  end
  else if routeMode=='OBSTRUCTED' then do
    /* Deliberately held-out route: leg 2 must be occluded by the existing
     * Salesforce tower. The scene is NOT changed or moved. Five target
     * locations are seeded; none is leaked to the pilot. This is a harder
     * obstacle-recovery test, NOT an independently surveyed Sydney flight. */
    courseAreas=.array~of('QUAY','BEHIND_TOWER','BRIDGE','OPERA','QUAY_RETURN')
    found=.false
    do trial=1 to 100
      first=.array~of(160+(self~random-0.5)*14,,
          -820+(self~random-0.5)*14,68+(self~random-0.5)*8)
      second=.array~of(-250+(self~random-0.5)*14,,
          -1300+(self~random-0.5)*14,78+(self~random-0.5)*8)
      if \self~safePoint(first,3) | \self~safePoint(second,3) then iterate
      if self~safeLine(first,second) then iterate
      if .HarbourRayOcclusion~firstHit(scene,first,second)\=='SALESFORCE' then iterate
      targets~append(first);targets~append(second);found=.true;leave
    end
    if \found then raise syntax 88.900 array('no seeded obstructed tower leg generated')
    do p over .array~of(.array~of(80,-150,127),,
            .array~of(400,-555,95),.array~of(235,-800,94))
      if \self~safePoint(p,3) then raise syntax 88.900 array('blocked reserved course point')
      targets~append(p)
    end
  end
  else do
    regions=.array~of('QUAY','BRIDGE','OPERA','BLUES')
    if routeMode=='LOOP' then do
      courseAreas=.array~of('QUAY','BRIDGE','OPERA','BLUES','QUAY')
    end
    else if routeMode=='WIDE' then do
      /* Fisher-Yates, seeded and reproducible, with a revisit fifth.
       * The route can double back; no straight-line LOS is demanded. */
      do i=4 to 2 by -1
        j=1+trunc(i*self~random)
        temp=regions[i];regions[i]=regions[j];regions[j]=temp
      end
      do i=1 to 4;courseAreas~append(regions[i]);end
      courseAreas~append(regions[1])
    end
    else raise syntax 88.900 array('unknown SLAM450 course mode')
    do i=1 to 5
      area=courseAreas[i]
      select
        when area=='QUAY' then do
          baseX=160;baseY=-820;loZ=38;hiZ=98
        end
        when area=='BRIDGE' then do
          baseX=35;baseY=-150;loZ=90;hiZ=145
        end
        when area=='OPERA' then do
          baseX=400;baseY=-555;loZ=48;hiZ=105
        end
        when area=='BLUES' then do
          baseX=-445;baseY=170;loZ=104;hiZ=145
        end
      end
      accepted=.false
      do tries=1 to 700
        x=baseX+(self~random-0.5)*95
        y=baseY+(self~random-0.5)*95
        z=loZ+(hiZ-loZ)*self~random
        candidate=.array~of(x,y,z)
        if \self~safePoint(candidate,3) then iterate
        /* Revisit the AREA, not the same 2m physical target: an old red
         * square must not occlude another numbered square in the panorama. */
        overlaps=.false
        do old over targets
          if self~distance(old,candidate)<55 then overlaps=.true
        end
        if overlaps then iterate
        /* A target behind a bridge/building IS allowed. Collision control
         * remains entirely separate from scene generation. */
        targets~append(candidate);accepted=.true;leave
      end
      if \accepted then raise syntax 88.900 array('wide waypoint generation exhausted')
    end
  end
  pose=.array~of(270,-610,65,230)
  if \self~safePoint(pose,2.2) then raise syntax 88.900 array('starting position obstructed in PowerSLAM scene')
  if routeMode=='LEGACY' & \self~safeLine(pose,targets[1]) then raise syntax 88.900 array('no model-clear first leg')
  active=1;status='RUNNING';lastHit='';steps=0
::method random
  expose seed
  seed=(seed*16807)//2147483647
  return seed/2147483647
::method distance
  use strict arg a,b
  return HSqrt((a[1]-b[1])**2+(a[2]-b[2])**2+(a[3]-b[3])**2)
::method fastCollision
  expose collisionBounds
  use strict arg a,b,ignore=''
  xlo=min(a[1],b[1]);xhi=max(a[1],b[1])
  ylo=min(a[2],b[2]);yhi=max(a[2],b[2])
  zlo=min(a[3],b[3]);zhi=max(a[3],b[3])
  do bound over collisionBounds
    if ignore\=='' & bound[1][1]==ignore then iterate
    if xhi<bound[2] | xlo>bound[3] then iterate
    if yhi<bound[4] | ylo>bound[5] then iterate
    if zhi<bound[6] | zlo>bound[7] then iterate
    if .HarbourRayOcclusion~hitSegment(bound[1],a,b)>=0 then return bound[1][1]
  end
  return ''
::method safePoint
  expose scene
  use strict arg p,clearance=1
  if p[3] <= clearance then return .false /* ocean surface */
  offsets=.array~of(.array~of(0,0,0),.array~of(clearance,0,0),.array~of(0-clearance,0,0),.array~of(0,clearance,0),.array~of(0,0-clearance,0),.array~of(0,0,clearance),.array~of(0,0,0-clearance))
  do o over offsets
    q=.array~of(p[1]+o[1],p[2]+o[2],p[3]+o[3])
    to=.array~of(q[1]+0.01,q[2]+0.01,q[3]+0.01)
    if self~fastCollision(q,to)<>'' then return .false
  end
  return .true
::method safeLine
  expose scene
  use strict arg a,b
  if min(a[3],b[3])<2 then return .false
  offsets=.array~of(.array~of(0,0,0),.array~of(2,0,0),.array~of(-2,0,0),.array~of(0,2,0),.array~of(0,-2,0),.array~of(0,0,2),.array~of(0,0,-2))
  do o over offsets
    start=.array~of(a[1]+o[1],a[2]+o[2],a[3]+o[3])
    finish=.array~of(b[1]+o[1],b[2]+o[2],b[3]+o[3])
    if self~fastCollision(start,finish)<>'' then return .false
  end
  return .true
::method step
  expose pose active status targets lastHit steps windEnabled windField lastWindTruth lastSensorPacket lastAirE lastAirN
  use strict arg yawRate,forward,climb,side=0
  if status\=='RUNNING' then return status
  yawRate=max(-25,min(25,yawRate))
  forward=max(-3,min(7,forward))
  side=max(-3,min(3,side))
  climb=max(-4,min(4,climb))
  old=pose
  hdg=old[4]+yawRate
  do while hdg<0; hdg+=360;end
  do while hdg>=360;hdg-=360;end
  driveE=forward*RxCalcSin(hdg)+side*RxCalcCos(hdg)
  driveN=forward*RxCalcCos(hdg)-side*RxCalcSin(hdg)
  driftE=0;driftN=0
  wind=.nil
  if windEnabled then do
    wind=windField~advance(old[3],steps+1)
    /* Simplified inertial drift: gust advection partially moves the craft;
       the untracked remainder changes apparent airflow at its sensors. */
    driftE=0.45*wind['EAST_MPS'];driftN=0.45*wind['NORTH_MPS']
  end
  pos=.array~of(old[1]+driveE+driftE,old[2]+driveN+driftN,old[3]+climb,hdg)
  if \self~safeLine(old,pos) | \self~safePoint(pos,2) then do
    status='COLLISION';lastHit=.HarbourRayOcclusion~firstHit(self~scene,old,pos)
    if lastHit=='' then lastHit='SEA_OR_UNCERTIFIED_SURFACE'
    return status
  end
  pose=pos;steps+=1
  if windEnabled then do
    lastWindTruth=wind
    lastAirE=driveE-0.55*wind['EAST_MPS']
    lastAirN=driveN-0.55*wind['NORTH_MPS']
    lastSensorPacket=(.Slam450AirflowInstruments~new)~sample(lastAirE,lastAirN,hdg,wind['LEVEL'])
  end
  if self~distance(pose,targets[active])<=2.5 then do
    active+=1
    if active>5 then status='COMPLETE'
  end
  return status

::class Slam450Camera public
::attribute world get
::attribute projectionLane get
::method init
  /* v0.88: scene-box silhouettes are projected by the Maths v0.20
   * MathPanoramaProjector (PURE reference lane at 9 digits = the original
   * renderer bit-for-bit; NUMPY lane with the scene resident in Python).
   * Lane: argument, else .local['SLAM450.PROJECTION'], else AUTO. */
  expose world projector projectionLane
  use strict arg incomingWorld,lane=.nil
  world=incomingWorld
  if lane==.nil then do
    lane='AUTO'
    if .local~hasEntry('SLAM450.PROJECTION') then lane=.local['SLAM450.PROJECTION']
  end
  groups=.array~new
  do box over world~scene~boxes; groups~append(box[2]); end
  projector=.MathPanoramaProjector~new(groups,lane,9)
  projectionLane=projector~lane
::method bearing
  use strict arg dx,dy
  if abs(dy)<0.0000001 then do
    if dx>=0 then return 90
    return 270
  end
  if dy>0 then a=RxCalcArcTan(dx/dy)
  else a=180+RxCalcArcTan(dx/dy)
  if a<0 then a+=360
  return a
::method relative
  use strict arg bearing,yaw
  a=bearing-yaw+180
  do while a<0;a+=360;end
  do while a>=360;a-=360;end
  return a
::method project
  use strict arg camera,pt,width,height
  dx=pt[1]-camera[1];dy=pt[2]-camera[2];dz=pt[3]-camera[3]
  dist=HSqrt(dx*dx+dy*dy)
  if dist<0.1 then dist=0.1
  bearing=self~bearing(dx,dy)
  angle=self~relative(bearing,camera[4])
  el=RxCalcArcTan(dz/dist)
  xx=trunc(angle*width/360)+1
  yy=trunc((90-el)*height/180)+1
  return .array~of(xx,yy,dist,bearing,el)
::method paint
  use strict arg rows,xx,yy,halfX,halfY,symbol,w,h
  x0=max(1,xx-halfX);x1=min(w,xx+halfX)
  y0=max(1,yy-halfY);y1=min(h,yy+halfY)
  if x1<x0 | y1<y0 then return
  fill=symbol~copies(x1-x0+1)
  do y=y0 to y1
    rows[y]=overlay(fill,rows[y],x0)
  end
::method render
  expose world
  use strict arg width=720,height=181
  return self~renderAt(world~pose,width,height,.false)
::method renderAt
  expose world projector
  use strict arg cam,width=720,height=181,external=.false,claimed=.nil,rivalPose=.nil,ownCraftPose=.nil,otherKinds=.nil
  rows=.array~new
  do y=1 to height
    if y <= (height+1)/2 then rows~append('.'~copies(width))
    else rows~append('~'~copies(width))
  end
  /* A deliberately low-information indexed raster. Scene solid silhouettes
     use exactly the PowerSLAM cuboid vertices, clipped to camera angles.
     The pilot receives only these image rows. */
  do e over projector~extents(cam,width,height)
    if e==.nil then iterate
    fill='x'~copies(e[2]-e[1]+1)
    do y=e[3] to e[4]
      rows[y]=overlay(fill,rows[y],e[1])
    end
  end
  /* Named PowerSLAM landmark appearance: four synthetic distinct colours;
     no coordinates or true pose written into the image. */
  anchors=.array~of(.array~of('A','N','PYLON'),.array~of('B','S','PYLON'),.array~of('C','O','OPERA'),.array~of('D','T','SALESFORCE'))
  do landmark over anchors
    id=landmark[2]
    if \world~scene~features~hasIndex(id) then iterate
    pt=world~scene~features[id]
    if world~fastCollision(.array~of(cam[1],cam[2],cam[3]),pt,landmark[3])<>'' then iterate
    q=self~project(cam,pt,width,height)
    self~paint(rows,q[1],q[2],1,1,landmark[1],width,height)
  end
  /* Physical targets: 2m horizontal x 2m vertical billboards, facing camera;
     colours 1..5 are strictly monotonically brighter red, no numbers. */
  do t=1 to world~targets~items
    if claimed\==.nil then do
      if claimed~hasIndex(t) then iterate
    end
    pt=world~targets[t]
    if world~fastCollision(.array~of(cam[1],cam[2],cam[3]),pt)<>'' then iterate
    q=self~project(cam,pt,width,height)
    halfX=max(1,trunc(width*RxCalcArcTan(1/q[3])/360))
    d=HSqrt(q[3]**2+(pt[3]-cam[3])**2)
    halfY=max(1,trunc(height*RxCalcArcTan(1/max(0.1,d))/180))
    self~paint(rows,q[1],q[2],halfX,halfY,t,width,height)
  end
  /* The fixed upstream camera can see the vehicle, but the vehicle cannot
     see itself. The pose remains world-private and never appears in FRAME. */
  if external then do
    craft=world~pose
    if ownCraftPose\==.nil then craft=ownCraftPose
    if world~fastCollision(.array~of(cam[1],cam[2],cam[3]),,
          .array~of(craft[1],craft[2],craft[3]))=='' then do
      q=self~project(cam,craft,width,height)
      self~paint(rows,q[1],q[2],2,2,'V',width,height)
    end
  end
  /* The environment may draw the rival as a physical silhouette.
   * The controller sees only R pixels, never the rival's XYZ. */
  if rivalPose\==.nil then do
    craftList=.array~new
    if rivalPose~isA(.directory) then do
      do kind over .array~of('R','P')
        if rivalPose~hasIndex(kind) then craftList~append(.array~of(kind,rivalPose[kind]))
      end
    end
    else if rivalPose[1]~isA(.array) then do
      do otherCraft over rivalPose
        craftList~append(.array~of('R',otherCraft))
      end
    end
    else craftList~append(.array~of('R',rivalPose))
    do otherPair over craftList
      symbol=otherPair[1];otherCraft=otherPair[2]
      if world~fastCollision(.array~of(cam[1],cam[2],cam[3]),,
            .array~of(otherCraft[1],otherCraft[2],otherCraft[3]))=='' then do
        q=self~project(cam,otherCraft,width,height)
        /* v0.88: the silhouette is the airframe's true shape. QUAD keeps
         * the legacy 2.5 m square billboard (behaviour unchanged); a
         * FIXED_WING is wide and flat: 5 m half-span, ~1/6 as tall. The
         * pilot sees only pixels; any type must be inferred from them. */
        kind='QUAD'
        if otherKinds\==.nil then if otherKinds~hasIndex(symbol) then kind=otherKinds[symbol]
        if kind=='FIXED_WING' then do
          spanX=max(2,min(80,trunc(width*RxCalcArcTan(5/max(1,q[3]))/360)))
          spanY=trunc(spanX/6)
          self~paint(rows,q[1],q[2],spanX,spanY,symbol,width,height)
        end
        else do
          span=max(1,min(40,trunc(width*RxCalcArcTan(2.5/max(1,q[3]))/360)))
          self~paint(rows,q[1],q[2],span,span,symbol,width,height)
        end
      end
    end
  end
  f=.directory~new
  f['WIDTH']=width;f['HEIGHT']=height;f['PIXELS']=rows
  f['PALETTE']='.=SKY;~=WATER;x=STRUCTURE;A-D=LANDMARK;1..5=RED_SHADE;V=CRAFT;R=COMPETITOR;P=BUDDY' 
  return f
::method writePPM
  use strict arg frame,file
  /* Netpbm P3 image proof; export only. The pilot never sees filenames. */
  colors=.directory~new
  colors['.']='191 218 238';colors['~']='51 126 173';colors['x']='101 104 112'
  colors['V']='70 205 255';colors['R']='255 230 0';colors['P']='60 225 145'
  colors['A']='235 184 26';colors['B']='249 219 79';colors['C']='251 249 227';colors['D']='56 106 198'
  colors['1']='70 0 0';colors['2']='112 0 0';colors['3']='158 0 0';colors['4']='208 0 0';colors['5']='255 0 0'
  call lineout file,'P3'
  call lineout file,frame['WIDTH'] frame['HEIGHT']
  call lineout file,'255'
  do r over frame['PIXELS']
    line=''
    do k=1 to r~length
      line=line||colors[r~substr(k,1)]||' '
    end
    call lineout file,line
  end
  call stream file,'C','CLOSE'

::class Slam450Vision public
::method observe
  use strict arg frame,symbol
  rows=frame['PIXELS'];w=frame['WIDTH'];h=frame['HEIGHT']
  n=0;xs=0;ys=0;minX=w+1;maxX=0;minY=h+1;maxY=0
  do y=1 to rows~items
    r=rows[y]
    x=pos(symbol,r)
    do while x>0
      n+=1;xs+=x;ys+=y
      minX=min(minX,x);maxX=max(maxX,x)
      minY=min(minY,y);maxY=max(maxY,y)
      x=pos(symbol,r,x+1)
    end
  end
  if n=0 then return .nil
  d=.directory~new
  d['COUNT']=n;d['X']=xs/n;d['Y']=ys/n
  d['WIDTH']=maxX-minX+1;d['HEIGHT']=maxY-minY+1
  d['AZ']=(d['X']-1)*360/w-180
  d['EL']=90-(d['Y']-1)*180/h
  return d

::class Slam450Pilot public
::attribute lastObservation get
::attribute lastTrackedTarget get
::attribute visualSteps get
::attribute gain
::attribute lastFixedCamera get
::attribute lastFixedTargetBearing get
::method init
  expose lastObservation lastTrackedTarget visualSteps gain lastFixedCamera lastFixedTargetBearing
  use strict arg g=0.75
  gain=g;visualSteps=0;lastObservation=.nil;lastTrackedTarget=0
  lastFixedCamera='NONE';lastFixedTargetBearing='NOT_SEEN'
::method consultFixedCamera
  expose lastFixedCamera lastFixedTargetBearing
  use strict arg cameraID,frame,targetNumber
  /* Only colour pixels from ONE stationary feed; no camera/world XYZ. */
  lastFixedCamera=cameraID
  v=(.Slam450Vision~new)~observe(frame,targetNumber)
  lastFixedTargetBearing='NOT_SEEN'
  if v\==.nil then lastFixedTargetBearing=v['AZ']+180
  return lastFixedTargetBearing
::method control
  expose lastObservation lastTrackedTarget visualSteps gain
  use strict arg frame,targetNumber
  /* The target stage is an itinerary instruction. No world-space XYZ access. */
  vis=.Slam450Vision~new
  previous=lastObservation;previousTarget=lastTrackedTarget
  target=vis~observe(frame,targetNumber)
  lastObservation=target;lastTrackedTarget=targetNumber;visualSteps+=1
  if target==.nil then return .array~of(12,0,0) /* scan */
  az=target['AZ'];el=target['EL']
  yaw=max(-25,min(25,az*gain))
  up=max(-4,min(4,el*0.20))
  size=max(target['WIDTH'],target['HEIGHT'])
  /* Image-only close-approach damping. Large target pixels indicate that
   * 4m vertical steps would overshoot a 2m billboard. Neither altitude
   * nor target range is read from the referee or scene. */
  if size>=45 then up=max(-0.7,min(0.7,el*0.035))
  else if size>=25 then up=max(-1.2,min(1.2,el*0.04))
  if abs(az)>25 then speed=0.7
  else if abs(az)>10 then speed=1.7
  else if size>=50 then speed=0.4
  else if size>=25 then speed=0.8
  else if size>=10 then speed=1.6
  else if size>=5 then speed=3.5
  else speed=6
  if abs(el)>14 then speed=min(speed,2.5)
  /* A near, centred target should expand as we advance. If the image
   * stops expanding at the same objective, overcome possible headwind
   * with a short forward pulse. Actual wind and XYZ are not consulted. */
  if size>=25 & abs(az)<10 & abs(el)<12 & previousTarget==targetNumber & previous\==.nil then do
    oldSize=max(previous['WIDTH'],previous['HEIGHT'])
    if size<=oldSize+1 then speed=max(speed,3.0)
  end
  return .array~of(yaw,speed,up)

::class Slam450PoseGuesser public
::attribute references get
::method init
  expose references
  use strict arg scene
  f=scene~features
  references=.directory~new
  do x over .array~of(.array~of('A','N'),.array~of('B','S'),.array~of('C','O'),.array~of('D','T'))
    if f~hasIndex(x[2]) then references[x[1]]=f[x[2]]
  end
::method bearing
  use strict arg dx,dy
  if abs(dy)<0.000001 then do
    if dx>0 then return 90
    return 270
  end
  if dy>0 then a=RxCalcArcTan(dx/dy)
  else a=180+RxCalcArcTan(dx/dy)
  if a<0 then a+=360
  return a
::method wrap
  use strict arg a
  do while a>180; a-=360;end
  do while a< -180; a+=360;end
  return a
::method guess
  expose references
  use strict arg frame,prior=.nil
  vision=.Slam450Vision~new
  obs=.array~new
  do key over .array~of('A','B','C','D')
    v=vision~observe(frame,key)
    if v\==.nil then obs~append(.array~of(key,v['AZ'],v['EL']))
  end
  answer=.directory~new
  answer['STATUS']='UNKNOWN_INSUFFICIENT_VISIBLE_LANDMARKS'
  answer['VISIBLE']=obs~items
  if obs~items<3 then return answer
  if prior==.nil then do
    xmin=-500;xmax=900;ymin=-1200;ymax=450;step=90
  end
  else do
    xmin=prior['X']-140;xmax=prior['X']+140
    ymin=prior['Y']-140;ymax=prior['Y']+140;step=35
  end
  best=.nil;bestScore=1e99
  do pass=1 to 3
    do x=xmin to xmax by step
      do y=ymin to ymax by step
        a=obs[1];ref=references[a[1]]
        initial=self~bearing(ref[1]-x,ref[2]-y)-a[2]
        score=0
        do ob over obs
          pt=references[ob[1]]
          pred=self~bearing(pt[1]-x,pt[2]-y)-initial
          e=self~wrap(pred-ob[2])
          score+=e*e
        end
        if score<bestScore then do
          bestScore=score;best=.array~of(x,y,initial)
        end
      end
    end
    xmin=best[1]-step;xmax=best[1]+step
    ymin=best[2]-step;ymax=best[2]+step
    step=max(2,step/5)
  end
  heights=0
  do ob over obs
    ref=references[ob[1]]
    range=HSqrt((ref[1]-best[1])**2+(ref[2]-best[2])**2)
    heights+=ref[3]-range*RxCalcTan(ob[3])
  end
  yaw=best[3]
  do while yaw<0;yaw+=360;end
  do while yaw>=360;yaw-=360;end
  answer['STATUS']='IMAGE_BEARING_ESTIMATE'
  answer['X']=best[1];answer['Y']=best[2];answer['Z']=heights/obs~items
  answer['YAW']=yaw;answer['BEARING_RMS_DEG']=HSqrt(bestScore/obs~items)
  return answer

/* A genuinely global fixed-camera limiter. A request does not accept a world
 * coordinate, view orientation, zoom, or caller-supplied step count.  Five
 * navigation steps must complete between grants.  No concurrent acquisition,
 * no request queue, and no multi-camera bulk response.  The camera ID is
 * visible to the pilot; camera XYZ and the world truth are NOT transmitted.
 */
::class Slam450FixedCameraNetwork public
::attribute lastGrantedStep get
::attribute grantCount get
::attribute denyCount get
::attribute views get
::method init
  expose world lastGrantedStep grantCount denyCount busy views camera panorama
  use strict arg controlledWorld
  world=controlledWorld
  camera=.Slam450Camera~new(world)
  panorama=.HarbourOcclusionPanorama~new
  panorama~configure
  views=.array~of('CAFE_SYDNEY','OPERA_WEST_WALK','KIRRIBILLI','NORTH_PTZ','BLUES_PT')
  lastGrantedStep=0;grantCount=0;denyCount=0;busy=.false
::method request
  expose world lastGrantedStep grantCount denyCount busy views camera panorama
  use strict arg cameraID
  r=.directory~new
  r['CAMERA']=cameraID
  r['STEP']=world~steps
  r['STATUS']='DENIED'
  valid=.false
  do id over views
    if id==cameraID then valid=.true
  end
  if \valid then do
    r['REASON']='UNKNOWN_FIXED_CAMERA';denyCount+=1;return r
  end
  if busy then do
    r['REASON']='SINGLE_CAMERA_BUSY';denyCount+=1;return r
  end
  if world~steps-lastGrantedStep<5 then do
    r['REASON']='FIVE_COMPLETED_STEPS_REQUIRED';denyCount+=1;return r
  end
  busy=.true
  fixed=panorama~siteCamera(cameraID)
  /* yaw=0 means east pixel at 90 deg; these 5 cameras NEVER move. */
  location=.array~of(fixed[1],fixed[2],fixed[3],0)
  frame=camera~renderAt(location,720,181,.true)
  grantCount+=1;lastGrantedStep=world~steps
  busy=.false
  r['STATUS']='GRANTED';r['FRAME']=frame;r['REASON']='ONE_STATIC_PANORAMA'
  return r
