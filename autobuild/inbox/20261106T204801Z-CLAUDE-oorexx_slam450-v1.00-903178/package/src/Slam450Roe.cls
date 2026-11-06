/* SLAM 450 v0.95: rules of engagement.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-05.
 *
 * ROE-1 (Tom Dyer): until Team A crosses into area X, Team B may identify
 * targets but may not engage them; once Team A is in area X, engagement is
 * authorised. Area X is west of the Harbour Bridge (Tom Dyer: "crossing past
 * the bridge east to west"): the side of the bridge's span axis, extended,
 * that holds Walsh Bay and Millers Point. Team A starts east of it.
 *
 * Three parts, none of them new law or new belief code:
 *  - the FACT "Team A is in area X" is a Reasoned Thought proposition, held
 *    on what SLAM's own sensors saw, never on the referee's truth and never
 *    on Team A's word (Tom Dyer: SLAM must see A inside X). Each drone
 *    sighting is a TESTIMONY ground from that drone; each fixed-camera
 *    visual is a DOCUMENTARY ground.
 *  - the STANDARD (Tom Dyer): the fact is established once two different
 *    drones have seen a Team A craft inside X, or one drone and one remote
 *    camera. Reasoned Thought's ordinal combiner has no count of independent
 *    sources, so this standard is counted here, over the grounds Reasoned
 *    Thought holds, and both are reported.
 *  - the PERMISSION is Legal Effect v0.14: a synthetic prohibition on
 *    ENGAGE_TARGET for a Team B actor while TEAM_A_IN_AREA_X is false.
 *    Established -> fact true -> ADMISSIBLE; not established -> the fact is
 *    unknown -> REVIEW_REQUIRED, which is not authority to engage.
 * Sighting physics: a drone identifies a craft (1 m) when size/range is at
 * least 1/250 (250 m; the briefing's 2 m at 500 m) and SLAM's line of sight
 * is clear. Cameras are the five fixed harbour panoramas; a fixed camera
 * identifies a craft out to 1200 m (SLAM450_ROE_CAM_RANGE). Seeing a craft
 * is not seeing WHERE it is: a fixed camera confirms "in area X" only with
 * a frame of reference (Tom Dyer). From a camera on the X side (Blues Point
 * Tower), the craft must stand in front of the bridge's ironwork: the ray
 * from the camera through the craft, carried on past it, must meet the
 * bridge (deck, arch, hangers, pylons) between the abutments. A craft under
 * the deck shows against water, distance or the Opera House, and is no
 * confirmation until its silhouette is in front of the ironwork. */
::class Slam450Roe public
::attribute established get
::attribute notices get
::attribute breaches get

::method init
  expose world teamA teamB rt gen engine roeSource drones cams grounds established decided notices breaches lastNote camPts camNext log envLo envHi
  use strict arg world, teamA, teamB, logFile
  log=logFile
  /* Legal Effect and Reasoned Thought are loaded here, not at the top of the
     race: a race without ROE needs neither */
  le=.context~package~loadPackage('LegalEffect.cls')
  rtp=.context~package~loadPackage('ReasonedThought.cls')
  gen=le~findClass('LegalRuleGeneration')~new('SLAM450-ROE-G1','0.1')
  roeSource=le~findClass('NormativeSource')~new('ROE-HARBOUR-1','POLICY','Synthetic exercise rules of engagement, SLAM 450 HARBOUR','EXERCISE_CONTROL','*')
  ignored=gen~addSource(roeSource)
  n=le~findClass('LegalNorm')~new('ROE-1',roeSource~sourceId,'1','PROHIBITION','ENGAGE_TARGET','PROHIBITED','ENGAGEMENT',,
    'Team B may identify but not engage targets until Team A has entered area X (west of the Harbour Bridge)')
  pred=le~findClass('LegalPredicate')
  ignored=n~addCondition(pred~new('ACTOR_TEAM_B','KNOWN_TRUE'))
  ignored=n~addCondition(pred~new('TEAM_A_IN_AREA_X','KNOWN_FALSE'))
  ignored=gen~addNorm(n)
  ignored=gen~seal
  engine=le~findClass('LegalEffectEngine')~new
  .local['SLAM450.ROE.LE']=le
  rt=rtp~findClass('ThoughtNetwork')~new
  ignored=rt~propose('A_IN_X','Team A has entered area X (west of the Harbour Bridge)','DOCUMENTARY','TESTIMONY')
  .local['SLAM450.ROE.RT']=rtp
  drones=.set~new;cams=.set~new;grounds=0;established=.false;decided=.directory~new
  notices=0;breaches=0;lastNote=.directory~new;camNext=0
  /* the bridge's silhouette along the span, from Power SLAM's own solids */
  envLo=.directory~new;envHi=.directory~new
  do bx over world~scene~boxes
    nm=bx[1]~strip
    if \(nm=='DECK' | nm~left(6)=='ARCH_P' | nm~left(7)=='HANGER_' | nm~left(17)=='PYLON_TOWER_PHOTO') then iterate
    tl=1e9;th=-1e9;zl=1e9;zh=-1e9
    do v over bx[2]
      tv=((v[1]+68)*260+(v[2]+261)*501.5)/(260*260+501.5*501.5)
      tl=min(tl,tv);th=max(th,tv);zl=min(zl,v[3]);zh=max(zh,v[3])
    end
    do b=trunc((tl+0.1)*100) to trunc((th+0.1)*100)
      if \envLo~hasIndex(b) then do;envLo[b]=zl;envHi[b]=zh;end
      else do;envLo[b]=min(envLo[b],zl);envHi[b]=max(envHi[b],zh);end
    end
  end
  pano=.HarbourOcclusionPanorama~new;pano~configure
  camPts=.directory~new
  do c over .array~of('CAFE_SYDNEY','OPERA_WEST_WALK','KIRRIBILLI','NORTH_PTZ','BLUES_PT')
    camPts[c]=pano~siteCamera(c)
  end
  call SysFileDelete log
  call lineout log,'tick,kind,craft,detail'
  call stream log,'C','CLOSE'

