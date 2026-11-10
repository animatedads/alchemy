/* SLAM450 v0.89 — squad referee: N aircraft in two teams.
 * Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.
 *
 * Generalises the v0.88 trio referee (which is unchanged) to any set of
 * craft ids, each with its own airframe (Physics World dev51 adapters) and
 * battery. Physics, energy debits, swept target interception and the 4 m
 * separation rule are identical to the trio. One rule differs, by design:
 *   a craft that collides (scene, water, stall or another aircraft) is OUT:
 *   it is frozen, stops being drawn or debited, and the race continues for
 *   everyone else. The trio ended the whole race on any collision, which
 *   would let one experimental pilot (e.g. an LLM) end every race.
 * A quad that cannot pay for its tick is likewise OUT (POWER_OUT); a wing
 * glides on its polar exactly as in v0.88.
 */
::requires 'Slam450Flight.cls'
::requires 'Slam450Battery.cls'
::requires 'Slam450Airframe.cls'
::requires 'Slam450Trio.cls'
::requires 'Slam450TargetMovers.cls'

::class Slam450SquadReferee public subclass Slam450TrioReferee
/* ooRexx object variables are scoped per class: every accessor that reads
   state is redeclared here; only the stateless geometry helpers
   (contactFraction, closestConcurrent) are inherited from the trio. */
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
::attribute lastStates get
::attribute ids get
::attribute teams get
::attribute craftStatus get
::attribute outEvents get
::method init
  /* layout: array of directories ID, TEAM, AIRFRAME. */
  expose world tick status claims events poses lastPackets lastWind lastHit windField minSeparation batteryEnabled batteries airframes lastStates ids teams craftStatus outEvents
  use strict arg scenario,layout,windOn=.true,batteryOn=.true
  world=scenario
  tick=0;status='RUNNING';lastHit='';claims=.directory~new
  events=.array~new;lastPackets=.directory~new;lastWind=.directory~new
  lastStates=.directory~new;outEvents=.array~new
  ids=.array~new;teams=.directory~new;airframes=.directory~new;craftStatus=.directory~new
  do entry over layout
    id=entry['ID']
    if id~left(1)\=='A' | \datatype(id~substr(2),'W') then raise syntax 88.900 array('craft id must be A<n>')
    ids~append(id);teams[id]=entry['TEAM'];craftStatus[id]='ACTIVE'
    select
      when entry['AIRFRAME']=='QUAD' then airframes[id]=.Slam450QuadAirframe~new
      when entry['AIRFRAME']=='FIXED_WING' then airframes[id]=.Slam450FixedWingAirframe~new
      otherwise raise syntax 88.900 array('unknown airframe' entry['AIRFRAME'])
    end
  end
  batteryEnabled=batteryOn;batteries=.directory~new
  if batteryEnabled then do id over ids
    batteries[id]=.Slam450Battery~new(airframes[id]~CAPACITY,airframes[id])
  end
  windField=.nil
  if windOn then windField=.Slam450WindField~new(world~seed+904)
  /* Start: the trio's equilateral triangle (A1,A2,A3 at 10 m) plus two
   * mirrored apexes; every pair at least 10 m apart and scene-safe. */
  first=world~targets[1];start=world~pose
  dx=start[1]-first[1];dy=start[2]-first[2]
  rr=HSqrt(dx*dx+dy*dy)
  ux=dx/rr;uy=dy/rr;h=8.660254037844386
  slots=.array~new
  slots~append(.array~of(start[1],start[2],start[3],start[4]))
  slots~append(.array~of(start[1]+10*ux,start[2]+10*uy,start[3],start[4]))
  slots~append(.array~of(start[1]+5*ux-h*uy,start[2]+5*uy+h*ux,start[3],start[4]))
  slots~append(.array~of(start[1]+5*ux+h*uy,start[2]+5*uy-h*ux,start[3],start[4]))
  slots~append(.array~of(start[1]-10*ux,start[2]-10*uy,start[3],start[4]))
  slots~append(.array~of(start[1]+20*ux,start[2]+20*uy,start[3],start[4]))
  safe=.array~new
  do s over slots
    if world~safePoint(s,2.2) then safe~append(s)
  end
  if safe~items<ids~items then raise syntax 88.900 array('not enough safe start slots')
  poses=.directory~new
  do i=1 to ids~items;poses[ids[i]]=safe[i];end
  /* v0.92: an LLM-crewed WING (A4/A5) cannot hover off the start line, so
     it starts stacked above its slot (+12 m A4, +18 m A5) instead of flying
     into a hovering quad on tick 1 (HARBOUR seed 45047 lost both teams'
     craft at t1/t6 that way). Quads and A3 keep the legacy layout. */
  do id over .array~of('A4','A5')
    if \poses~hasIndex(id) then iterate
    if airframes[id]~KIND\=='FIXED_WING' then iterate
    up=12;if id=='A5' then up=18
    p=poses[id]~copy;p[3]=p[3]+up
    if world~safePoint(p,2.2) then poses[id]=p
  end
  minSeparation=1e9
  do i=1 to ids~items-1
    do j=i+1 to ids~items
      minSeparation=min(minSeparation,world~distance(poses[ids[i]],poses[ids[j]]))
    end
  end
  if minSeparation<9.99 then raise syntax 88.900 array('squad start spacing')
