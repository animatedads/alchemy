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
::requires 'Slam450Ground.cls'
::requires 'SlamHarbourBridgeArch.cls'

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
::attribute fieldBox get
::attribute ground get
::method init
  expose scene targets pose active status seed lastHit steps routeMode courseAreas collisionBounds windEnabled windField lastWindTruth lastSensorPacket lastAirE lastAirN fieldBox ground
  use strict arg rnd=45042,selectedMode='LEGACY',useWind=.false,groundModel=.nil
  /* v0.91: optional real ground (Slam450Ground); must exist before the
   * course is generated so targets and the start respect it. */
  ground=groundModel
  windEnabled=useWind;windField=.nil;lastWindTruth=.nil;lastSensorPacket=.nil
  lastAirE=0;lastAirN=0
  if windEnabled then windField=.Slam450WindField~new(rnd)
  p=.HarbourOcclusionPanorama~new
  p~configure
  scene=p~scene
  /* v0.92: the Sydney Harbour Bridge arch (Power SLAM v0.41,
   * HarbourBridgeArch, PR #127): 86 solids derived from the DECK solid.
   * Applied before the collision bounds, so collision, sight lines, the
   * panorama and the map all include it. */
  archSolids=.HarbourBridgeArch~apply(scene)
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
  fieldBox=.nil
  startPose=.array~of(270,-610,65,230)
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
  else if routeMode=='QUAYSIDE' then do
    /* v0.91 obstructed field over Circular Quay: a fixed 380 x 380 m box
     * (1.43x the LEGACY target area) holding the Salesforce tower, wharves
     * CQ2-CQ6, the station/Cahill expressway and its east extension, and
     * the Cahill berm's diagonal. Targets fly low (8-60 m) so structures
     * obstruct; at least 2 of the 5 must be hidden from the start. */
    fieldBox=.array~of(-170,210,-1190,-810,8,60)
    startPose=.array~of(250,-880,30,240)
    found=.false
    do trial=1 to 60
      targets=.array~new;courseAreas=.array~new
      do i=1 to 5
        accepted=.false
        do tries=1 to 700
          candidate=.array~of(fieldBox[1]+(fieldBox[2]-fieldBox[1])*self~random,,
              fieldBox[3]+(fieldBox[4]-fieldBox[3])*self~random,,
              fieldBox[5]+(fieldBox[6]-fieldBox[5])*self~random)
          if \self~safePoint(candidate,3) then iterate
          overlaps=.false
          do old over targets
            if self~distance(old,candidate)<55 then overlaps=.true
          end
          if overlaps then iterate
          targets~append(candidate);courseAreas~append('QUAYSIDE');accepted=.true;leave
        end
        if \accepted then leave
      end
      if targets~items<5 then iterate
      hidden=0
      do t over targets
        if \self~safeLine(startPose,t) then hidden+=1
      end
      if hidden>=2 then do;found=.true;leave;end
    end
    if \found then raise syntax 88.900 array('quayside course generation exhausted')
  end
  else if routeMode=='HILL' then do
    /* v0.92 Observatory Hill: a fixed 420 x 420 m field over the hill
     * (41-44 m AHD), the western CBD ridge and Millers Point, from the
     * Power SLAM v0.40 ground. Targets 8-80 m and >= 3 m above ground; at
     * least 2 of the 5 hidden from the start (behind the hill itself).
     * Start over Walsh Bay water, south of the WB67 wharf, facing the hill.
     * Needs real ground: without it the hill does not exist. */
    if ground==.nil then raise syntax 88.900 array('course HILL needs real ground (groundMode GROUND)')
    fieldBox=.array~of(-720,-300,-1020,-600,8,80)
    startPose=.array~of(-525,-560,25,180)
    found=.false
    do trial=1 to 60
      targets=.array~new;courseAreas=.array~new
      do i=1 to 5
        accepted=.false
        do tries=1 to 700
          candidate=.array~of(fieldBox[1]+(fieldBox[2]-fieldBox[1])*self~random,,
              fieldBox[3]+(fieldBox[4]-fieldBox[3])*self~random,,
              fieldBox[5]+(fieldBox[6]-fieldBox[5])*self~random)
          if \self~safePoint(candidate,3) then iterate
          overlaps=.false
          do old over targets
            if self~distance(old,candidate)<55 then overlaps=.true
          end
          if overlaps then iterate
          targets~append(candidate);courseAreas~append('HILL');accepted=.true;leave
        end
        if \accepted then leave
      end
      if targets~items<5 then iterate
      hidden=0
      do t over targets
        if \self~safeLine(startPose,t) then hidden+=1
      end
      if hidden>=2 then do;found=.true;leave;end
    end
    if \found then raise syntax 88.900 array('hill course generation exhausted')
  end
  else if routeMode=='PYLONS' then do
    /* v0.92 Sydney Harbour Bridge: a fixed 500 x 680 m field around the
     * whole span. Target 1 sits in the gap between a pylon pair above the
     * deck (55-80 m); targets 2-3 under the deck (8-35 m, a vertical ray
     * from them hits DECK); targets 4-5 anywhere in the field. All >= 3 m
     * clear of solids (and ground when attached), >= 55 m apart. Start
     * over open water east of the span, facing the bridge. Pylon pairs are
     * the PYLON_TOWER_PHOTO solids at each abutment. */
    fieldBox=.array~of(-200,300,-350,330,8,80)
    startPose=.array~of(150,-150,30,300)
    gaps=.array~of(.array~of(-86,-253,-49.5,-269),.array~of(174.5,249,210,232))
    sA=.array~of(-68,-261);nA=.array~of(192,240.5)
    dx=nA[1]-sA[1];dy=nA[2]-sA[2];len=HSqrt(dx*dx+dy*dy);ux=dx/len;uy=dy/len
    found=.false
    do trial=1 to 60
      targets=.array~new;courseAreas=.array~new
      do i=1 to 5
        accepted=.false
        do tries=1 to 700
          select
            when i==1 then do
              gp=gaps[1+trunc(2*self~random)]
              mx=(gp[1]+gp[3])/2;my=(gp[2]+gp[4])/2
              ax=gp[3]-gp[1];ay=gp[4]-gp[2];al=HSqrt(ax*ax+ay*ay);ax=ax/al;ay=ay/al
              along=(self~random-0.5)*6;across=(self~random-0.5)*8
              candidate=.array~of(mx+along*ax-across*ay,my+along*ay+across*ax,55+25*self~random)
              area='PYLON_GAP'
            end
            when i<=3 then do
              t=0.2+0.6*self~random;off=(self~random-0.5)*24
              candidate=.array~of(sA[1]+t*dx-off*uy,sA[2]+t*dy+off*ux,8+27*self~random)
              area='UNDER_DECK'
            end
            otherwise do
              candidate=.array~of(fieldBox[1]+(fieldBox[2]-fieldBox[1])*self~random,,
                  fieldBox[3]+(fieldBox[4]-fieldBox[3])*self~random,,
                  fieldBox[5]+(fieldBox[6]-fieldBox[5])*self~random)
              area='PYLONS'
            end
          end
          if \self~safePoint(candidate,3) then iterate
          if area=='UNDER_DECK' then do
            if self~fastCollision(candidate,.array~of(candidate[1],candidate[2],60))\=='DECK' then iterate
          end
          overlaps=.false
          do old over targets
            if self~distance(old,candidate)<55 then overlaps=.true
          end
          if overlaps then iterate
          targets~append(candidate);courseAreas~append(area);accepted=.true;leave
        end
        if \accepted then leave
      end
      if targets~items==5 then do;found=.true;leave;end
    end
    if \found then raise syntax 88.900 array('pylons course generation exhausted')
  end
  else if routeMode=='HARBOUR' then do
    /* v0.92 (Tom Dyer: "box Circular Quay to Blues Point tower inclusive"):
     * a fixed 900 x 1510 m field, x -640..260 E, y -1130..380 N, 8-90 m.
     * One target in each of five zones, numbered in a seeded shuffle:
     * BLUES (within 150 m of the tower), BRIDGE (under the deck), WALSH
     * (among the Walsh Bay wharves, low), HILL (Observatory Hill, >= 3 m
     * above ground) and QUAY (over the Circular Quay wharves, low). Start
     * over open water west of the span; >= 2 targets hidden at the start.
     * Needs real ground (the hill and both shores). Written by Claude (Opus 5.5). */
    if ground==.nil then raise syntax 88.900 array('course HARBOUR needs real ground (groundMode GROUND)')
    fieldBox=.array~of(-640,260,-1130,380,8,90)
    startPose=.array~of(-250,-100,30,160)
    sA=.array~of(-68,-261);nA=.array~of(192,240.5)
    dx=nA[1]-sA[1];dy=nA[2]-sA[2];len=HSqrt(dx*dx+dy*dy);ux=dx/len;uy=dy/len
    zones=.array~of('BLUES','BRIDGE','WALSH','HILL','QUAY')
    found=.false
    do trial=1 to 60
      order=zones~copy
      do i=5 to 2 by -1
        j=1+trunc(i*self~random);tmp=order[i];order[i]=order[j];order[j]=tmp
      end
      targets=.array~new;courseAreas=.array~new
      do i=1 to 5
        area=order[i];accepted=.false
        do tries=1 to 900
          select
            when area=='BLUES' then do
              r=40+110*self~random;a=360*self~random
              candidate=.array~of(-597+r*RxCalcSin(a,16),334+r*RxCalcCos(a,16),15+75*self~random)
            end
            when area=='BRIDGE' then do
              t=0.2+0.6*self~random;off=(self~random-0.5)*24
              candidate=.array~of(sA[1]+t*dx-off*uy,sA[2]+t*dy+off*ux,8+27*self~random)
            end
            when area=='WALSH' then candidate=.array~of(-680+450*self~random,-560+320*self~random,8+22*self~random)
            when area=='HILL' then candidate=.array~of(-620+220*self~random,-980+220*self~random,45+35*self~random)
            otherwise candidate=.array~of(-30+240*self~random,-1110+220*self~random,8+27*self~random)
          end
          if candidate[1]<fieldBox[1] | candidate[1]>fieldBox[2] then iterate
          if candidate[2]<fieldBox[3] | candidate[2]>fieldBox[4] then iterate
          if \self~safePoint(candidate,3) then iterate
          if area=='BRIDGE' then do
            if self~fastCollision(candidate,.array~of(candidate[1],candidate[2],60))\=='DECK' then iterate
          end
          targets~append(candidate);courseAreas~append(area);accepted=.true;leave
        end
        if \accepted then leave
      end
      if targets~items<5 then iterate
      hidden=0
      do t over targets
        if \self~safeLine(startPose,t) then hidden+=1
      end
      if hidden>=2 then do;found=.true;leave;end
    end
    if \found then raise syntax 88.900 array('harbour course generation exhausted')
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
  pose=startPose
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
::method scan
  /* v0.92 short-range narrow-band reflective scanner (Tom Dyer): 7 x 3 rays,
   * azimuth -15..+15 deg in 5 deg steps around the heading, elevation -10,
   * 0, +10 deg, range 60 m. Each ray returns the range to the first
   * structure, ground or water surface, or the full range when clear.
   * Simulator-measured, like the airflow sensors; pilots get ranges only. */
  expose collisionBounds ground
  use strict arg p,maxRange=60
  numeric digits 16
  out=.array~new
  do el over .array~of(-10,0,10)
    do az=-15 to 15 by 5
      hd=p[4]+az;ce=RxCalcCos(el)
      q=.array~of(p[1]+maxRange*ce*RxCalcSin(hd),p[2]+maxRange*ce*RxCalcCos(hd),p[3]+maxRange*RxCalcSin(el))
      best=2
      xlo=min(p[1],q[1]);xhi=max(p[1],q[1]);ylo=min(p[2],q[2]);yhi=max(p[2],q[2]);zlo=min(p[3],q[3]);zhi=max(p[3],q[3])
      do bound over collisionBounds
        if xhi<bound[2] | xlo>bound[3] | yhi<bound[4] | ylo>bound[5] | zhi<bound[6] | zlo>bound[7] then iterate
        t=.HarbourRayOcclusion~hitSegment(bound[1],p,q)
        if t>=0 then best=min(best,t)
      end
      if var('ground') then if ground\==.nil then do
        t=ground~firstHit(p,q);if t>=0 then best=min(best,t)
      end
      if q[3]<0 then best=min(best,p[3]/(p[3]-q[3]))   /* water plane */
      d=.directory~new;d['AZ']=az;d['EL']=el
      if best<=1 then d['RANGE']=best*maxRange
      else d['RANGE']=maxRange
      d['HIT']=(best<=1)
      out~append(d)
    end
  end
  return out