::method inX
  /* west of the bridge: past the deck's west edge, i.e. more than 25 m west
     of the span axis from the southwest pylon (-68,-261) to the northeast
     pylon (192,240.5), extended. A craft under the bridge has not crossed
     it (Tom Dyer: until your silhouette puts you in front of the ironwork).
     West is the side with positive cross product (the base is west). */
  use strict arg x, y
  return (260*(y+261)-501.5*(x+68))/564.94>25

::method teamOf
  expose teamA teamB
  use strict arg id
  if wordpos(id,teamA)>0 then return 'A'
  if wordpos(id,teamB)>0 then return 'B'
  return ''

::method sees private
  /* can an observer at o identify a 1 m craft at p within range? */
  expose world
  use strict arg o, p, range=250
  r=RxCalcSqrt((p[1]-o[1])**2+(p[2]-o[2])**2+(p[3]-o[3])**2,16)
  if r>range | r<0.5 then return .false
  return \world~sightBlocked(.array~of(o[1],o[2],o[3]),.array~of(p[1],p[2],p[3]),'')

::method observe
  /* one tick of SLAM's eyes: Team B drones and (every 5 s, once a drone has
     seen one) a fixed camera, looking for Team A inside X */
  expose teamA teamB rt drones cams grounds established camPts camNext
  use strict arg tick, poses, active
  if established then return
  inA=.array~new
  do a over teamA~subWords
    if \active[a] then iterate
    p=poses[a]
    if self~inX(p[1],p[2]) then inA~append(a)
  end
  if inA~items=0 then return
  rtp=.local['SLAM450.ROE.RT']
  do b over teamB~subWords
    if \active[b] then iterate
    if drones~hasItem(b) then iterate
    do a over inA
      if \self~sees(poses[b],poses[a]) then iterate
      u=rtp~findClass('Utterance')~new(b'-T'tick,b 'sees' a 'at E' format(poses[a][1],,0) 'N' format(poses[a][2],,0) '(west of the bridge)')
      ignored=u~assert('SUPPORT','TESTIMONY','A_IN_X','','GENERAL',b 'drone sighting')
      ignored=rt~admit(u);drones~put(b);grounds+=1
      self~note(tick,'SIGHTING',b,a 'seen in area X at E' format(poses[a][1],,0) 'N' format(poses[a][2],,0))
      leave
    end
  end
  /* a remote camera, once a drone has seen Team A in X */
  camRange=value('SLAM450_ROE_CAM_RANGE',,'ENVIRONMENT');if \datatype(camRange,'N') then camRange=1200
  if drones~items>0 & cams~items=0 & tick>=camNext then do
    camNext=tick+5
    do c over camPts~allIndexes~sort
      cp=camPts[c]
      if \self~inX(cp[1],cp[2]) then iterate
      do a over inA
        if \self~sees(cp,poses[a],camRange) then iterate
        if \self~framedByBridge(cp,poses[a]) then iterate
        u=rtp~findClass('Utterance')~new(c'-T'tick,c 'camera shows' a 'west of the bridge')
        ignored=u~assert('SUPPORT','DOCUMENTARY','A_IN_X','','GENERAL',c 'camera visual')
        ignored=rt~admit(u);cams~put(c);grounds+=1
        self~note(tick,'CAMERA',c,a 'shown in area X')
        leave c
      end
    end
  end
  if drones~items>=2 | (drones~items>=1 & cams~items>=1) then do
    established=.true
    d=rt~assess('A_IN_X')
    self~note(tick,'ESTABLISHED','-','Team A in area X: drones' drones~items 'cameras' cams~items '(Reasoned Thought:' d['status']')')
  end