::method sensorDebit
  /* v0.92: scanner / radio altimeter power (SENSOR); .false = could not pay. */
  expose batteries batteryEnabled
  use strict arg id,amount
  if \batteryEnabled | amount<=0 then return .true
  return batteries[id]~debit('SENSOR',amount)
::method visualDebit
  /* v0.92: visual position-fix data charge (VISUAL); .false = could not pay. */
  expose batteries batteryEnabled
  use strict arg id,amount
  if \batteryEnabled | amount<=0 then return .true
  return batteries[id]~debit('VISUAL',amount)
::method attachMovers
  /* v0.90: slow-moving committed targets (Slam450TargetMovers). */
  expose movers windLevels
  use strict arg m
  movers=m;windLevels=.directory~new
::method movers
  expose movers
  if var('movers') then return movers
  return .nil
::method windLevels
  expose windLevels
  if var('windLevels') then return windLevels
  return .directory~new
::method contactMoving
  /* First time the craft enters the 2.5 m capture sphere of a target that
   * is itself moving over the same tick: relative swept motion. */
  use strict arg a,b,p0,p1,radius=2.5
  numeric digits 16
  rx=a[1]-p0[1];ry=a[2]-p0[2];rz=a[3]-p0[3]
  vx=(b[1]-a[1])-(p1[1]-p0[1]);vy=(b[2]-a[2])-(p1[2]-p0[2]);vz=(b[3]-a[3])-(p1[3]-p0[3])
  C=rx*rx+ry*ry+rz*rz-radius*radius
  if C<=0 then return 0
  A=vx*vx+vy*vy+vz*vz
  if A<0.00000001 then return -1
  B=2*(rx*vx+ry*vy+rz*vz)
  disc=B*B-4*A*C
  if disc<0 then return -1
  t=(-B-RxCalcSqrt(disc,16))/(2*A)
  if t<0 | t>1 then return -1
  return t
::method active
  expose craftStatus
  use strict arg id
  return craftStatus[id]=='ACTIVE'
::method activeIds
  expose ids craftStatus
  out=.array~new
  do id over ids;if craftStatus[id]=='ACTIVE' then out~append(id);end
  return out
::method knockOut private
  expose craftStatus outEvents tick
  use strict arg id,reason
  craftStatus[id]=reason
  e=.directory~new;e['STEP']=tick+1;e['CRAFT']=id;e['REASON']=reason
  outEvents~append(e)