::method surfaceBelow
  /* v0.92 radio altimeter: height of the first surface straight below p
   * (water at 0, real ground when attached, or a structure top such as the
   * deck). Exact: the same cuboid segment test as collisions. Returns
   * 'NO_RETURN' over unknown/no-fly ground. */
  expose collisionBounds ground
  use strict arg p
  numeric digits 16
  top=0
  if var('ground') then if ground\==.nil then do
    g=ground~surface(p[1],p[2])
    if g>=1e8 then return 'NO_RETURN'
    top=max(top,g)
  end
  a=.array~of(p[1],p[2],p[3]);b=.array~of(p[1],p[2],-1)
  do bound over collisionBounds
    if p[1]<bound[2] | p[1]>bound[3] | p[2]<bound[4] | p[2]>bound[5] | bound[6]>p[3] then iterate
    t=.HarbourRayOcclusion~hitSegment(bound[1],a,b)
    if t>=0 then top=max(top,p[3]-t*(p[3]+1))
  end
  return top
::method sightBlocked
  /* v0.91 line of sight: scene solids (unchanged fastCollision) and, when
   * real ground is attached, the ground surface. Without ground this is
   * exactly fastCollision<>'' (static races stay byte-identical). */
  expose ground
  use strict arg a,b,ignore=''
  if self~fastCollision(a,b,ignore)<>'' then return .true
  if var('ground') then if ground\==.nil then return \ground~sightClear(a,b)
  return .false