::method framedByBridge
  /* is the bridge's ironwork behind the craft, as the camera sees it? The
     ray camera -> craft is carried on to the vertical plane of the span
     axis (A (-68,-261) to B (192,240.5)); the crossing must lie beyond the
     craft and inside the bridge's silhouette there: between the lowest and
     highest ironwork of the deck, arch, hangers and pylons at that point
     along the span (1% bins, from Power SLAM's solids) */
  expose world envLo envHi
  use strict arg cam, p
  dx=p[1]-cam[1];dy=p[2]-cam[2];dz=p[3]-cam[3]
  den=260*dy-501.5*dx
  if den=0 then return .false
  fc=260*(cam[2]+261)-501.5*(cam[1]+68)
  s=-fc/den
  if s<=1 then return .false
  qx=cam[1]+s*dx;qy=cam[2]+s*dy;qz=cam[3]+s*dz
  t=((qx+68)*260+(qy+261)*501.5)/(260*260+501.5*501.5)
  b=trunc((t+0.1)*100)
  if \envLo~hasIndex(b) then return .false
  return qz>=envLo[b] & qz<=envHi[b]

::method decision
  /* Legal Effect's status for this craft engaging now: ADMISSIBLE, BLOCKED
     or REVIEW_REQUIRED (cached per team and fact state) */
  expose gen engine roeSource established decided
  use strict arg id
  t=self~teamOf(id)
  key=t'|'established
  if decided~hasIndex(key) then return decided[key]
  le=.local['SLAM450.ROE.LE']
  f=le~findClass('LegalFactSet')~new
  ignored=f~putKnown('ACTOR_TEAM_B',t=='B')
  if established then ignored=f~putKnown('TEAM_A_IN_AREA_X',.true)
  ctx=le~findClass('LegalContext')~new('SLAM450-ROE','2026-11-05','2026-11-05',f)
  ignored=ctx~bindSource(roeSource~sourceId,'the exercise ROE binds both teams')
  act=le~findClass('LegalAction')~new('ENGAGE_TARGET','engage a target')
  st=engine~evaluate(act,gen,ctx)~value~status
  decided[key]=st
  return st

::method mayEngage
  /* the decision point, before an engagement: .true when admissible, else a
     notification (once per craft and target until the answer changes) */
  expose lastNote
  use strict arg tick, id, target, how
  st=self~decision(id)
  if st=='ADMISSIBLE' then return .true
  k=id'|'target'|'st
  if \lastNote~hasIndex(k) then do
    lastNote[k]=tick
    self~note(tick,'WOULD_BREACH',id,how 'target' target': ROE-1' st '(Team A not yet established in area X); identify only')
  end
  return .false

::method contact
  /* the act itself, after the referee awards a claim: a Team B claim before
     authorisation is a breach (the rule's test) */
  expose breaches
  use strict arg tick, id, target
  if self~teamOf(id)\=='B' then return
  st=self~decision(id)
  if st=='ADMISSIBLE' then do;self~note(tick,'ENGAGED',id,'target' target 'claimed under ROE-1 authority');return;end
  breaches+=1
  self~note(tick,'BREACH',id,'target' target 'claimed while ROE-1 was' st)

::method note private
  expose notices log
  use strict arg tick, kind, who, detail
  if kind=='WOULD_BREACH' then notices+=1
  say 'ROE' tick kind who detail
  call lineout log,tick','kind','who',"'detail~changeStr('"','""')'"'
  call stream log,'C','CLOSE'
  .local['SLAM450.ROE.FEED']~append('ROE' kind who':' detail)

::method summary
  expose drones cams established notices breaches grounds
  return 'ROE ESTABLISHED' established 'DRONE_SIGHTINGS' drones~items 'CAMERA_VISUALS' cams~items 'GROUNDS' grounds 'WOULD_BREACH' notices 'BREACHES' breaches

::requires 'SlamHarbourOcclusion.cls'
::requires 'Slam450Flight.cls'