::method advanceAll
  /* cmds: directory id -> command (only active craft are read). */
  expose world tick status claims events poses lastPackets lastWind lastHit windField minSeparation batteryEnabled batteries airframes lastStates ids craftStatus movers windLevels
  use strict arg cmds
  if status\=='RUNNING' then return .array~new
  live=self~activeIds
  if live~items==0 then do;status='ALL_OUT';return .array~new;end
  before=.directory~new;after=.directory~new
  windPackets=.directory~new;sensorPackets=.directory~new
  windsByLevel=.directory~new
  /* v0.90 moving targets: draw all three wind bands every tick, in band
   * order, so the weather no longer depends on which levels craft happen
   * to occupy and targets and craft share one air mass. Static-target
   * races keep the v0.89 on-demand draw (byte-identical). */
  if var('movers') then if movers\==.nil & windField\==.nil then do lv=1 to 3
    windsByLevel[lv]=windField~advance(word('30 80 130',lv),tick+1)
  end
  prices=.directory~new;powered=.directory~new;states=.directory~new
  do id over live;powered[id]=.true;end
  if batteryEnabled then do id over live
    q=batteries[id]~quote(cmds[id])
    prices[id]=q['TOTAL']
    if \batteries[id]~affordable(prices[id]) then do
      if airframes[id]~KIND=='FIXED_WING' then do
        powered[id]=.false
        cmds[id]=airframes[id]~glideCommand(cmds[id][1])
        prices[id]=batteries[id]~quote(cmds[id],.false)['TOTAL']
        if \batteries[id]~affordable(prices[id]) then do
          cmds[id]=airframes[id]~glideCommand(0);prices[id]=batteries[id]~remaining
        end
      end
      else self~knockOut(id,'POWER_OUT')
    end
  end
  live=self~activeIds
  crashed=.array~new
  do id over live
    p=poses[id];before[id]=p
    wind=.nil
    if windField\==.nil then do
      level=windField~levelAt(p[3])
      if windsByLevel~hasIndex(level) then wind=windsByLevel[level]
      else do;wind=windField~advance(p[3],tick+1);windsByLevel[level]=wind;end
    end
    if airframes[id]~KIND=='FIXED_WING' then movement=airframes[id]~propose(p,cmds[id],wind,powered[id])
    else movement=airframes[id]~propose(p,cmds[id],wind)
    after[id]=movement[1];sensorPackets[id]=movement[2];states[id]=movement[3]
    windPackets[id]=wind
    if states[id]['STATUS']=='STALL' then crashed~append(.array~of(id,'CRASHED_STALL'))
    else if \world~safeLine(p,after[id]) | \world~safePoint(after[id],2) then crashed~append(.array~of(id,'CRASHED_SCENE'))
  end
  /* Separation over craft still flying after scene checks. */
  hit=.directory~new
  do c over crashed;hit[c[1]]=c[2];end
  do i=1 to live~items-1
    do j=i+1 to live~items
      a=live[i];b=live[j]
      if hit~hasIndex(a) | hit~hasIndex(b) then iterate
      gap=self~closestConcurrent(before[a],after[a],before[b],after[b])
      minSeparation=min(minSeparation,gap)
      if gap<4 then do
        hit[a]='CRASHED_SEPARATION_'||b;hit[b]='CRASHED_SEPARATION_'||a
      end
    end
  end
  /* Debit and commit every craft that flew this tick (crashed craft pay
   * for the tick they flew, then stay where they were). */
  if batteryEnabled then do id over live
    ignored=batteries[id]~debit('FLIGHT',prices[id])
  end
  do id over live
    if hit~hasIndex(id) then do
      self~knockOut(id,hit[id]);after[id]=before[id]
      states[id]['STATUS']=hit[id]
    end
    else ignored=airframes[id]~commit(states[id])
    states[id]['POWERED']=powered[id]
    if batteryEnabled then states[id]['PRICE']=prices[id]
    else states[id]['PRICE']=0
  end
  /* Targets fly the same interval as the craft. */
  moving=.false
  if var('movers') then moving=(movers\==.nil)
  tBefore=.directory~new
  if moving then do
    do num=1 to world~targets~items;tBefore[num]=world~targets[num]~copy;end
    ignored=movers~advance(windsByLevel,tick+1,claims)
    windLevels=windsByLevel
  end
  tick+=1
  do id over live;poses[id]=after[id];end
  lastPackets=sensorPackets;lastWind=windPackets;lastStates=states
  arrivals=.array~new
  do num=1 to 5
    if claims~hasIndex(num) then iterate
    target=world~targets[num]
    winner='';time=2
    do id over live
      if hit~hasIndex(id) then iterate
      if moving then fraction=self~contactMoving(before[id],after[id],tBefore[num],target)
      else fraction=self~contactFraction(before[id],after[id],target)
      if fraction<0 then iterate
      if fraction<time then do;time=fraction;winner=id;end
    end
    if winner=='' then iterate
    claims[num]=winner
    event=.directory~new
    event['STEP']=tick;event['TARGET']=num;event['WINNER']=winner
    event['INTERCEPT_FRACTION']=time;event['TIE']='NONE'
    arrivals~append(event);events~append(event)
  end
  if claims~items==5 then status='COMPLETE'
  else if self~activeIds~items==0 then status='ALL_OUT'
  return arrivals

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
::method airframeKind
  expose airframes
  use strict arg id
  if \airframes~hasIndex(id) then raise syntax 88.900 array('unknown craft')
  return airframes[id]~KIND
::method airframeSpec
  expose airframes
  use strict arg id
  if \airframes~hasIndex(id) then raise syntax 88.900 array('unknown craft')
  return airframes[id]~spec
::method batteryReport
  expose batteryEnabled batteries
  use strict arg id
  if \batteryEnabled then raise syntax 88.900 array('battery disabled on this referee')
  if \batteries~hasIndex(id) then raise syntax 88.900 array('unknown craft meter')
  return batteries[id]~report
::method debitRadio
  expose batteryEnabled batteries craftStatus
  use strict arg id
  if \batteryEnabled then return .true
  if \batteries~hasIndex(id) then return .false
  if craftStatus[id]\=='ACTIVE' then return .false
  b=batteries[id]
  return b~debit('RADIO',b~radioCost)
::method debitRemote
  expose batteryEnabled batteries craftStatus
  use strict arg id
  if \batteryEnabled then return .true
  if \batteries~hasIndex(id) then return .false
  if craftStatus[id]\=='ACTIVE' then return .false
  b=batteries[id]
  return b~debit('LOOKUP',b~remoteCost)
::method advance
  raise syntax 88.900 array('squad referee: use advanceAll(directory)')