::method safePoint
  expose scene ground
  use strict arg p,clearance=1
  if p[3] <= clearance then return .false /* ocean surface */
  if var('ground') then if ground\==.nil then if \ground~pointClear(p,clearance) then return .false
  offsets=.array~of(.array~of(0,0,0),.array~of(clearance,0,0),.array~of(0-clearance,0,0),.array~of(0,clearance,0),.array~of(0,0-clearance,0),.array~of(0,0,clearance),.array~of(0,0,0-clearance))
  do o over offsets
    q=.array~of(p[1]+o[1],p[2]+o[2],p[3]+o[3])
    to=.array~of(q[1]+0.01,q[2]+0.01,q[3]+0.01)
    if self~fastCollision(q,to)<>'' then return .false
  end
  return .true
::method safeLine
  expose scene ground
  use strict arg a,b
  if min(a[3],b[3])<2 then return .false
  if var('ground') then if ground\==.nil then if \ground~lineClear(a,b,2) then return .false
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
  expose world projector projectionLane terrain groupClass groupCentre
  use strict arg incomingWorld,lane=.nil
  world=incomingWorld
  terrain=.nil
  if lane==.nil then do
    lane='AUTO'
    if .local~hasEntry('SLAM450.PROJECTION') then lane=.local['SLAM450.PROJECTION']
  end
  /* v0.92: structures drawn by CLASS colour (Tom Dyer: one grey for every
   * building makes vision near the bridge / Opera / towers ambiguous), far
   * to near, and long solids split into <= 40 m pieces FOR DRAWING ONLY
   * (one bounding rectangle per solid collapses when the solid surrounds
   * the camera, e.g. the deck seen from beneath). Collision is unchanged:
   * it still tests each exact solid. */
  groups=.array~new;groupClass=.array~new;groupCentre=.array~new
  do box over world~scene~boxes
    cls=self~structureClass(box[1])
    do piece over self~drawPieces(box[2])
      groups~append(piece);groupClass~append(cls)
      cx=0;cy=0;cz=0
      do v over piece;cx+=v[1];cy+=v[2];cz+=v[3];end
      groupCentre~append(.array~of(cx/piece~items,cy/piece~items,cz/piece~items))
    end
  end
  projector=.MathPanoramaProjector~new(groups,lane,9)
  projectionLane=projector~lane
  /* v0.91: real ground (Power SLAM v0.40 words) as land silhouettes, by the
   * Maths v0.21 MathTerrainPanorama (same lane choice as the projector). */
  if world~ground\==.nil then do
    r=world~ground~rasterLocal
    terrain=.MathTerrainPanorama~new(r['HEIGHTS'],r['KINDS'],r['COLUMNS'],r['ROWS'],,
      r['ORIGIN'],r['COL_VECTOR'],r['ROW_VECTOR'],3000,lane,9)
  end
::method structureClass class
  /* Palette symbol per PowerSLAM solid class (colours in palette()). */
  use strict arg name
  n=name~upper
  select
    when n=='OPERA' then return 'o'
    when n~left(5)=='PYLON' | n~left(8)=='ABUTMENT' then return 'p'
    when n=='DECK' then return 'd'
    when n=='SALESFORCE' then return 's'
    when n=='BLUES_POINT_TOWER' then return 'b'
    when (n~left(2)=='CQ' | n~left(2)=='WB') & (pos('_DECK',n)>0 | pos('_ROOF',n)>0) then return 'w'
    when n~left(6)=='CAHILL' | n=='CQ_STATION' then return 'c'
    when n~left(5)=='ARCH_' | n~left(7)=='HANGER_' then return 'a'
    otherwise return 'x'
  end
::method structureClass
  use strict arg name
  return self~class~structureClass(name)
::method palette class
  /* Shared structure colours (panorama PPM/PNG and the plan map). */
  p=.directory~new
  p['o']='230 214 170';p['p']='156 136 112';p['d']='52 60 92';p['s']='0 160 160'
  p['b']='98 112 190';p['w']='166 168 190';p['c']='200 140 90';p['x']='101 104 112';p['a']='130 140 155'
  return p
::method drawPieces
  /* Split a cuboid along its longest edge into <= 40 m pieces. PowerSLAM's
   * cuboid() emits vertices as index = 4*vertical + 2*a + b + 1, so the
   * edges from vertex 1 go to vertices 2 (b), 3 (a) and 5 (vertical). The
   * three are checked for orthogonality; anything else is drawn whole.
   * (Picking the "three nearest" vertices fails for long thin slabs: the
   * bridge deck's 49 m face diagonal is shorter than its 566 m edge.) */
  use strict arg verts
  numeric digits 16
  if verts~items\==8 then return .array~of(verts)
  v1=verts[1];e=.array~new
  do k over .array~of(2,3,5)
    w=verts[k];ex=w[1]-v1[1];ey=w[2]-v1[2];ez=w[3]-v1[3]
    e~append(.array~of(ex,ey,ez,ex*ex+ey*ey+ez*ez))
  end
  do i=1 to 2
    do j=i+1 to 3
      dot=e[i][1]*e[j][1]+e[i][2]*e[j][2]+e[i][3]*e[j][3]
      if abs(dot)>0.001*RxCalcSqrt(e[i][4]*e[j][4],16)+1e-9 then return .array~of(verts)
    end
  end
  long=1;do j=2 to 3;if e[j][4]>e[long][4] then long=j;end
  L=RxCalcSqrt(e[long][4],16)
  n=max(1,trunc((L+39.999)/40))
  if n==1 then return .array~of(verts)
  o=.array~new;do j=1 to 3;if j\==long then o~append(e[j]);end
  out=.array~new
  do i=0 to n-1
    piece=.array~new
    do t over .array~of(i/n,(i+1)/n)
      do bb over .array~of(0,1)
        do cc over .array~of(0,1)
          piece~append(.array~of(v1[1]+t*e[long][1]+bb*o[1][1]+cc*o[2][1],,
                                 v1[2]+t*e[long][2]+bb*o[1][2]+cc*o[2][2],,
                                 v1[3]+t*e[long][3]+bb*o[1][3]+cc*o[2][3]))
        end
      end
    end
    out~append(piece)
  end
  return out
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
  expose world projector terrain groupClass groupCentre
  use strict arg cam,width=720,height=181,external=.false,claimed=.nil,rivalPose=.nil,ownCraftPose=.nil,otherKinds=.nil
  rows=.array~new
  do y=1 to height
    if y <= (height+1)/2 then rows~append('.'~copies(width))
    else rows~append('~'~copies(width))
  end
  /* v0.91: land ('G') under the structures. Structures are still drawn
   * over land, so a hill does not hide a building behind it (rare at
   * harbour level; documented limit). */
  if var('terrain') then if terrain\==.nil then do
    runs=terrain~rowRuns(cam,width,height)
    do y=1 to height
      do run over runs[y]
        rows[y]=overlay('G'~copies(run[2]-run[1]+1),rows[y],run[1])
      end
    end
  end
  /* A deliberately low-information indexed raster. Scene solid silhouettes
     use exactly the PowerSLAM cuboid vertices, clipped to camera angles.
     The pilot receives only these image rows. */
  /* v0.92: painted far to near, each in its structure-class colour. */
  ext=projector~extents(cam,width,height)
  keys=.array~new
  do i=1 to ext~items
    if ext[i]==.nil then iterate
    c=groupCentre[i]
    d=RxCalcSqrt((c[1]-cam[1])**2+(c[2]-cam[2])**2+(c[3]-cam[3])**2,16)
    keys~append(translate(format(d,7,3),'0',' ')||' '||i)
  end
  keys=keys~sort
  do k=keys~items to 1 by -1
    i=word(keys[k],2);e=ext[i]
    fill=groupClass[i]~copies(e[2]-e[1]+1)
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
    if world~sightBlocked(.array~of(cam[1],cam[2],cam[3]),pt,landmark[3]) then iterate
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
    if world~sightBlocked(.array~of(cam[1],cam[2],cam[3]),pt) then iterate
    q=self~project(cam,pt,width,height)
    halfX=max(1,trunc(width*RxCalcArcTan(1/q[3])/360))
    d=HSqrt(q[3]**2+(pt[3]-cam[3])**2)
    halfY=max(1,trunc(height*RxCalcArcTan(1/max(0.1,d))/180))
    /* v0.92 identification range (Tom Dyer): within R a small object is
       reliably identifiable; R..1.6R it is at most a single pixel; beyond
       1.6R it is not drawn. R=0 (default) keeps the legacy unlimited view. */
    vr=visRange()
    if vr>0 then do
      if d>1.6*vr then iterate
      if d>vr then do;halfX=0;halfY=0;end
    end
    self~paint(rows,q[1],q[2],halfX,halfY,t,width,height)
  end
  /* The fixed upstream camera can see the vehicle, but the vehicle cannot
     see itself. The pose remains world-private and never appears in FRAME. */
  if external then do
    craft=world~pose
    if ownCraftPose\==.nil then craft=ownCraftPose
    if \world~sightBlocked(.array~of(cam[1],cam[2],cam[3]),,
          .array~of(craft[1],craft[2],craft[3])) then do
      q=self~project(cam,craft,width,height)
      self~paint(rows,q[1],q[2],2,2,'V',width,height)
    end
  end
  /* The environment may draw the rival as a physical silhouette.
   * The controller sees only R pixels, never the rival's XYZ. */
  /* v0.92 fix (bug since v0.89): when the requester is the last craft
   * still flying its list of others is EMPTY; that is "no rivals", not a
   * pose with no coordinates. */
  if rivalPose\==.nil then if rivalPose~isA(.array) then if rivalPose~items==0 then rivalPose=.nil
  if rivalPose\==.nil then do
    craftList=.array~new
    kindList=.array~new
    if rivalPose~isA(.directory) then do
      do kind over .array~of('R','P')
        if \rivalPose~hasIndex(kind) then iterate
        v=rivalPose[kind]
        /* v0.89: a symbol may stand for several aircraft (squad races). */
        if v~items>0 & v[1]~isA(.array) then do
          do j=1 to v~items
            craftList~append(.array~of(kind,v[j]))
            k='QUAD'
            if otherKinds\==.nil then if otherKinds~hasIndex(kind) then do
              ok=otherKinds[kind]
              if ok~isA(.array) then k=ok[j]
              else k=ok
            end
            kindList~append(k)
          end
        end
        else do
          craftList~append(.array~of(kind,v))
          k='QUAD'
          if otherKinds\==.nil then if otherKinds~hasIndex(kind) then k=otherKinds[kind]
          kindList~append(k)
        end
      end
    end
    else if rivalPose[1]~isA(.array) then do
      do otherCraft over rivalPose
        craftList~append(.array~of('R',otherCraft))
      end
    end
    else craftList~append(.array~of('R',rivalPose))
    do pairNo=1 to craftList~items
      otherPair=craftList[pairNo]
      symbol=otherPair[1];otherCraft=otherPair[2]
      if \world~sightBlocked(.array~of(cam[1],cam[2],cam[3]),,
            .array~of(otherCraft[1],otherCraft[2],otherCraft[3])) then do
        q=self~project(cam,otherCraft,width,height)
        vr=visRange();far=.false
        if vr>0 then do
          dd=HSqrt(q[3]**2+(otherCraft[3]-cam[3])**2)
          if dd>1.6*vr then iterate
          far=(dd>vr)
        end
        if far then do;self~paint(rows,q[1],q[2],0,0,symbol,width,height);iterate;end
        /* v0.88: the silhouette is the airframe's true shape. QUAD keeps
         * the legacy 2.5 m square billboard (behaviour unchanged); a
         * FIXED_WING is wide and flat: 5 m half-span, ~1/6 as tall. The
         * pilot sees only pixels; any type must be inferred from them. */
        kind='QUAD'
        if kindList~hasIndex(pairNo) then kind=kindList[pairNo]
        else if otherKinds\==.nil then if otherKinds~hasIndex(symbol) then kind=otherKinds[symbol]
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
  colors['.']='191 218 238';colors['~']='51 126 173';colors['x']='101 104 112';colors['G']='169 180 143'
  sp=.Slam450Camera~palette;do k over sp~allIndexes;colors[k]=sp[k];end
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

::method observeBlobs
  /* v0.89: connected components of one symbol (4-connected runs), so each
   * separately drawn aircraft is its own observation. observe() merges
   * every pixel of a symbol into one box, which is correct for a single
   * target colour but wrong when several aircraft share 'R' or 'P'.
   * Returns an array of directories with the same fields as observe(),
   * largest first. Image only; no coordinates. */
  use strict arg frame,symbol
  rows=frame['PIXELS'];w=frame['WIDTH'];h=frame['HEIGHT']
  runs=.array~new;prev=.array~new;parent=.array~new
  do y=1 to rows~items
    r=rows[y];cur=.array~new;x=pos(symbol,r)
    do while x>0
      e=verify(r,symbol,'N',x)
      if e=0 then e=length(r)+1
      runs~append(.array~of(y,x,e-1));id=runs~items;parent[id]=id
      do q over prev
        pr=runs[q]
        if pr[2]<=e-1 & pr[3]>=x then call union parent,id,q
      end
      cur~append(id)
      x=pos(symbol,r,e)
    end
    prev=cur
  end
  groups=.directory~new
  do id=1 to runs~items
    root=find(parent,id)
    if \groups~hasIndex(root) then groups[root]=.array~new
    groups[root]~append(runs[id])
  end
  out=.array~new
  do root over groups~allIndexes
    n=0;xs=0;ys=0;minX=w+1;maxX=0;minY=h+1;maxY=0
    do run over groups[root]
      len=run[3]-run[2]+1;n+=len
      xs+=len*(run[2]+run[3])/2;ys+=len*run[1]
      minX=min(minX,run[2]);maxX=max(maxX,run[3]);minY=min(minY,run[1]);maxY=max(maxY,run[1])
    end
    d=.directory~new
    d['COUNT']=n;d['X']=xs/n;d['Y']=ys/n
    d['WIDTH']=maxX-minX+1;d['HEIGHT']=maxY-minY+1
    d['AZ']=(d['X']-1)*360/w-180
    d['EL']=90-(d['Y']-1)*180/h
    out~append(d)
  end
  /* largest first (stable insertion sort; few blobs) */
  sorted=.array~new
  do d over out
    placed=.false
    do i=1 to sorted~items
      if d['COUNT']>sorted[i]['COUNT'] then do
        if i==1 then sorted~insert(d,.nil)
        else sorted~insert(d,i-1)
        placed=.true;leave
      end
    end
    if \placed then sorted~append(d)
  end
  return sorted

::routine find
  use arg parent,i
  do while parent[i]\=i
    parent[i]=parent[parent[i]];i=parent[i]
  end
  return i
::routine union
  use arg parent,a,b
  ra=find(parent,a);rb=find(parent,b)
  if ra\=rb then parent[max(ra,rb)]=min(ra,rb)
  return

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

::routine visRange public
  /* v0.92: identification range in metres (.local SLAM450.ID_RANGE); 0 = unlimited. */
  v=.local['SLAM450.ID_RANGE']
  if datatype(v,'N') then return v
  return 0
