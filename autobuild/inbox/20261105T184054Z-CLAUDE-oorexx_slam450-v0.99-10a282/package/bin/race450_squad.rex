/* SLAM 450 v0.89 squad race: RED = A1 SLAM quad + A4 LLM quad;
 * BLUE = A2 SLAM quad + A3 SLAM fixed-wing + A5 LLM quad.
 * Architecture: Tom Dyer. Squad runner + LLM seat: Claude (Opus 5.5).
 * Derived from the v0.88 trio runner; SLAM pilot logic is unchanged.
 * Native simultaneous flight.
 * Simulator state is strictly private to referee and renderer. No pilot,
 * tactics, peer or radio sees world coordinates or actual wind vectors.
 */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg prefix seed course maxSteps windMode batteryMode lookupMode llmMode eyesMode projection thinkMode seatMode targetMode mapMode groundMode modelMode avoidMode llmCraft visRange searchMode visFixMode utcStart orderMode orderEvery orderDelay
if prefix=='' then prefix='slam450_trio'
if seed=='' then seed=45045
if course=='' then course='LEGACY'
if maxSteps=='' then maxSteps=75
if windMode=='' then windMode='WIND'
if batteryMode=='' then batteryMode='BATTERY'
if lookupMode=='' then lookupMode='AUTO'
/* v0.88: A3 airframe (QUAD = v0.87-style all-quad race, FIXED_WING = the
   team flies one quad (A2) + one fixed-wing (A3)); projection lane for the
   Maths panorama projector (AUTO, PURE = bit-exact reference, NUMPY). */
/* v0.92: airframe of the LLM-crewed craft H1/H2 (A4/A5): QUAD (default) or
   WING (the same fixed-wing airframe as A3). In PILOT seat a wing's LLM
   commands pass a flight envelope (no stall, no hover, no side-slip). */
if llmCraft=='' then llmCraft='QUAD'
llmCraft=llmCraft~upper
if llmCraft\=='QUAD' & llmCraft\=='WING' then raise syntax 88.900 array('LLM craft QUAD or WING')
llmAirframe='QUAD';if llmCraft=='WING' then llmAirframe='FIXED_WING'
/* v0.92 identification range (m): 0 = legacy unlimited; 500 = Tom Dyer's
   normal briefing. Search: ORBIT (legacy SLAM search) or SWEEP (SLAM flies
   to the least-searched sector of its own flight book when nothing is seen). */
if visRange=='' then visRange=0
if \datatype(visRange,'N') then raise syntax 88.900 array('visibility range must be metres (0 = unlimited)')
.local['SLAM450.ID_RANGE']=visRange
if searchMode=='' then searchMode='ORBIT'
searchMode=searchMode~upper
/* RECALL = SWEEP plus flying back to targets in the flight book (own
   sightings, triangulated bearings, navigator entries) when the chosen
   target is out of view. */
if wordpos(searchMode,'ORBIT SWEEP RECALL')=0 then raise syntax 88.900 array('search mode ORBIT, SWEEP or RECALL')
/* v0.92 visual position fix for SLAM (Tom Dyer): OFF (default) or ON.
   ON: every 10 s each SLAM pilot converts its own panorama to a 96x24
   feature surface and looks it up in the precomputed 50 m grid
   (data/<course>_visualfix_50m_alt{15,40,70}.txt); with the radio
   altimeter on (AVOID ON) the fix is refined from the nearest landmark
   top's elevation in a 960x242 detail frame. 0.03 per grid fix and 0.03
   per detail request (a radio message's price), category VISUAL. */
if visFixMode=='' then visFixMode='OFF'
visFixMode=visFixMode~upper
if visFixMode\=='OFF' & visFixMode\=='ON' then raise syntax 88.900 array('visual fix OFF or ON')
VISUAL_FIX_COST=0.03;VISUAL_DETAIL_COST=0.03
/* v0.93 race clock (Tom Dyer: Sun and Moon at time and date): UTC start,
   e.g. 2026-11-04T23:00:00Z, + 1 s per tick. Empty = no clock, no sky.
   Ephemeris: Slam450Ephemeris (stand-in with Moonsault's call shape). */
skyOn=.false;clock=.nil;eph=.nil;SKY_FIX_COST=0.03;ephName='NONE'
HARBOUR_LAT=-33.852;HARBOUR_LON=151.210
if utcStart~upper=='OFF' then utcStart=''  /* v0.94: OFF keeps the sky off when later arguments follow */
if utcStart\=='' then do
  clock=.Slam450RaceClock~new(utcStart);skyOn=.true
  /* Moonsault's provider when its src is on hand (MOONSAULT_SRC), else the
     stand-in with the same shape. Both are predictions only. */
  msrc=value('MOONSAULT_SRC',,'ENVIRONMENT')
  if msrc\=='' & stream(msrc'/MoonsaultEphemeris.cls','C','QUERY EXISTS')\=='' then eph=.Slam450MoonsaultEphemeris~new(msrc)
  else eph=.Slam450Ephemeris~new
  ephName=eph~class~id
  .local['SLAM450.SKYON']='ON'
end
if llmMode=='' then llmMode='STANDIN'
llmMode=llmMode~upper
/* NONE = control run: BACKSEAT craft flown by SLAM with no navigator. */
pilotMode=llmMode;if llmMode=='NONE' then pilotMode='STANDIN'
if eyesMode=='' then eyesMode='EYES'
if thinkMode=='' then thinkMode='OFF'
if seatMode=='' then seatMode='PILOT'
seatMode=seatMode~upper
/* v0.90 targets: STATIC (v0.89 behaviour) or MOVING[:airspeed m/s]. */
if targetMode=='' then targetMode='STATIC'
parse upper var targetMode targetKind ':' targetSpeed
if targetSpeed=='' then targetSpeed=3.0
if targetKind\=='STATIC' & targetKind\=='MOVING' then raise syntax 88.900 array('target mode STATIC or MOVING[:speed]')
.local['SLAM450.TARGETS']=targetKind
.local['SLAM450.TARGET_SPEED']=targetSpeed
/* v0.90 LLM map: NOMAP (default, as v0.89) or MAP (static plan map). */
if mapMode=='' then mapMode='NOMAP'
mapMode=mapMode~upper
if mapMode\=='MAP' & mapMode\=='NOMAP' then raise syntax 88.900 array('map mode MAP or NOMAP')
if mapMode=='MAP' & wordpos(course~upper,'LEGACY QUAYSIDE HILL PYLONS HARBOUR')==0 then raise syntax 88.900 array('the plan map crop is defined for LEGACY, QUAYSIDE, HILL, PYLONS and HARBOUR only')
.local['SLAM450.MAP']=mapMode
.local['SLAM450.AVOID']='OFF'
/* v0.91 ground: NOGROUND (default; boxes + sea only, as v0.90) or GROUND
   (Power SLAM v0.40 heights + water words, Slam450Ground). */
if groundMode=='' then groundMode='NOGROUND'
groundMode=groundMode~upper
if groundMode\=='GROUND' & groundMode\=='NOGROUND' then raise syntax 88.900 array('ground mode GROUND or NOGROUND')
.local['SLAM450.GROUND']=groundMode
/* v0.92: which Claude model sits in H1/H2 (HAIKU default, SONNET), and
   SLAM's visual obstacle reflex (OFF default = v0.91 behaviour, ON). */
if modelMode=='' then modelMode='HAIKU'
modelMode=modelMode~upper
select
  when modelMode=='HAIKU' then llmModel='claude-haiku-5-5'
  when modelMode=='SONNET' then llmModel='claude-sonnet-5-5'
  otherwise raise syntax 88.900 array('model mode HAIKU or SONNET')
end
if avoidMode=='' then avoidMode='OFF'
avoidMode=avoidMode~upper
if avoidMode\=='ON' & avoidMode\=='OFF' then raise syntax 88.900 array('avoid mode ON or OFF')
avoidOn=(avoidMode=='ON')
.local['SLAM450.AVOID']=avoidMode
reflex=.directory~new;sensorUse=.directory~new;gps=.directory~new;gpsUse=.directory~new;gpsText=.directory~new
if seatMode\=='PILOT' & seatMode\=='BACKSEAT' then raise syntax 88.900 array('seat mode PILOT or BACKSEAT')
eyesMode=eyesMode~upper
if projection=='' then projection='AUTO'
.local['SLAM450.PROJECTION']=projection~upper
/* Fail loudly if the output prefix directory does not exist (v0.86 wrote
   nothing and still exited 5). */
outDir=filespec('location',prefix)
if outDir\=='' then if \sysIsFileDirectory(outDir) then raise syntax 88.900 array('output directory does not exist:' outDir)
/* lineout appends: clear this prefix's previous run outputs first, or a
   rerun silently concatenates two races into one evidence set. */
call SysFileTree prefix||'_*.csv','stale.','FO'
do i=1 to stale.0; call SysFileDelete stale.i; end
call SysFileTree prefix||'_*.txt','stale.','FO'
do i=1 to stale.0; call SysFileDelete stale.i; end
batteryOn=(batteryMode~upper=='BATTERY')
if batteryMode~upper\=='BATTERY' & batteryMode~upper\=='LEGACY' then raise syntax 88.900 array('battery mode invalid')
windOn=(windMode~upper=='WIND')
groundModel=.nil
if groundMode=='GROUND' then do
  /* Affine fit and verification over the harbour core (+/- ~3 km). */
  groundModel=.Slam450Ground~new(value('SLAM450_HARBOUR_WORDS',,'ENVIRONMENT'),.array~of(-1500,1500,-2000,1000))
  say 'GROUND' groundModel~heightsFile 'RESIDUAL_M' format(groundModel~maxResidual,,4) 'VERIFIED' groundModel~checkedPoints 'EXCLUDED' groundModel~excludedPoints
end
world=.Slam450World~new(seed,course,.false,groundModel)
.local['SLAM450.MAP_SCALE']=.Slam450PlanMap~crop(world)[5]
layout=.array~new
/* v0.97 SLAM450_SQUAD: 3V3 adds Foxtrot (A6), a SLAM-flown fixed wing, to
   Red, so each team flies two quads and one fixed wing (Red: Alpha, Delta,
   Foxtrot; Blue: Bravo, Echo, Charlie). Default 3V3 when CONTROL_TEAMS=ON,
   otherwise the legacy five (5). Tom Dyer's line-up, 2026-11-05. */
squadMode=value('SLAM450_SQUAD',,'ENVIRONMENT')~upper
if squadMode=='' then do
  squadMode='5';if value('CONTROL_TEAMS',,'ENVIRONMENT')~upper=='ON' then squadMode='3V3'
end
if squadMode\=='5' & squadMode\=='3V3' then raise syntax 88.900 array('SLAM450_SQUAD 5 or 3V3')
specs=.array~of('A1 RED QUAD','A2 BLUE QUAD','A3 BLUE FIXED_WING','A4 RED' llmAirframe,'A5 BLUE' llmAirframe)
if squadMode=='3V3' then specs~append('A6 RED FIXED_WING')
allIds=.array~new
do spec over specs
  parse var spec i t a
  d=.directory~new;d['ID']=i;d['TEAM']=t;d['AIRFRAME']=a;layout~append(d);allIds~append(i)
end
/* v0.95 rules of engagement (SLAM450_ROE=ON): ROE-1, Team B (BLUE) may
   identify but not engage until SLAM has seen Team A (RED) west of the
   Harbour Bridge; Team A starts east of it (SLAM450_ROE_EAST, default
   E 150 N -650, 30 m). Needs Legal Effect v0.14 and Reasoned Thought v0.1
   on REXX_PATH. */
roeOn=(value('SLAM450_ROE',,'ENVIRONMENT')~upper=='ON')
if roeOn then do
  re=value('SLAM450_ROE_EAST',,'ENVIRONMENT');if re=='' then re='150 -650 30'
  .local['SLAM450.ROE_EAST']=re
end
ref=.Slam450SquadReferee~new(world,layout,windOn,batteryOn)
/* v0.92 flight books: each craft's own belief of where it is, what it has
   searched and where it saw targets (Slam450Belief). Started at the craft's
   own observed start; never fed truth afterwards. */
books=.directory~new;noSee=.directory~new;lostFor=.directory~new
visCharge=.directory~new;visFixes=.directory~new;visDetails=.directory~new;skyFixes=.directory~new
fixSet=.nil;landmarks=.nil
if visFixMode=='ON' then do
  files=.array~new
  do a over .array~of(15,40,70)
    files~append('data/'||course~lower||'_visualfix_50m_alt'||a||'.txt')
  end
  base=filespec('location',.context~package~name)||'../'
  do i=1 to files~items;files[i]=base||files[i];end
  fixSet=.Slam450VisualFixSet~new(files)
  landmarks=.Slam450Landmarks~new(world)
  say 'VISUALFIX GRID' fixSet~points 'POINTS' fixSet~layers~items 'LAYERS' fixSet~dataBytes 'BYTES' landmarks~items~items 'LANDMARKS'
end
bookRange=500;if visRange>0 then bookRange=visRange
do id over allIds
  books[id]=.Slam450Belief~new(ref~poseOf(id),.Slam450PlanMap~crop(world),bookRange,50)
  noSee[id]=0
end
movers=.nil
if targetKind=='MOVING' then do
  movers=.Slam450TargetMovers~new(world,seed,targetSpeed)
  ref~attachMovers(movers)
end
slamIds=.array~of('A1','A2','A3');llmIds=.array~of('A4','A5')
/* v0.90 BACKSEAT: SLAM flies H1/H2's quads; Haiku advises from the back seat. */
if seatMode=='BACKSEAT' then slamIds=.array~of('A1','A2','A3','A4','A5')
if squadMode=='3V3' then slamIds~append('A6')
advice=.directory~new;adviseNow=.true
labels=.directory~new;labels['A4']='H1';labels['A5']='H2'
llm=.directory~new;llmFixed=.directory~new;llmWantsLookup=.directory~new;envelopeNote=.directory~new
client=.nil;rates=.AnthropicModelCatalog~new
if llmMode=='LIVE' then client=.AnthropicMessageClient~new(.AnthropicRuntimeConfig~fromEnvironment)
/* v0.94 orders: OFF (default), SCRIPT:file or LIVE. Control, a remote
   commander with a map and no camera, gives plain-English orders; Boston
   Crab checks each one; SLAM relays it at once whatever the check says.
   orderEvery: seconds between Control's looks (default 20). orderDelay:
   radio delay in SCRIPT mode (default 3 s); LIVE uses the measured time of
   the model call plus the check. Needs CRAB_WORK (a private copy of
   oorexx_slam_bostoncrab v0.8+) and ALCHEMY_REPO_ROOT. */
if orderMode=='' then orderMode='OFF'
parse var orderMode orderKind ':' .
orderKind=orderKind~upper
if wordpos(orderKind,'OFF SCRIPT LIVE')=0 then raise syntax 88.900 array('order mode OFF, SCRIPT:file or LIVE')
orderOn=(orderKind\=='OFF')
if orderEvery=='' then orderEvery=20
if orderDelay=='' then orderDelay=3
if orderKind=='LIVE' & client==.nil then client=.AnthropicMessageClient~new(.AnthropicRuntimeConfig~fromEnvironment)
hk='quad';if llmCraft=='WING' then hk='fixed-wing'
redNote='RED = you (H1, LLM' hk') + A1 (SLAM quad, autonomous, no radio). Rivals BLUE = A2 quad + A3 fixed-wing + H2' hk'.'
blueNote='BLUE = you (H2, LLM' hk') + A2 (SLAM quad) + A3 (SLAM fixed-wing); A2/A3 run their own buddy radio and you can read its summary. Rivals RED = A1 quad + H1' hk'.'
if mapMode=='MAP' then do
  /* Rendered once, before any pilot is built; identical for every seed. */
  planMap=.Slam450PlanMap~new(world)
  mapProvider=.nil;if .ForeignPngProvider~available then mapProvider=.ForeignPngProvider~new
  .local['SLAM450.MAP_PNG']=planMap~pngBase64(mapProvider)
  .local['SLAM450.MAP_W']=planMap~width;.local['SLAM450.MAP_H']=planMap~height
end
llm['A4']=.Slam450LlmPilot~new('A4','H1','RED',redNote,pilotMode,eyesMode,llmModel,client,rates,'AUTO',thinkMode)
llm['A5']=.Slam450LlmPilot~new('A5','H2','BLUE',blueNote,pilotMode,eyesMode,llmModel,client,rates,'AUTO',thinkMode)
do id over llmIds;ignored=llm[id]~useAirframe(llmAirframe);end
do id over llmIds;ignored=llm[id]~attachBook(books[id]);end
if seatMode=='BACKSEAT' then do id over llmIds;ignored=llm[id]~becomeNavigator;end
fwc=.directory~new
typeMem=.directory~new;beliefs=.directory~new
cam=.Slam450Camera~new(world)
feeds=.Slam450TrioCameraService~new(world,batteryOn,ref)
energyPolicy=.Slam450BatteryPolicy~new
energyMemory=.directory~new
radio=.Slam450BuddyRadio~new(ref)
ids=allIds
buddies=.array~of('A2','A3')
pilots=.directory~new;tactics=.directory~new;observer=.directory~new
peer=.directory~new;lastBid=.directory~new;lastCalculated=.directory~new
lastOwnCommand=.directory~new;lastTgt=.directory~new;lastAction=.directory~new
lastDecision=.directory~new;wins=.directory~new
vision=.Slam450Vision~new
separation=.Slam450VisualSeparation~new
peer['A2']=.Slam450BuddyPeer~new('A2',48)
peer['A3']=.Slam450BuddyPeer~new('A3',48)
 do id over ids
  typeMem[id]=.Slam450AircraftTypeMemory~new(8)
  if slamIds~hasItem(id) then do
    pilots[id]=.Slam450LearningPilot~new(.Slam450VisualMemory~new(48))
    tactics[id]=.Slam450RaceTactics~new(id,48)
    observer[id]=.Slam450RivalAir~new(id,48)
  end
  lastOwnCommand[id]=.nil;lastTgt[id]=0;lastAction[id]='NONE'
  lastDecision[id]='';wins[id]=0
  if batteryOn then do
    energyMemory[id]=.Slam450BatteryMemory~new(48)
    call lineout prefix||'_'||id||'_battery.csv',,
      'tick,remaining,percent,flight_used,remote_used,radio_used,est_cruise_steps,yaw_cmd,forward_cmd,up_cmd,side_cmd,lookup_granted,radio_sent,energy_idea,airframe,airspeed,throttle,flight_mode,flight_price,powered,fc_mode,bank_deg,gamma_deg'
  end
  call lineout prefix||'_'||id||'_truth_ORACLE_ONLY.csv',,
    'tick,x_east_m,y_north_m,z_m,heading_deg,objective,action,min_separation_m,airspeed_mps'
  if ref~airframeKind(id)=='FIXED_WING' then fwc[id]=.Slam450FixedWingFlightComputer~new
  call lineout prefix||'_'||id||'_tactics.csv',,
    'tick,chosen_target,source,action,negotiated_leader,agreement_status'
  if windOn then do
    call lineout prefix||'_'||id||'_sensors.csv',,
      'tick,level,pitot_mps,cup_mps,sail,wind_idea'
    call lineout prefix||'_'||id||'_wind_ORACLE_ONLY.csv',,
      'tick,level,bearing_deg,speed_mps,east_mps,north_mps'
  end
 end
 do id over buddies;lastBid[id]=-1;lastCalculated[id]=-1;end
call lineout prefix||'_claims.csv','tick,contact_fraction,target,winner,tie'
call lineout prefix||'_team_radio.csv','tick,from,to,kind,epoch,event,leader,A2_target,A3_target'
if batteryOn then call lineout prefix||'_team_target_costs.csv',,
  'tick,event,sender,epoch,target,estimate_energy,risk,confidence,theory,reported_battery,reported_reserve'
if batteryOn then call lineout prefix||'_team_energy.csv',,
  'tick,event,from,to,sample_tick,remaining,capacity,percent,window_turns,delta_flight,delta_remote,delta_radio,burn_rate,cruise_steps_est,theory,confidence'
call lineout prefix||'_fixed_camera.csv','tick,aircraft,camera,status,reason'
call lineout prefix||'_airframes.csv','aircraft,airframe,capacity,min_speed,max_speed,cruise_speed,cruise_cost,climb_cost_per_m,hover_cost,stall_speed,glide_ratio,physics,projection_lane'
 do id over ids
  sp=ref~airframeSpec(id);stall='';glide=''
  if sp~hasIndex('STALL_SPEED') then stall=sp['STALL_SPEED']
  if sp~hasIndex('GLIDE_RATIO') then glide=sp['GLIDE_RATIO']
  call lineout prefix||'_airframes.csv',id||','||sp['AIRFRAME']||','||sp['CAPACITY']||','||sp['MIN_SPEED']||','||sp['MAX_SPEED']||','||,
    sp['CRUISE_SPEED']||','||sp['CRUISE_COST']||','||sp['CLIMB_COST_PER_M']||','||sp['HOVER_COST']||','||stall||','||glide||','||sp['PHYSICS']||','||cam~projectionLane
 end
call stream prefix||'_airframes.csv','C','CLOSE'
/* v0.97: the line-up for the plan renderer: one row per craft, however many
   (written with orders on, so the plain race's files are unchanged) */
if orderOn then do
  call lineout prefix||'_squad.csv','aircraft,team,airframe,call_sign'
  cs=.array~of('Alpha','Bravo','Charlie','Delta','Echo','Foxtrot')
  do id over ids
    call lineout prefix||'_squad.csv',id','ref~teams[id]','ref~airframeKind(id)','cs[id~substr(2)]
  end
  call stream prefix||'_squad.csv','C','CLOSE'
end
/* Shared pilot knowledge: basic normal operating parameters by type. */
hints=.Slam450FlightWindowHints~new
do line over hints~describe; call lineout prefix||'_flight_window_hints.txt',line; end
call stream prefix||'_flight_window_hints.txt','C','CLOSE'
call lineout prefix||'_course_ORACLE_ONLY.csv','target,region,east_m,north_m,z_m'
 do i=1 to 5
  p=world~targets[i]
  call lineout prefix||'_course_ORACLE_ONLY.csv',,
    i||','||world~courseAreas[i]||','||p[1]||','||p[2]||','||p[3]
 end
if movers\==.nil then do
  call lineout prefix||'_targets_track_ORACLE_ONLY.csv',.Slam450TargetMovers~header
  do row over movers~drain;call lineout prefix||'_targets_track_ORACLE_ONLY.csv',row;end
  call lineout prefix||'_wind_levels_ORACLE_ONLY.csv','tick,level,east_mps,north_mps'
end
say 'SLAM450 SQUAD START' seed course windMode batteryMode lookupMode 'LLM' llmMode eyesMode 'THINK' thinkMode 'SEAT' seatMode 'TARGETS' targetKind 'MAP' mapMode 'GROUND' groundMode 'MODEL' llmModel 'AVOID' avoidMode 'LLMCRAFT' llmCraft 'IDRANGE' visRange 'SEARCH' searchMode 'VISFIX' visFixMode 'UTC' utcStart 'EPHEMERIS' ephName 'PROJECTION' cam~projectionLane 'GAP' ref~minSeparation
if orderOn then do
  crabWork=value('CRAB_WORK',,'ENVIRONMENT')
  if crabWork=='' | \sysIsFileDirectory(crabWork) then raise syntax 88.900 array('orders need CRAB_WORK: a private copy of oorexx_slam_bostoncrab v0.8+')
  crabCheck=filespec('location',.context~package~name)||'crab450_check.sh'
  sit=.Slam450Situation~new(world)
  /* v0.95 CONTROL_TEAMS=ON: one commander per team, Red (Alpha, Delta) and
     Blue (Bravo, Charlie, Echo); otherwise one Control for all five */
  teamsMode=(value('CONTROL_TEAMS',,'ENVIRONMENT')~upper=='ON')
  tlist='ALL';if teamsMode then tlist='RED BLUE'
  cmdrs=.directory~new;nextTurnT=.directory~new;feedbackT=.directory~new;teamIds=.directory~new
  do tm over tlist~subWords
    tid='';tnames=''
    do id over ids
      if tm=='ALL' | ref~teams[id]==tm then do;tid=tid id;tnames=tnames sit~craftNames[id];end
    end
    teamIds[tm]=tid~strip
    note=''
    /* v0.97: the lists come from the line-up, and each team is told which of
       its drones is a fixed wing */
    otm='RED';if tm=='RED' then otm='BLUE'
    onames='';wnames=''
    do id over ids
      if ref~teams[id]==otm then onames=onames sit~craftNames[id]
      if ref~teams[id]==tm & ref~airframeKind(id)=='FIXED_WING' then wnames=wnames sit~craftNames[id]
    end
    wnote=''
    do w over wnames~subWords
      wnote=wnote||'0a'x||w 'is a fixed wing: fast, but it cannot stop or hover; told to hold or wait, it circles over the place.'
    end
    if tm=='RED' then note='You command Team Red:' andList(tnames)'. Team Blue ('onames~strip~changeStr(' ',', ')') is the other team, with its own commander.'||wnote
    if tm=='BLUE' then do
      note='You command Team Blue:' andList(tnames)'. Team Red ('onames~strip~changeStr(' ',', ')') is the other team, with its own commander.'||wnote
      if roeOn then note=note||'0a'x||'Rules of engagement, ROE-1: until SLAM confirms that Team Red has crossed into area X (west of the Harbour Bridge,'||,
        ' past the deck''s west edge), your drones may identify targets but must not engage (touch) them. SLAM checks every order and'||,
        ' every engagement, tells you when an order or move would breach ROE-1, and records any breach. It tells you when ROE-1 authority is given.'||,
        ' SLAM confirms the crossing only from what it sees: two of your drones each seeing a Red drone west of the bridge, or one of your'||,
        ' drones plus a fixed harbour camera that shows the Red drone in front of the bridge. A Red report of its own position does not count.'
    end
    cmdrs[tm]=.Slam450Commander~new(orderMode,client,llmModel,rates,tnames~strip,note)
    /* CONTROL_LANGUAGE_RED / _BLUE: that team's Control speaks it (uk) */
    cmdrs[tm]~language=value('CONTROL_LANGUAGE_'tm,,'ENVIRONMENT')
    nextTurnT[tm]=0;feedbackT[tm]=.array~new
  end
  cmdr=cmdrs[tlist~word(1)]
  /* Control's map: the PNG drawn by bin/control450_map.rex from Tombstone's
     ELVIS terrain (CONTROL_MAP_PNG); LIVE needs it, SCRIPT does not read it */
  cmap=value('CONTROL_MAP_PNG',,'ENVIRONMENT')
  if cmap\=='' then do
    if stream(cmap,'C','QUERY EXISTS')=='' then raise syntax 88.900 array('CONTROL_MAP_PNG not found:' cmap)
    mp=charin(cmap,1,chars(cmap))~encodeBase64;call stream cmap,'C','CLOSE'
    do tm over cmdrs~allIndexes;cmdrs[tm]~mapPng=mp;end
  end
  else if orderKind=='LIVE' then raise syntax 88.900 array('LIVE orders need CONTROL_MAP_PNG (bin/control450_map.rex)')
  tkeys=.array~new
  do d over sit~places;if d['KIND']=='target' then tkeys~append(d['KEY']);end
  ord=.directory~new;orderQueue=.array~new;nextTurn=0;feedback=.array~new;orderN=0
  plan=.directory~new;planSig=.directory~new
  /* v0.97: targets a craft has been told not to go for ("do not search Ruby") */
  banned=.directory~new
  ordDir=prefix||'_orders'
  call SysMkDir ordDir
  of=prefix||'_orders.csv'
  call lineout of,'n,tick_sent,tick_due,craft,order,verdict,action,place,reading,llm_s,crab_s,flag'
  call stream of,'C','CLOSE'
  say 'ORDERS' orderMode 'EVERY' orderEvery 'CRAB' crabWork
end
if roeOn then do
  ta='';tb=''
  do id over ids;if ref~teams[id]=='RED' then ta=ta id;else tb=tb id;end
  .local['SLAM450.ROE.FEED']=.array~new
  roe=.Slam450Roe~new(world,ta~strip,tb~strip,prefix||'_roe.csv')
  say 'ROE ON TEAM_A' ta~strip 'TEAM_B' tb~strip 'AREA_X west of the Harbour Bridge START_A' .local['SLAM450.ROE_EAST']
end
 do loop=1 to maxSteps
  if ref~status\=='RUNNING' then leave
  if skyOn then .local['SLAM450.SKY']=eph~sunMoon(clock~unixAt(ref~tick),HARBOUR_LAT,HARBOUR_LON)
  poses=.directory~new;frames=.directory~new;commands=.directory~new
  lookupDone=.directory~new;radioSent=.directory~new
  do id over ids;lookupDone[id]=.false;radioSent[id]=0;end
  targets=.directory~new;available=.directory~new
  do n=1 to 5
    if ref~available(n) then available[n]=.true
  end
  do id over ids
    poses[id]=ref~poseOf(id)
  end
  /* Each craft gets its own panorama: every live rival drawn as R, every
   * live teammate as P, with true silhouettes. Never xyz. */
  do id over ids
    if \ref~active(id) then iterate
    others=.directory~new;okinds=.directory~new
    rl=.array~new;rk=.array~new;pl=.array~new;pk=.array~new
    do who over ids
      if who==id | \ref~active(who) then iterate
      if ref~teams[who]==ref~teams[id] then do;pl~append(poses[who]);pk~append(ref~airframeKind(who));end
      else do;rl~append(poses[who]);rk~append(ref~airframeKind(who));end
    end
    if rl~items>0 then do;others['R']=rl;okinds['R']=rk;end
    if pl~items>0 then do;others['P']=pl;okinds['P']=pk;end
    frames[id]=cam~renderAt(poses[id],480,121,.false,ref~claims,others,.nil,okinds)
  end
  /* Pilot side: aircraft type is inferred from those pixels only. */
  do id over ids;if ref~active(id) then beliefs[id]=typeMem[id]~observe(frames[id],ref~tick);end
  current=ref~nextAvailable(0)
  after=ref~nextAvailable(current)
  if after==0 then after=current
  epoch=trunc(ref~tick/16)
  /* Bid and send only own image evidence; private notes never shared. */
  do id over buddies
    if \ref~active(id) then iterate
    delivered=radio~receive(id,ref~tick)
    do m over delivered
      result=peer[id]~absorb(m)
      if result=='OBS_STORED' & m~hasIndex('RIVAL_TYPE') then ,
        ignored=typeMem[id]~absorbPeer('R',m['RIVAL_TYPE'])
      if batteryOn & m['KIND']=='ENERGY' then do
        call lineout prefix||'_team_energy.csv',,
          ref~tick||','||result||','||m['FROM']||','||m['TO']||','||,
          m['SAMPLE_TICK']||','||m['REMAINING']||','||m['CAPACITY']||','||,
          m['PERCENT']||','||m['WINDOW_TURNS']||','||m['DELTA_FLIGHT']||','||,
          m['DELTA_REMOTE']||','||m['DELTA_RADIO']||','||m['BURN_RATE']||','||,
          m['CRUISE_STEPS_ESTIMATE']||','||m['THEORY']||','||m['CONFIDENCE']
      end
      lead='';t2='';t3=''
      if m~hasIndex('LEADER') then lead=m['LEADER']
      if m~hasIndex('A2_TARGET') then t2=m['A2_TARGET']
      if m~hasIndex('A3_TARGET') then t3=m['A3_TARGET']
      call lineout prefix||'_team_radio.csv',,
        ref~tick||','||m['FROM']||','||m['TO']||','||m['KIND']||','||m['EPOCH']||','||result||','||lead||','||t2||','||t3
    end
  end
  do id over buddies
    if \ref~active(id) then iterate
    if epoch>lastBid[id] then do
      packet=.nil
      if ref~tick>0 & windOn then packet=ref~lastPackets[id]
      if batteryOn then offer=peer[id]~localOffer(,
        frames[id],available,epoch,packet,ref~batteryReport(id),energyMemory[id],ref~tick)
      else offer=peer[id]~localOffer(frames[id],available,epoch,packet)
      sent=radio~send(offer,ref~tick)
      if sent=='QUEUED_NEXT_TICK' then radioSent[id]+=1
      call lineout prefix||'_team_radio.csv',,
        ref~tick||','||id||','||peer[id]~peerID||',BID,'||epoch||','||sent||',,, '
      if batteryOn then do
        do t=1 to 5
          if \available~hasIndex(t) then iterate
          call lineout prefix||'_team_target_costs.csv',,
            ref~tick||',BID,'||id||','||epoch||','||t||','||,
            offer['COSTS'][t]||','||offer['RISKS'][t]||','||,
            offer['CONFIDENCES'][t]||','||offer['THEORIES'][t]||','||,
            offer['BID_REMAINING']||','||offer['BID_RESERVE']
        end
      end
      lastBid[id]=epoch
    end
    if lastCalculated[id]<epoch then do
      ack=peer[id]~calculate(epoch,available)
      if ack\==.nil then do
        sent=radio~send(ack,ref~tick)
        if sent=='QUEUED_NEXT_TICK' then radioSent[id]+=1
        call lineout prefix||'_team_radio.csv',,
          ref~tick||','||id||','||peer[id]~peerID||',ACK,'||epoch||','||sent||','||ack['LEADER']||','||ack['A2_TARGET']||','||ack['A3_TARGET']
        if batteryOn then do
          d=peer[id]~current
          do craft over buddies
            t=d[craft||'_TARGET']
            call lineout prefix||'_team_target_costs.csv',,
              ref~tick||',PROPOSED,'||craft||','||epoch||','||t||','||,
              d[craft||'_COST']||','||d[craft||'_RISK']||',,'||,
              d[craft||'_THEORY']||',,'
          end
        end
        lastCalculated[id]=epoch
      end
    end
  end
  /* Periodic peer reports: energy meter + observed consumption + theory.
     Snapshot is made from OWN permitted meter/memory, never referee truth.
     Delivery has one tick latency and accepted traffic is charged 0.03. */
  if batteryOn & ref~tick//12==0 then do
    do id over buddies
      if \ref~active(id) then iterate
      m=peer[id]~energyReport(epoch,ref~tick,ref~batteryReport(id),energyMemory[id])
      sent=radio~send(m,ref~tick)
      if sent=='QUEUED_NEXT_TICK' then radioSent[id]+=1
      call lineout prefix||'_team_radio.csv',,
        ref~tick||','||id||','||peer[id]~peerID||',ENERGY,'||epoch||','||sent||',,, '
      if sent=='QUEUED_NEXT_TICK' then do
        call lineout prefix||'_team_energy.csv',,
          ref~tick||',SENT,'||id||','||peer[id]~peerID||','||,
          m['SAMPLE_TICK']||','||m['REMAINING']||','||m['CAPACITY']||','||,
          m['PERCENT']||','||m['WINDOW_TURNS']||','||m['DELTA_FLIGHT']||','||,
          m['DELTA_REMOTE']||','||m['DELTA_RADIO']||','||m['BURN_RATE']||','||,
          m['CRUISE_STEPS_ESTIMATE']||','||m['THEORY']||','||m['CONFIDENCE']
      end
    end
  end
  /* Back-seat navigators: every 4 ticks and right after any claim. */
  if seatMode=='BACKSEAT' & llmMode\=='NONE' & (adviseNow | ref~tick//4==0) then do
    pendingAdvice=.directory~new
    do id over llmIds
      if \ref~active(id) then iterate
      fixed=.nil
      if llmFixed~hasIndex(id) then do;fixed=llmFixed[id];llmFixed~remove(id);end
      ignored=llm[id]~prepare(frames[id],fixed)
      vis='not visible'
      if lastTgt[id]>0 then if (.Slam450Vision~new)~observe(frames[id],lastTgt[id])\==.nil then vis='visible'
      ps='flying toward target' lastTgt[id] '('vis'), last action' lastAction[id]'.'
      if lastOwnCommand~hasIndex(id) then if lastOwnCommand[id]\==.nil then ps=ps 'Last command yaw' lastOwnCommand[id][1] 'forward' lastOwnCommand[id][2] 'climb' lastOwnCommand[id][3]'.'
      feed='';if id=='A5' then feed=blueFeed(peer,typeMem)
      mtr=ref~batteryReport(id)
      if avoidOn then do
        /* The navigator hears the SLAM pilot's own callouts and altimeter. */
        cl='nothing to report';if reflex~hasIndex(id) then if reflex[id]~lastCallouts\=='' then cl=reflex[id]~lastCallouts
        mtr['GPWS']='SENSORS (the SLAM pilot runs its scanner and radio altimeter, and heeds or ignores warnings by its own rules). GPWS (advisory): 'cl'.'
        if gpsText~hasIndex(id) then if gpsText[id]\=='' then mtr['GPS']=gpsText[id]
      end
      msg=.message~new(llm[id],'ADVISE','A',.array~of(ref~tick,frames[id],mtr,available,claimsText(ref),feed,ps))
      msg~start;pendingAdvice[id]=msg
    end
    do id over pendingAdvice~allIndexes;advice[id]=pendingAdvice[id]~result;end
    adviseNow=.false
  end
  /* v0.94 Control: deliver orders that have arrived, then (on Control's
     turn) take new orders, check them with Boston Crab and send them. The
     race clock does not wait: an order is due delay seconds after Control
     looked at the map. */
  if orderOn then do
    /* deliver: every step due now, grouped by craft, becomes that craft's
       new plan (a new turn's orders replace the old plan; the very same
       orders again keep their progress) */
    keep=.array~new;newPlans=.directory~new
    do q over orderQueue
      if q['DUE']>ref~tick then do;keep~append(q);iterate;end
      if \ref~active(q['CRAFT']) then iterate
      if \newPlans~hasIndex(q['CRAFT']) then newPlans[q['CRAFT']]=.array~new
      newPlans[q['CRAFT']]~append(q)
    end
    orderQueue=keep
    do craft over newPlans~allIndexes
      np=newPlans[craft];sig='';do q over np;sig=sig'|'q['TEXT']'#'q['PART'];end
      if planSig~hasIndex(craft) then if planSig[craft]==sig then iterate
      planSig[craft]=sig;plan[craft]=np
      call nextStep craft
    end
    do tm over tlist~subWords
    if ref~tick>=nextTurnT[tm] then do
    cmdr=cmdrs[tm];feedback=feedbackT[tm]
      claimedKeys='';reported=''
      do n=1 to 5
        if ref~claims~hasIndex(n) then claimedKeys=claimedKeys tkeys[n]
        do id over teamIds[tm]~subWords
          if books[id]~sighting(n)\==.nil then do;reported=reported tkeys[n];leave;end
        end
      end
      act=.directory~new;bpos=.directory~new
      do id over ids
        act[id]=ref~active(id)
        bpos[id]=.array~of(books[id]~x,books[id]~y,poses[id][3],poses[id][4])
      end
      if roeOn then if tm\=='RED' then do;do r_ over .local['SLAM450.ROE.FEED'];feedback~append(r_);end;.local['SLAM450.ROE.FEED']=.array~new;end
      fb='Since your last look:'
      if feedback~items=0 then fb=fb 'nothing new.'
      else do f over feedback;fb=fb||'0a'x||'  '||f;end
      feedback~empty
      res=cmdr~turn(ref~tick,sit~mapText(books,act,reported,claimedKeys,ref~tick,teamIds[tm]),fb)
      if res['STATUS']\=='OK' then say 'ORDER CALL' ref~tick res['STATUS']
      crabS=0
      if res['ORDERS']~items>0 then do
        dir=ordDir'/t'ref~tick;if tm\=='ALL' then dir=ordDir'/'tm~lower'_t'ref~tick
        call SysMkDir dir
        ignored=sit~write(dir,world,bpos,act,reported,.true,ref~tick,ownOf(tm))
        st=dir'/story.txt'
        do o over res['ORDERS']
          call lineout st,'# Order — Control to' o[1]
          call lineout st,o[2]
        end
        call stream st,'C','CLOSE'
        t0=time('E')
        address system 'bash' crabCheck crabWork dir '>' dir'/check.log 2>&1'
        crc=rc;crabS=time('E')-t0
        relay=.array~new
        if crc=0 then do while lines(dir'/out/relay.txt')>0;relay~append(linein(dir'/out/relay.txt'));end
        call stream dir'/out/relay.txt','C','CLOSE'
        flags=crabFlags(dir'/out/orders.txt')
        tones=crabTones(dir'/out/orders.words');toneSaid=.set~new
        delay=orderDelay
        if orderKind=='LIVE' then delay=max(1,trunc(res['LATENCY_S']+crabS+0.999))
        if crc\=0 then do
          /* one order that stops Boston Crab must not take the others down
             with it: check them one at a time; one that still stops it goes
             out unread (UNABLE), and Control is told */
          say 'ORDER CHECK FAILED rc='crc dir '- checking each order alone'
          relay=.array~new;flags=.array~new;base=0
          do k=1 to res['ORDERS']~items
            o=res['ORDERS'][k];dk=dir'_'k
            call SysMkDir dk
            ignored=sit~write(dk,world,bpos,act,reported,.true,ref~tick,ownOf(tm))
            call lineout dk'/story.txt','# Order — Control to' o[1]
            call lineout dk'/story.txt',o[2]
            call stream dk'/story.txt','C','CLOSE'
            address system 'bash' crabCheck crabWork dk '>' dk'/check.log 2>&1'
            if rc=0 then do
              fk=crabFlags(dk'/out/orders.txt');mx=0
              do while lines(dk'/out/relay.txt')>0
                ln=linein(dk'/out/relay.txt')
                parse var ln rn '|' rest
                relay~append(rn+base'|'rest);mx=max(mx,rn)
              end
              call stream dk'/out/relay.txt','C','CLOSE'
              do f_ over fk;flags~append(f_);end
              base=base+mx
            end
            else do
              base=base+1
              relay~append(base'|1|control|'o[1]~lower'|NOT CHECKED (Boston Crab stopped on this order)|NONE|UNABLE||Boston Crab could not read it|'o[2])
              flags~append('Boston Crab stopped on this order')
              say 'ORDER UNREADABLE' ref~tick o[1] o[2]
            end
          end
          crabS=time('E')-t0
          if orderKind=='LIVE' then delay=max(1,trunc(res['LATENCY_S']+crabS+0.999))
        end
        /* one plan step per part of each sentence Boston Crab read */
        readback=.directory~new;lastPl=.directory~new
        do rl over relay
          parse var rl rn '|' rp '|' . '|' rto '|' v '|' a '|' pl '|' rot '|' rdg '|' rtext '|' rwo
          craft='';do id over ids;if sit~craftNames[id]~lower==rto~lower then craft=id;end
          if craft=='' then iterate
          /* an action with no place of its own ("Виконайте обліт" after "search
             near the Opera House") works at the place the craft was last given
             in this message */
          if pl=='' & a\=='NONE' & a\=='DONT' & a\=='IF' & lastPl~hasIndex(craft) then do;pl=lastPl[craft];rdg='the same place,' placeName(sit,pl);end
          if pl\=='' & pl\=='UNABLE' & a\=='DONT' & a\=='IF' then lastPl[craft]=pl
          orderN+=1
          q=.directory~new;q['N']=orderN;q['SENT_N']=rn;q['PART']=rp;q['CRAFT']=craft;q['TEXT']=rtext
          q['SENT']=ref~tick;q['DUE']=ref~tick+delay;q['VERDICT']=v;q['ACTION']=a;q['PLACE']=pl
          q['ROT']=rot;q['READING']=rdg;q['FLAG']='';if flags~items>=rn then q['FLAG']=flags[rn]
          /* v0.98 (Boston Crab v0.19): "without stop" - an orbit or search that never ends on its own */
          q['WITHOUT']=rwo~strip;q['NOSTOP']=(wordpos('stop',q['WITHOUT'])>0 | wordpos('halt',q['WITHOUT'])>0)
          q['X']='';q['Y']='';q['TNUM']=0;q['SIZE']=0;q['OUTSIDE']=0
          if pl~left(5)=='grid:' then do
            parse var pl 'grid:' gx ':' gy
            q['X']=gx;q['Y']=gy;q['Z']=30
          end
          /* v0.97: hold where it is: where its flight book puts it when the order is sent */
          else if pl=='here' then do
            q['X']=bpos[craft][1];q['Y']=bpos[craft][2];q['Z']=bpos[craft][3]
          end
          else if pl\=='' & pl\=='UNABLE' then do
            pd=sit~place(pl)
            if pd\==.nil then do;q['X']=pd['X'];q['Y']=pd['Y'];q['Z']=pd['Z'];q['SIZE']=pd['SIZE'];end
            q['TNUM']=tkeys~index(pl);if q['TNUM']==.nil then q['TNUM']=0
          end
          /* SLAM's own check: a place outside the race field */
          if q['X']\=='' then do
            fbx=world~fieldBox
            if q['X']<fbx[1] | q['X']>fbx[2] | q['Y']<fbx[3] | q['Y']>fbx[4] then q['OUTSIDE']=1
          end
          orderQueue~append(q)
          call lineout of,orderN','ref~tick','q['DUE']','craft','csvq(rtext)','csvq(v)','a'#'rp','pl','csvq(rdg)','format(res['LATENCY_S'],,2)','format(crabS,,2)','csvq(q['FLAG'])
          call stream of,'C','CLOSE'
          say 'ORDER SENT' ref~tick 'DUE' q['DUE'] sit~craftNames[craft] rtext '|' v '|' a rot pl '|' rdg
          /* SLAM's readback: what the craft will do, step by step, at once */
          step=a~lower;if rot\=='' then step=step rot~lower
          if a=='DONT' then step='do not' rdg~word(2)~lower~strip(,':')
          /* v0.98: a conditional order is never flown: SLAM cannot evaluate the condition */
          if a=='IF' then do
            step='if ...' rdg~word(2)~lower~strip(,':')
            if pl\=='UNABLE' & pl\=='' then step=step placeName(sit,pl)
            step=step '(conditional: SLAM cannot evaluate the condition; not acted on)'
          end
          else if a=='DONT' then do
            if pl\=='UNABLE' & pl\=='' then step=step '('placeName(sit,pl)')'
            else if pl=='UNABLE' then step=step '('rdg~substr(pos(':',rdg)+1)~strip')'
          end
          else if pl=='UNABLE' | pl=='' then step=step '(cannot act:' rdg')'
          else do
            step=step placeName(sit,pl)
            if pos('nearest',rdg)>0 then step=step '('rdg')'
            if q['OUTSIDE'] then step=step '(outside the race field: works from the field edge)'
            if q['WITHOUT']\=='' then do w_ over q['WITHOUT']~subWords
              if w_=='stop' | w_=='halt' then step=step 'without stopping (until the next order)'
              else step=step 'without' w_||'ing'
            end
          if roeOn then if q['TNUM']>0 then if roe~teamOf(craft)=='B' then if roe~decision(craft)\=='ADMISSIBLE' then do
            step=step '(ROE-1: identify only until SLAM sees Team A west of the bridge)'
            ignored=roe~mayEngage(ref~tick,craft,q['TNUM'],'order to')
          end
          end
          if \readback~hasIndex(craft) then readback[craft]=''
          if readback[craft]=='' then readback[craft]=step;else readback[craft]=readback[craft]'; then' step
          if v\=='CLEAR' then fbq(craft)~append(sit~craftNames[craft] 'got "'rtext'". SLAM:' v'.' q['FLAG'])
          /* v0.98: Boston Crab's tone line (swearing): shown to Control once per order, never an order */
          if tones~hasIndex(rn) & \toneSaid~hasItem(rn) then do
            toneSaid~put(rn);fbq(craft)~append('Tone heard in the order to' sit~craftNames[craft]':' tones[rn]'.')
            say 'ORDER TONE' ref~tick sit~craftNames[craft] tones[rn]
          end
        end
        do craft over readback~allIndexes~sort
          fbq(craft)~append('Readback' sit~craftNames[craft]':' readback[craft]'.')
          say 'READBACK' ref~tick sit~craftNames[craft]':' readback[craft]
        end
      end
      nextTurnT[tm]=ref~tick+orderEvery
      if orderKind=='LIVE' then nextTurnT[tm]=ref~tick+max(orderEvery,trunc(res['LATENCY_S']+crabS+0.999))
    end
    end
  end
  /* v0.95 ROE: SLAM's eyes on Team A, every tick */
  if roeOn then do
    act2=.directory~new;do id over ids;act2[id]=ref~active(id);end
    roe~observe(ref~tick,poses,act2)
  end
  do id over slamIds
    if \ref~active(id) then iterate
    ownPacket=.nil
    if ref~tick>0 & windOn then ownPacket=ref~lastPackets[id]
    /* Other craft silhouettes are observations, not referee access. */
    ignored=observer[id]~observe(frames[id],ref~tick,ownPacket,lastOwnCommand[id],0,.nil,beliefs[id]['R']['TYPE'])
    selected=0;hold=.false;source='SOLO_VISUAL_POLICY';leader='NONE';agreement='NONE'
    if id=='A2' | id=='A3' then do
      selected=peer[id]~assignment(available)
      if selected>0 then do
        source='PEER_ACKNOWLEDGED';leader=peer[id]~current['LEADER']
        agreement=peer[id]~current['STATUS']
      end
      /* A peer may commit to HOLD if its own cost estimates conclude
         that all outstanding targets threaten its battery reserve. */
      else if batteryOn & peer[id]~current\==.nil then do
        d=peer[id]~current
        if d['STATUS']=='COMMITTED' & d['ENERGY_AWARE'] & ,
           d[id||'_TARGET']==0 then do
          hold=.true;source='PEER_ENERGY_RESERVE_HOLD'
          leader=d['LEADER'];agreement=d['STATUS']
        end
      end
    end
    if advice~hasIndex(id) then do
      a=advice[id]
      if a['SPEED']=='HOLD' then do;hold=.true;source='HAIKU_BACKSEAT_HOLD';end
      else if a['TARGET']>0 then if ref~available(a['TARGET']) then do
        selected=a['TARGET'];source='HAIKU_BACKSEAT';lastAction[id]='NAVIGATOR_TARGET'
      end
    end
    if selected==0 & \hold then do
      if lastTgt[id]>0 then do
        if ref~available(lastTgt[id]) & ref~tick//5\==0 then selected=lastTgt[id]
      end
      if selected==0 then do
        decision=tactics[id]~choose(frames[id],current,after,ref~tick,beliefs[id]['R']['TYPE'])
        selected=decision['TARGET']
        if \ref~available(selected) then selected=current
        lastAction[id]=decision['ACTION'];lastDecision[id]=decision['DECISION_ID']
      end
    end
    if source=='PEER_ACKNOWLEDGED' then lastAction[id]='BUDDY_ASSIGNED'
    if selected\==lastTgt[id] | (source=='PEER_ACKNOWLEDGED' & ref~tick//16==2) then do
      call lineout prefix||'_'||id||'_tactics.csv',,
        ref~tick||','||selected||','||source||','||lastAction[id]||','||leader||','||agreement
      say 'DECISION' ref~tick id 'TARGET' selected source 'LEAD' leader
    end
    /* v0.94: an order naming a target makes it the craft's target */
    orderSteer=.false;orderGo=.false
    if orderOn then if ord~hasIndex(id) then do
      q=ord[id]
      if q['TNUM']>0 then do
        if ref~available(q['TNUM']) then do
          if selected\==q['TNUM'] then lastAction[id]='ORDER'
          selected=q['TNUM'];hold=.false
        end
        else do;fbq(id)~append(sit~craftNames[id] 'reports' placeName(sit,q['PLACE']) 'is claimed.');call stepDone id;end
      end
      else if q['X']\=='' then orderSteer=.true
    end
    /* v0.97: a prohibition on a target, at the same decision point as ROE-1:
       the craft's own choice moves to the nearest target it has booked that
       it may go for, else the lowest-numbered one; none left, it holds */
    if orderOn then if selected>0 then if banned~hasIndex(id) then if banned[id]~hasItem(selected) then do
      was=selected;selected=0;bestD=''
      do n=1 to world~targets~items
        if banned[id]~hasItem(n) | \ref~available(n) then iterate
        sg=books[id]~sighting(n);dd=1e9
        if sg\==.nil then dd=RxCalcSqrt((sg['X']-books[id]~x)**2+(sg['Y']-books[id]~y)**2,16)
        if bestD=='' then do;selected=n;bestD=dd;end
        else if dd<bestD then do;selected=n;bestD=dd;end
      end
      if selected==0 then hold=.true
      if lastTgt[id]\==selected then say 'ORDER KEPT' ref~tick id 'not target' was '-> target' selected
    end
    /* v0.95 ROE: the decision point, before any engagement. Not admissible:
       the craft identifies (approaches, sees, books the target) and holds at
       stand-off: 60 m by its book, or when the target fills 12 pixels */
    roeHold=.false
    if roeOn then if selected>0 then if \roe~mayEngage(ref~tick,id,selected,'engage') then do
      sg=books[id]~sighting(selected)
      if sg\==.nil then if RxCalcSqrt((sg['X']-books[id]~x)**2+(sg['Y']-books[id]~y)**2,16)<=60 then roeHold=.true
      vo=(.Slam450Vision~new)~observe(frames[id],selected)
      if vo\==.nil then if max(vo['WIDTH'],vo['HEIGHT'])>=12 then roeHold=.true
    end
    lastTgt[id]=selected;targets[id]=selected
    if hold | roeHold then commands[id]=.array~of(0,0,0,0)
    else commands[id]=pilots[id]~control(frames[id],selected)
    /* v0.92 visual position fix (every 10 s, spread by craft number). */
    if fixSet\==.nil then if (ref~tick+id~substr(2))//10=0 then do
      surf=.Slam450VisualFix~surfaceOf(frames[id])
      agl='';amsl=.nil
      if avoidOn then do
        agl=radioAlt(world,poses[id])
        if datatype(agl,'N') then amsl=agl+fixSet~groundAt(books[id]~x,books[id]~y)
      end
      vr=fixSet~lookup(surf,books[id]~x,books[id]~y,books[id]~heading,amsl)
      if \visCharge~hasIndex(id) then do;visCharge[id]=0;visFixes[id]=0;visDetails[id]=0;end
      visCharge[id]+=VISUAL_FIX_COST;visFixes[id]+=1
      how='REFUSED';fx='';fy='';fh='';lmName='';lmRange='';lmEl=''
      if vr['ACCEPT'] then do
        fx=vr['X'];fy=vr['Y'];how='VISFIX'
        /* heading: the gyro (own-turn) heading unless the grid's column shift
           disagrees by more than two columns (7.5 deg) */
        fh=books[id]~heading;dh=abs(vr['HEADING']-fh);if dh>180 then dh=360-dh
        if dh>7.5 then fh=vr['HEADING']
        if avoidOn & datatype(agl,'N') then do
          det=cam~renderAt(poses[id],960,242,.false,ref~claims)
          visCharge[id]+=VISUAL_DETAIL_COST;visDetails[id]+=1
          lm=landmarks~refine(det,fx,fy,fh,agl+fixSet~groundAt(fx,fy))
          if lm['OK'] then do
            /* bench (v0.92b): a landmark top is worth using within 300 m, and
               the mean of the grid and landmark fixes beats either alone */
            if (lm['X']-fx)**2+(lm['Y']-fy)**2<80**2 & lm['RANGE']<=300 then do
              fx=(fx+lm['X'])/2;fy=(fy+lm['Y'])/2;how='VISFIX_LM'
            end
            lmName=lm['NAME'];lmRange=format(lm['RANGE'],,1);lmEl=format(lm['EL'],,2)
          end
        end
        ignored=books[id]~fix(ref~tick,fx,fy,fh,how)
      end
      f=prefix||'_'||id||'_visfix.csv'
      if stream(f,'C','QUERY EXISTS')=='' then call lineout f,'tick,mode,layer,score,second,ratio,candidates,accepted,fix_x,fix_y,fix_heading,landmark,landmark_range_m,landmark_el_deg'
      lay='';if vr~hasIndex('LAYER') then lay=vr['LAYER']
      sc='';if vr~hasIndex('SCORE') then sc=vr['SCORE']
      se='';if vr~hasIndex('SECOND') then se=vr['SECOND']
      ra='';if vr~hasIndex('RATIO') then ra=format(vr['RATIO'],,3)
      xs='';ys='';hs=''
      if fx\=='' then do;xs=format(fx,,2);ys=format(fy,,2);hs=format(fh,,2);end
      call lineout f,ref~tick','how','lay','sc','se','ra','vr['N']||','||(how\=='REFUSED')||','||xs','ys','hs','lmName','lmRange','lmEl
      call stream f,'C','CLOSE'
    end
    /* v0.93 sky heading: the Sun (else a visible Moon) in SLAM's own view
       against the ephemeris at the book's position gives an absolute
       heading. Every 10 s, offset 5 s from the visual fix. */
    if skyOn then if (ref~tick+id~substr(2))//10=5 then do
      sk=.local['SLAM450.SKY'];sym='';bodyName=''
      /* heading geometry: the body between 5 and 70 deg up (provider's
         headingCandidate when it gives one) */
      sunOk=(sk['SUN_UP'] & sk['SUN_ALT_APP']<70 & sk['SUN_ALT']>=5)
      moonOk=(sk['MOON_VISIBLE'] & sk['MOON_ALT_APP']<70 & sk['MOON_ALT']>=5)
      if sunOk then do;sym='S';bodyName='SUN';end
      else if moonOk then do;sym='M';bodyName='MOON';end
      if sym\=='' then do
        bb=.Slam450SkyFix~bodyBearing(frames[id],sym)
        if bb\==.nil then do
          rel=bb[1];nb=bb[2]
          blat=HARBOUR_LAT+books[id]~y/111200;blon=HARBOUR_LON+books[id]~x/92300
          pr=eph~sunMoon(clock~unixAt(ref~tick),blat,blon)
          hobs=.Slam450SkyFix~heading(pr[bodyName'_AZ'],rel)
          hd=abs(hobs-books[id]~heading);if hd>180 then hd=360-hd
          if \visCharge~hasIndex(id) then do;visCharge[id]=0;visFixes[id]=0;visDetails[id]=0;end
          if \skyFixes~hasIndex(id) then skyFixes[id]=0
          visCharge[id]+=SKY_FIX_COST;skyFixes[id]+=1
          ok=(hd<=20);hbook=books[id]~heading
          if ok then ignored=books[id]~headingFix(ref~tick,hobs,bodyName'_HEADING')
          sf=prefix||'_'||id||'_skyfix.csv'
          if stream(sf,'C','QUERY EXISTS')=='' then call lineout sf,'tick,body,alt_deg,az_pred_deg,pixels,rel_deg,heading_obs,heading_book,diff_deg,accepted'
          call lineout sf,ref~tick','bodyName','format(pr[bodyName'_ALT_APP'],,3)','format(pr[bodyName'_AZ'],,3)','nb','format(rel,,3)','format(hobs,,3)','format(hbook,,3)','format(hd,,3)','ok
          call stream sf,'C','CLOSE'
        end
      end
    end
    /* v0.92 SLAM flight book: write sightings; SWEEP to unsearched ground. */
    seenAny=.false
    do n over available~allIndexes
      o=vision~observe(frames[id],n)
      if o==.nil then iterate
      seenAny=.true
      sz=max(o['WIDTH'],o['HEIGHT'])
      if sz>3 then do
        ang=sz*360/frames[id]['WIDTH']
        rng=1/RxCalcTan(ang/2,16)
        ignored=books[id]~sightBearing(ref~tick,n,o['AZ'],rng,'SLAM_VIEW')
      end
      else ignored=books[id]~addRay(ref~tick,n,o['AZ'])
    end
    if seenAny then noSee[id]=0;else noSee[id]+=1
    /* v0.92 RECALL: chosen target out of view for 3 s -> fly to its book entry */
    recalled=.false
    if searchMode=='RECALL' & \hold & selected>0 then do
      if \lostFor~hasIndex(id) then lostFor[id]=0
      if vision~observe(frames[id],selected)==.nil then lostFor[id]+=1;else lostFor[id]=0
      if lostFor[id]>=3 then do
        sg=books[id]~sighting(selected)
        maxAge=120;if targetKind=='MOVING' then maxAge=45
        if sg\==.nil then if ref~tick-sg['TICK']<=maxAge then do
          ddx=sg['X']-books[id]~x;ddy=sg['Y']-books[id]~y;dd=RxCalcSqrt(ddx*ddx+ddy*ddy,16)
          if dd<25 then ignored=books[id]~forget(selected)
          else do
            gb=RxCalcArcTan(ddx/max(0.001,abs(ddy)));if ddy<0 then gb=180-gb
            rel=gb-books[id]~heading
            do while rel>180;rel-=360;end
            do while rel<-180;rel+=360;end
            commands[id]=.array~of(max(-25,min(25,rel)),7,commands[id][3],0)
            recalled=.true
            rf=prefix||'_'||id||'_recall.csv'
            if stream(rf,'C','QUERY EXISTS')=='' then call lineout rf,'tick,target,entry_tick,via,bel_dist_m,rel_deg'
            call lineout rf,ref~tick','selected','sg['TICK']','sg['VIA']','format(dd,,1)','format(rel,,1)
            call stream rf,'C','CLOSE'
          end
        end
      end
    end
    if (searchMode=='SWEEP' | searchMode=='RECALL') & \recalled & \hold & noSee[id]>=8 then do
      goal=books[id]~leastSearched
      gb=RxCalcArcTan((goal[1]-books[id]~x)/max(0.001,abs(goal[2]-books[id]~y)))
      if goal[2]<books[id]~y then gb=180-gb
      rel=gb-books[id]~heading
      do while rel>180;rel-=360;end
      do while rel<-180;rel+=360;end
      commands[id]=.array~of(max(-25,min(25,rel)),7,commands[id][3],0)
      call lineout prefix||'_'||id||'_sweep.csv',ref~tick||','||goal[4]||','||goal[3]||','||format(rel,,1)
      call stream prefix||'_'||id||'_sweep.csv','C','CLOSE'
    end
    /* v0.94: an order to a fixed place steers by the flight book. A place
       outside the race field is worked from the field edge nearest it. */
    if orderSteer then if ord~hasIndex(id) then do
      q=ord[id];fbx=world~fieldBox
      cx=max(fbx[1]+15,min(fbx[2]-15,q['X']));cy=max(fbx[3]+15,min(fbx[4]-15,q['Y']))
      bx=books[id]~x;by=books[id]~y;gx=cx;gy=cy
      dd=RxCalcSqrt((cx-bx)**2+(cy-by)**2,16)
      select
        when q['ACTION']=='SEARCH' then rad=max(120,q['SIZE']/2)
        when q['ACTION']=='ORBIT' then rad=max(80,q['SIZE']/2+40)+30
        when q['ACTION']=='MOVE' then rad=40
        otherwise rad=30
      end
      if dd<=rad & q['STATE']=='ACTIVE' then do
        q['STATE']='ARRIVED';q['ARRIVED']=ref~tick
        fbq(id)~append(sit~craftNames[id] 'is at' placeName(sit,q['PLACE']) '('q['ACTION']~lower')'||copies(', at the field edge',q['OUTSIDE'])'.')
      end
      more=(plan[id]~items>1);go=.true
      if q['STATE']=='ARRIVED' then select
        when q['ACTION']=='MOVE' then do;go=.false;call stepDone id;end
        when q['ACTION']=='SEARCH' then do
          if more & \q['NOSTOP'] & ref~tick-q['ARRIVED']>=30 then do;go=.false;call stepDone id;end
          else if noSee[id]<3 then go=.false
          else do
            ang=90*((ref~tick%15)//4);rr=rad*0.7
            gx=cx+rr*RxCalcSin(ang,16);gy=cy+rr*RxCalcCos(ang,16)
          end
        end
        when q['ACTION']=='ORBIT' then do
          if more & \q['NOSTOP'] & ref~tick-q['ARRIVED']>=60 then do;go=.false;call stepDone id;end
          else do
            /* bearing from the centre, then 25 deg on: clockwise seen from above */
            rr=rad-30;bc=RxCalcArcTan((bx-cx)/max(0.001,abs(by-cy)));if by<cy then bc=180-bc
            stepA=25;if q['ROT']=='CCW' then stepA=-25
            gx=cx+rr*RxCalcSin(bc+stepA,16);gy=cy+rr*RxCalcCos(bc+stepA,16)
            gx=max(fbx[1]+15,min(fbx[2]-15,gx));gy=max(fbx[3]+15,min(fbx[4]-15,gy))
          end
        end
        otherwise do
          go=.false;commands[id]=.array~of(0,0,0,0)
          if more & ref~tick-q['ARRIVED']>=20 then call stepDone id
        end
      end
      if go then do
        gb=RxCalcArcTan((gx-bx)/max(0.001,abs(gy-by)));if gy<by then gb=180-gb
        rel=gb-books[id]~heading
        do while rel>180;rel-=360;end
        do while rel<-180;rel+=360;end
        clb=0;if poses[id][3]<25 then clb=1;if poses[id][3]>70 then clb=-1
        /* v0.97: en route, 25 m over the highest map ground in the next 200 m
           (Tombstone ELVIS heights, which the craft carries). T3: Charlie
           held 27-32 m on an order and flew into a 38 m building on 23.5 m
           ground near E -238 N -561. */
        if groundModel\==.nil then do
          gTop=0
          do aheadM=0 to 200 by 25
            gs=groundModel~surface(bx+aheadM*RxCalcSin(gb,16),by+aheadM*RxCalcCos(gb,16))
            if gs<1e8 then gTop=max(gTop,gs)
          end
          want=min(90,max(30,gTop+25))
          /* v0.99: and clear of the mapped structures (the Power SLAM solids on
             Control's map and the craft's): the height nearest want whose line
             120 m ahead (15 s for a wing) is clear. T: Foxtrot circled the
             Harbour Bridge at 45 m, deck level by the south shore, and GPWS's
             PULL UP came too late for a wing. Over water this passes under the
             deck; over the approach spans, above them. */
          pNow=.array~of(poses[id][1],poses[id][2],poses[id][3],poses[id][4])
          aheadM=120;ax=poses[id][1]+aheadM*RxCalcSin(gb,16);ay=poses[id][2]+aheadM*RxCalcCos(gb,16)
          if \world~safeLine(pNow,.array~of(ax,ay,want,poses[id][4])) then do
            best=''
            do dz=10 to 60 by 10
              do sg over .array~of(1,-1)
                cz=want+sg*dz
                if cz<12 | cz>90 then iterate
                if world~safeLine(pNow,.array~of(ax,ay,cz,poses[id][4])) then do;best=cz;leave dz;end
              end
            end
            if best\=='' then want=best
          end
          if poses[id][3]<want-5 then clb=2
          else if poses[id][3]<want then clb=1
          else if poses[id][3]>want+5 then clb=-2
          else if poses[id][3]>want+30 & poses[id][3]>70 then clb=-1
          else clb=0
        end
        commands[id]=.array~of(max(-25,min(25,rel)),7,clb,0);orderGo=.true
      end
      call lineout prefix||'_'||id||'_order.csv',ref~tick','q['N']','q['ACTION']','q['ROT']','q['PLACE']','q['STATE']','format(dd,,1)
      call stream prefix||'_'||id||'_order.csv','C','CLOSE'
    end
    commands[id]=separation~adjust(id,frames[id],commands[id])
    if batteryOn then commands[id]=energyPolicy~adjust(commands[id],ref~batteryReport(id))
    if advice~hasIndex(id) then if advice[id]['SPEED']=='FAST' & \hold then ,
      if commands[id][2]>=3.5 then commands[id][2]=7
    if fwc~hasIndex(id) then do
      /* The wing's own flight computer turns intent into what a wing can fly. */
      meter=.nil
      if batteryOn then meter=ref~batteryReport(id)
      /* v0.94: en route on an order, the wing flies the order, not a target it sees */
      fsel=selected;if orderGo then fsel=0
      if roeHold then fsel=0
      commands[id]=fwc[id]~command(frames[id],fsel,commands[id],hold | roeHold,meter)
      if avoidOn then commands[id]=gpwsSlam(reflex,sensorUse,prefix,id,ref~airframeKind(id),ref~tick,frames[id],commands[id],selected,world,poses[id])
      ignored=pilots[id]~executed(commands[id])
    end
    else if avoidOn then commands[id]=gpwsSlam(reflex,sensorUse,prefix,id,ref~airframeKind(id),ref~tick,frames[id],commands[id],selected,world,poses[id])
  end
  /* v0.84 changes the old throttle: costly remote lookup may happen on
   * any turn. Battery price, not a shared five-step gate, restrains use. */
  /* v0.92 optional GPS: stepped every tick for every craft (warm/cold fix
     depends on time off); ON only when an LLM pilot or navigator asked. */
  if avoidOn then do id over ids
    if \ref~active(id) then iterate
    if \gps~hasIndex(id) then gps[id]=.Slam450Gps~new(seed*7+(id~substr(2)))
    want=.false
    if llm~hasIndex(id) & llmMode=='LIVE' then want=llm[id]~gpsWanted
    gd=gps[id]~step(ref~tick,want,poses[id],.Slam450PlanMap~crop(world))
    gpsText[id]=.Slam450Gps~text(gd)
    if want then gpsUse[id]=1
  end
  /* LLM seats decide in parallel (the simulation waits for both). */
  pending=.directory~new
  do id over llmIds
    if seatMode\=='PILOT' then leave
    if \ref~active(id) then iterate
    pk=.nil
    if ref~tick>0 & windOn then pk=ref~lastPackets[id]
    feed=''
    if id=='A5' then feed=blueFeed(peer,typeMem)
    fixed=.nil
    if llmFixed~hasIndex(id) then do;fixed=llmFixed[id];llmFixed~remove(id);end
    ignored=llm[id]~prepare(frames[id],fixed)
    mtr=ref~batteryReport(id)
    if avoidOn then do
      g=gpwsLlm(reflex,sensorUse,prefix,id,ref~airframeKind(id),ref~tick,world,poses[id],llm[id]~lastClimb,llm[id]~lastForward,llm[id]~scannerWanted,llm[id]~altimeterWanted)
      if g\=='' then mtr['GPWS']=g
      if gpsText~hasIndex(id) then if gpsText[id]\=='' then mtr['GPS']=gpsText[id]
    end
    if envelopeNote~hasIndex(id) then do;mtr['ENVELOPE']=envelopeNote[id];envelopeNote~remove(id);end
    if skyOn then mtr['UTC']=clock~isoAt(ref~tick)
    msg=.message~new(llm[id],'DECIDE','A',.array~of(ref~tick,frames[id],mtr,pk,available,claimsText(ref),feed,fixed))
    msg~start
    pending[id]=msg
  end
  do id over pending~allIndexes
    out=pending[id]~result
    commands[id]=out[1];targets[id]=out[2];llmWantsLookup[id]=out[3]
    if llmAirframe=='FIXED_WING' then commands[id]=wingEnvelope(prefix,id,ref~tick,commands[id],envelopeNote)
  end
  if batteryOn then do
    do id over llmIds
      if \ref~active(id) then iterate
      if seatMode=='BACKSEAT' then do
        if \advice~hasIndex(id) then iterate
        if \advice[id]['LOOKUP'] then iterate
        advice[id]['LOOKUP']=.false
      end
      else if \llmWantsLookup[id] then iterate
      others=.array~new
      do other over ids;if other\==id & ref~active(other) then others~append(poses[other]);end
      view=feeds~views[1+((ref~tick+id~substr(2,1))//feeds~views~items)]
      /* v0.92: a pilot or navigator may name the camera it wants. */
      named=llm[id]~takeView;if named\=='' then view=named
      response=feeds~request(id,view,ref~tick,ref~claims,poses[id],others)
      call lineout prefix||'_fixed_camera.csv',ref~tick||','||id||','||view||','||response['STATUS']||','||response['REASON']
      if response['STATUS']=='GRANTED' then do
        ignored=llm[id]~noteView(view)
        lookupDone[id]=.true;llmFixed[id]=response['FRAME']
        if seatMode=='BACKSEAT' then ignored=pilots[id]~consultFixedCamera(view,response['FRAME'],targets[id])
      end
    end
  end
  if batteryOn then do
    do id over slamIds
      if \ref~active(id) then iterate
      if targets[id]>0 & energyPolicy~wantRemote(ref~batteryReport(id),ref~tick,frames[id],targets[id],lookupMode) then do
        do
          others=.array~new
          do other over ids
            if other\==id & ref~active(other) then others~append(poses[other])
          end
          view=feeds~views[1+((ref~tick+id~substr(2,1))//feeds~views~items)]
          response=feeds~request(id,view,ref~tick,ref~claims,poses[id],others)
          call lineout prefix||'_fixed_camera.csv',,
            ref~tick||','||id||','||view||','||response['STATUS']||','||response['REASON']
          if response['STATUS']=='GRANTED' then do
            lookupDone[id]=.true
            ignored=pilots[id]~consultFixedCamera(view,response['FRAME'],targets[id])
          end
        end
      end
    end
  end
  else do
    if ref~tick>0 & ref~tick//5==0 then do
    turn=trunc(ref~tick/5)
    id=ids[1+((turn-1)//3)]
    others=.array~new
    do other over ids
      if other\==id then others~append(poses[other])
    end
    view=feeds~views[1+((turn-1)//feeds~views~items)]
    response=feeds~request(id,view,ref~tick,ref~claims,poses[id],others)
    call lineout prefix||'_fixed_camera.csv',,
      ref~tick||','||id||','||view||','||response['STATUS']||','||response['REASON']
    if response['STATUS']=='GRANTED' then do
      ignored=pilots[id]~consultFixedCamera(view,response['FRAME'],targets[id])
    end
  end
  end
  do id over ids;if commands~hasIndex(id) then lastOwnCommand[id]=commands[id]~copy;end
  /* v0.92 flight books dead-reckon on each craft's own final command. */
  do id over ids
    if \ref~active(id) then iterate
    if commands~hasIndex(id) then ignored=books[id]~deadReckon(ref~tick,commands[id])
  end
  outsBefore=ref~outEvents~items
  claimsNow=ref~advanceAll(commands)
  /* v0.92 visual-fix data charges for this tick (VISUAL). */
  do id over visCharge~allIndexes~sort
    if visCharge[id]<=0 then iterate
    paid=ref~visualDebit(id,visCharge[id])
    vf=prefix||'_'||id||'_visual_power.csv'
    if stream(vf,'C','QUERY EXISTS')=='' then call lineout vf,'tick,grid_fixes,detail_requests,sky_fixes,cost,debited'
    sfx=0;if skyFixes~hasIndex(id) then sfx=skyFixes[id]
    call lineout vf,ref~tick','visFixes[id]','visDetails[id]','sfx','visCharge[id]','paid
    call stream vf,'C','CLOSE'
    visCharge[id]=0;visFixes[id]=0;visDetails[id]=0;skyFixes[id]=0
  end
  /* ORACLE-side scoring of the books (truth only goes to the log). */
  do id over ids
    if ref~craftStatus[id]\=='ACTIVE' & \ref~active(id) then iterate
    ignored=books[id]~logError(prefix||'_'||id||'_belief_ORACLE_ONLY.csv',ref~tick,ref~poseOf(id))
    ignored=books[id]~logSighting(prefix||'_'||id||'_sightings_ORACLE_ONLY.csv',ref~tick,world~targets,ref~claims)
  end
  /* v0.92: sensors that were ON this tick are paid for (SENSOR category). */
  if avoidOn then do
    users=.directory~new
    do id over sensorUse~allIndexes;users[id]=1;end
    do id over gpsUse~allIndexes;users[id]=1;end
    do id over users~allIndexes~sort
      sOn=0;aOn=0;gOn=0
      if sensorUse~hasIndex(id) then parse value sensorUse[id] with sOn aOn
      if gpsUse~hasIndex(id) then gOn=1
      cost=sOn*.Slam450Gpws~power['SCANNER']+aOn*.Slam450Gpws~power['ALTIMETER']+gOn*.Slam450Gps~power
      paid=ref~sensorDebit(id,cost)
      call gpwsOpen reflex,prefix,id,ref~airframeKind(id)
      call lineout prefix||'_'||id||'_sensor_power.csv',ref~tick','sOn','aOn','gOn','cost','paid
    end
    sensorUse=.directory~new;gpsUse=.directory~new
  end
  if movers\==.nil then do
    do row over movers~drain;call lineout prefix||'_targets_track_ORACLE_ONLY.csv',row;end
    wl=ref~windLevels
    do lv=1 to 3
      if wl~hasIndex(lv) then call lineout prefix||'_wind_levels_ORACLE_ONLY.csv',,
        ref~tick','lv','wl[lv]['EAST_MPS']','wl[lv]['NORTH_MPS']
    end
  end
  if claimsNow~items>0 then adviseNow=.true
  do k=outsBefore+1 to ref~outEvents~items
    o=ref~outEvents[k]
    say 'SQUAD OUT' o['STEP'] o['CRAFT'] '('||ref~teams[o['CRAFT']]||')' o['REASON']
    call lineout prefix||'_out_events.csv',o['STEP']||','||o['CRAFT']||','||ref~teams[o['CRAFT']]||','||o['REASON']
  end

  if windOn & ref~tick//8==0 then do
    do id over buddies
      if \ref~lastStates~hasIndex(id) | \ref~active(id) then iterate
      packet=ref~lastPackets[id]
      /* Relay only OWN confirmed image evidence of the competitor's type,
         never a type this craft merely heard from its buddy. */
      seen=typeMem[id]~belief('R');shareType='UNKNOWN'
      if seen['SOURCE']=='OWN_IMAGE' & seen['CONFIDENCE']=='CONFIRMED' then shareType=seen['TYPE']
      report=peer[id]~windReport(epoch,packet,'UNKNOWN',shareType,ref~airframeKind(id))
      sent=radio~send(report,ref~tick)
      if sent=='QUEUED_NEXT_TICK' then radioSent[id]+=1
      call lineout prefix||'_team_radio.csv',,
        ref~tick||','||id||','||peer[id]~peerID||',OBS,'||epoch||','||sent||',,, '
    end
  end
  do id over ids
    if \ref~lastStates~hasIndex(id) then iterate
    if \targets~hasIndex(id) then targets[id]=0
    if \lastAction~hasIndex(id) then lastAction[id]='LLM'
    p=ref~poseOf(id)
    call lineout prefix||'_'||id||'_truth_ORACLE_ONLY.csv',,
      ref~tick||','||p[1]||','||p[2]||','||p[3]||','||p[4]||','||targets[id]||','||lastAction[id]||','||ref~minSeparation||','||ref~lastStates[id]['AIRSPEED']
    if batteryOn then do
      meter=ref~batteryReport(id)
      note=energyMemory[id]~observe(ref~tick,meter,commands[id],lookupDone[id],radioSent[id])
      st=ref~lastStates[id];fcMode=''
      if fwc~hasIndex(id) then fcMode=fwc[id]~lastMode
      bankV='';gammaV=''
      if st~hasIndex('BANK') then bankV=st['BANK']
      if st~hasIndex('GAMMA') then gammaV=st['GAMMA']
      sideCmd=0
      if commands[id]~items>=4 then sideCmd=commands[id][4]
      call lineout prefix||'_'||id||'_battery.csv',,
        ref~tick||','||meter['REMAINING']||','||meter['PERCENT']||','||meter['FLIGHT_USED']||','||meter['LOOKUP_USED']||','||meter['RADIO_USED']||','||meter['CRUISE_STEPS_ESTIMATE']||','||commands[id][1]||','||commands[id][2]||','||commands[id][3]||','||sideCmd||','||lookupDone[id]||','||radioSent[id]||','||note['IDEA']||','||,
        ref~airframeKind(id)||','||st['AIRSPEED']||','||st['THROTTLE']||','||st['MODE']||','||st['PRICE']||','||st['POWERED']||','||fcMode||','||bankV||','||gammaV
    end
    if windOn then do
      packet=ref~lastPackets[id]
      idea=.directory~new;idea['IDEA']='LLM_PILOT'
      if pilots~hasIndex(id) then idea=pilots[id]~ingestWind(ref~tick,packet,pilots[id]~lastVisualEvidence)
      wind=ref~lastWind[id]
      call lineout prefix||'_'||id||'_sensors.csv',,
        ref~tick||','||packet['FLIGHT_LEVEL']||','||packet['PITOT_FORWARD_MPS']||','||packet['CUP_AIRSPEED_MPS']||','||packet['SAIL']||','||idea['IDEA']
      call lineout prefix||'_'||id||'_wind_ORACLE_ONLY.csv',,
        ref~tick||','||wind['LEVEL']||','||wind['BEARING_DEG']||','||wind['GUST_MPS']||','||wind['EAST_MPS']||','||wind['NORTH_MPS']
    end
  end
  do event over claimsNow
    target=event['TARGET'];winner=event['WINNER']
    wins[winner]+=1
    say 'SQUAD CLAIM' ref~tick 'TARGET' target 'WINNER' winner
    if roeOn then roe~contact(ref~tick,winner,target)
    call lineout prefix||'_claims.csv',,
      ref~tick||','||event['INTERCEPT_FRACTION']||','||target||','||winner||','||event['TIE']
    do id over ids
      if \tactics~hasIndex(id) then iterate
      if targets[id]==target & lastDecision[id]\=='' then do
        outcome='RIVAL_CLAIMED'
        if id==winner then outcome='SELF_CLAIMED'
        ignored=tactics[id]~outcome(lastDecision[id],outcome)
      end
    end
  end
  if ref~tick//10==0 then say 'SQUAD TICK' ref~tick 'CLAIMS' ref~claims~items 'ACTIVE' ref~activeIds~makestring('L',',') 'GAP' format(ref~minSeparation,,2)
  if ref~status\=='RUNNING' then leave
 end
 do id over llmIds
  ignored=llm[id]~saveLog(prefix||'_'||id||'_llm_calls.csv')
 end
 do id over ids
  ignored=typeMem[id]~save(prefix||'_'||id||'_aircraft_types.csv')
  if \pilots~hasIndex(id) then do
    if batteryOn then do
      ignored=energyMemory[id]~save(prefix||'_'||id||'_battery_memory.csv')
      call stream prefix||'_'||id||'_battery.csv','C','CLOSE'
    end
    call stream prefix||'_'||id||'_truth_ORACLE_ONLY.csv','C','CLOSE'
    iterate
  end
  ignored=pilots[id]~savePolicy(prefix||'_'||id||'_steering.txt')
  if batteryOn then do
    ignored=energyMemory[id]~save(prefix||'_'||id||'_battery_memory.csv')
    call stream prefix||'_'||id||'_battery.csv','C','CLOSE'
  end
  ignored=pilots[id]~windMemory~saveObservations(prefix||'_'||id||'_wind_memory.csv')
  ignored=observer[id]~saveObservations(prefix||'_'||id||'_rival_observations.csv')
  call stream prefix||'_'||id||'_truth_ORACLE_ONLY.csv','C','CLOSE'
  call stream prefix||'_'||id||'_tactics.csv','C','CLOSE'
  if windOn then do
    call stream prefix||'_'||id||'_sensors.csv','C','CLOSE'
    call stream prefix||'_'||id||'_wind_ORACLE_ONLY.csv','C','CLOSE'
  end
 end
 do id over buddies
  file=prefix||'_'||id||'_buddy_memory.csv'
  call lineout file,'slot,event,epoch,source,leader,target_a2,target_a3'
  count=0
  do m over peer[id]~memory
    count+=1;leader='';a2='';a3='';origin=''
    if m~hasIndex('LEADER') then leader=m['LEADER']
    if m~hasIndex('A2_TARGET') then a2=m['A2_TARGET']
    if m~hasIndex('A3_TARGET') then a3=m['A3_TARGET']
    if m~hasIndex('SOURCE') then origin=m['SOURCE']
    call lineout file,count||','||m['EVENT']||','||m['EPOCH']||','||origin||','||leader||','||a2||','||a3
  end
  call stream file,'C','CLOSE'
  if batteryOn then do
    file=prefix||'_'||id||'_received_energy.csv'
    call lineout file,'slot,from,sample_tick,remaining,percent,window_turns,burn_rate,theory,confidence,source'
    n=0
    do e over peer[id]~energyHistory
      n+=1
      call lineout file,n||','||e['FROM']||','||e['SAMPLE_TICK']||','||,
        e['REMAINING']||','||e['PERCENT']||','||e['WINDOW_TURNS']||','||,
        e['BURN_RATE']||','||e['THEORY']||','||e['CONFIDENCE']||',PEER_SELF_REPORT'
    end
    call stream file,'C','CLOSE'
  end
  say 'BUDDY' id 'MEMORY' peer[id]~memory~items 'LEADER' peer[id]~current['LEADER']
 end
 if batteryOn then do
   call stream prefix||'_team_energy.csv','C','CLOSE'
   call stream prefix||'_team_target_costs.csv','C','CLOSE'
 end
 do path over .array~of(prefix||'_team_radio.csv',prefix||'_claims.csv',,
                          prefix||'_fixed_camera.csv',prefix||'_course_ORACLE_ONLY.csv',,
                          prefix||'_targets_track_ORACLE_ONLY.csv',prefix||'_wind_levels_ORACLE_ONLY.csv')
  call stream path,'C','CLOSE'
 end
do id over fwc~allIndexes
  m='';do k over fwc[id]~counts~allIndexes~sort;m=m k'='fwc[id]~counts[k];end
  say 'FLIGHT_COMPUTER' id m
end
red=wins['A1']+wins['A4'];blue=wins['A2']+wins['A3']+wins['A5']
if squadMode=='3V3' then red=red+wins['A6']
if movers\==.nil then say 'TARGET_LEGS' movers~legs 'AIRSPEED' movers~airspeed
f1='';if squadMode=='3V3' then f1=' A6' wins['A6']
say 'SLAM450 SQUAD RESULT' ref~status 'TICKS' ref~tick 'CLAIMS' ref~claims~items 'RED' red '(A1' wins['A1'] 'H1' wins['A4']||f1') BLUE' blue '(A2' wins['A2'] 'A3' wins['A3'] 'H2' wins['A5']') FEEDS' feeds~grants 'MIN_GAP' format(ref~minSeparation,,3)
do id over llmIds
  L=llm[id]
  say 'LLM' labels[id] id ref~craftStatus[id] 'calls' L~calls 'faults' L~faults 'in' L~totalIn 'cache_read' L~totalCacheRead 'cache_write' L~totalCacheWrite 'out' L~totalOut 'cost_usd' format(L~totalCost,,4) 'mean_latency_ms' trunc(L~totalLatency/max(1,L~calls))
end
do id over ids;say 'STATUS' id ref~teams[id] ref~airframeKind(id) ref~craftStatus[id];end
if roeOn then say roe~summary
if orderOn then do tm over tlist~subWords
  say 'ORDERS' tm 'SENT_TOTAL' orderN 'CONTROL_TURNS' cmdrs[tm]~log~items 'CONTROL_COST_USD' format(cmdrs[tm]~totalCost,,4)
end
do id over ids;say 'BELIEF' id books[id]~summary;end
if batteryOn then do
  do id over ids
    m=ref~batteryReport(id)
    say 'BATTERY' id 'REMAINING' m['REMAINING'] 'PERCENT' m['PERCENT'] 'FLIGHT' m['FLIGHT_USED'] 'REMOTE' m['LOOKUP_USED'] 'RADIO' m['RADIO_USED']
  end
end
if ref~status=='COMPLETE' then exit 0
exit 5
/* v0.94 plans: the craft's current step is ord[craft], its plan is plan[craft] */
nextStep:
  parse arg c_
  do while plan[c_]~items>0
    q_=plan[c_][1]
    if q_['ACTION']=='AVOID' then do
      fbq(c_)~append(sit~craftNames[c_] 'notes: avoid' placeName(sit,q_['PLACE'])'.')
      plan[c_]~delete(1);iterate
    end
    /* v0.98: a conditional order is noted, never flown */
    if q_['ACTION']=='IF' then do
      fbq(c_)~append(sit~craftNames[c_] 'holds a conditional order it cannot evaluate: "'q_['TEXT']'"; not acted on. Give it without "if" to have it flown.')
      say 'ORDER CONDITIONAL' ref~tick c_ q_['TEXT']
      plan[c_]~delete(1);iterate
    end
    /* v0.97: a prohibition ("не знижуйтесь", do not descend) is noted, never flown */
    if q_['ACTION']=='DONT' then do
      nt=sit~craftNames[c_] 'notes: do not' q_['READING']~word(2)~lower~strip(,':')
      if q_['PLACE']\=='' & q_['PLACE']\=='UNABLE' then nt=nt '('placeName(sit,q_['PLACE'])')'
      if q_['TNUM']>0 then do
        if \banned~hasIndex(c_) then banned[c_]=.set~new
        banned[c_]~put(q_['TNUM']);nt=nt'; it will not go for it until an order names it again'
      end
      fbq(c_)~append(nt'.')
      say 'ORDER NOTED' ref~tick c_ q_['TEXT'] '-> DONT' q_['READING']~word(2)~strip(,':') q_['PLACE']
      plan[c_]~delete(1);iterate
    end
    if q_['PLACE']=='UNABLE' | q_['PLACE']=='' | q_['ACTION']=='NONE' then do
      fbq(c_)~append(sit~craftNames[c_] 'cannot act on "'q_['TEXT']'": no place or action it knows ('q_['READING']'); it goes on to its next step or its own task.')
      say 'ORDER UNABLE' ref~tick c_ q_['TEXT']
      plan[c_]~delete(1);iterate
    end
    /* a later order naming a forbidden target lifts the prohibition */
    if q_['TNUM']>0 then if banned~hasIndex(c_) then banned[c_]~remove(q_['TNUM'])
    q_['STATE']='ACTIVE';q_['STARTED']=ref~tick;ord[c_]=q_
    say 'ORDER DELIVERED' ref~tick c_ q_['TEXT'] '->' q_['ACTION'] q_['ROT'] q_['PLACE']
    return
  end
  if ord~hasIndex(c_) then ord~remove(c_)
  return
andList:
  /* "Alpha Delta Foxtrot" -> "Alpha, Delta and Foxtrot" */
  parse arg l_
  n_=words(l_);if n_<2 then return l_~strip
  return subword(l_,1,n_-1)~changeStr(' ',', ') 'and' word(l_,n_)
ownOf:
  /* v0.97: a team's craft ids, for its situation's hostile drones; '' with one Control */
  parse arg t_o
  if t_o=='ALL' then return ''
  return teamIds[t_o]
fbq:
  /* the feedback queue of the commander a craft answers to */
  parse arg c_f
  if \teamsMode then return feedbackT['ALL']
  return feedbackT[ref~teams[c_f]]
stepDone:
  parse arg c_
  if plan~hasIndex(c_) then if plan[c_]~items>0 then plan[c_]~delete(1)
  if ord~hasIndex(c_) then ord~remove(c_)
  if plan~hasIndex(c_) then call nextStep c_
  return

::routine placeName
  use arg sit,key
  if key~left(5)=='grid:' then do
    parse var key 'grid:' gx ':' gy
    return 'E' gx 'N' gy
  end
  if key=='here' then return 'where it is'
  d=sit~place(key)
  if d==.nil then return key
  return d['PHRASE']

::routine csvq
  use arg t
  return '"'||t~string~changeStr('"','""')||'"'

::routine crabTones
  /* v0.98: Boston Crab v0.18 tone lines, tone|n|kind|count: order number -> kind */
  use arg f
  out=.directory~new
  if stream(f,'C','QUERY EXISTS')=='' then return out
  do while lines(f)>0
    parse value linein(f) with k '|' n '|' kind '|' .
    if k=='tone' then out[n]=kind
  end
  call stream f,'C','CLOSE'
  return out

::routine crabFlags
  /* the first finding line of each order in Boston Crab's report ('' if clear) */
  use arg f
  out=.array~new;cur=.nil
  do while lines(f)>0
    ln=linein(f)
    if ln~strip=='' then do;if cur\==.nil then out~append(cur);cur=.nil;iterate;end
    if ln~left(2)\=='  ' then do;if pos(' -> ',ln)>0 then cur='';iterate;end
    if cur==.nil then iterate
    w=ln~strip
    if cur=='' & wordpos(w~word(1),'CLEAR REQUIRES NOTHING')=0 then cur=w
  end
  if cur\==.nil then out~append(cur)
  call stream f,'C','CLOSE'
  return out

::routine claimsText
  use strict arg ref
  out=''
  do t=1 to 5
    if ref~claims~hasIndex(t) then out=out 'target' t 'by' ref~teams[ref~claims[t]]';'
  end
  if out=='' then return 'none.'
  return out~strip
::routine blueFeed
  /* What the BLUE radio itself carries: the agreed SLAM assignments and
     the competitor type the SLAM buddies observed. Self-reported data. */
  use strict arg peer,typeMem
  out='SLAM teammates A2 (quad) and A3 (fixed-wing) use a buddy radio.'
  d=peer['A2']~current
  if d\==.nil then out=out 'Their latest agreed targets: A2->'d['A2_TARGET'] 'A3->'d['A3_TARGET'] '('d['STATUS']').'
  b=typeMem['A2']~belief('R')
  if b['CONFIDENCE']=='CONFIRMED' then out=out 'A2 sees a rival as a' b['TYPE']'.'
  return out
::routine gpwsOpen
  use arg reflex,prefix,id,kind
  if \reflex~hasIndex(id) then do
    reflex[id]=.Slam450Gpws~new(kind)
    call lineout prefix||'_'||id||'_gpws.csv','tick,action,nearest_m,radio_alt_m,callouts'
    call lineout prefix||'_'||id||'_sensor_power.csv','tick,scanner_on,altimeter_on,gps_on,cost,debited'
  end
  return
::routine gpwsSlam
  /* v0.92 AVOID: the SLAM pilot runs both sensors and heeds/ignores. */
  use arg reflex,sensorUse,prefix,id,kind,tick,frame,cmd,target,world,pose
  call gpwsOpen reflex,prefix,id,kind
  scan=world~scan(pose);agl=radioAlt(world,pose);sensorUse[id]='1 1'
  n=reflex[id]~events~items
  out=reflex[id]~slamAdjust(tick,frame,cmd,target,scan,agl)
  do k=n+1 to reflex[id]~events~items
    parse value reflex[id]~events[k] with t a nr ag cl
    call lineout prefix||'_'||id||'_gpws.csv',t','a','nr','ag','translate(cl,' ','_')
  end
  return out
::routine gpwsLlm
  /* v0.92: an LLM pilot's own sensors, ON only when it asked; silent when off. */
  use arg reflex,sensorUse,prefix,id,kind,tick,world,pose,climbCmd,speed,sOn,aOn
  call gpwsOpen reflex,prefix,id,kind
  scan=.nil;agl='OFF'
  if sOn then scan=world~scan(pose)
  if aOn then agl=radioAlt(world,pose)
  if sOn | aOn then sensorUse[id]=(sOn==.true)+0 (aOn==.true)+0
  txt=reflex[id]~llmText(scan,agl,climbCmd,speed,sOn,aOn)
  if txt\=='' then call lineout prefix||'_'||id||'_gpws.csv',tick',LLM_TOLD,,,'reflex[id]~lastCallouts
  return txt
::routine radioAlt
  use arg world,pose
  s=world~surfaceBelow(pose)
  if \datatype(s,'N') then return 'NO_RETURN'
  return pose[3]-s
::requires 'Slam450VisualSeparation.cls'
::requires 'Slam450Buddy.cls'
::requires 'Slam450Trio.cls'
::requires 'Slam450Squad.cls'
::requires 'Slam450TargetMovers.cls'
::requires 'Slam450PlanMap.cls'
::requires 'Slam450Gpws.cls'
::requires 'Slam450Gps.cls'
::requires 'Slam450LlmPilot.cls'
::requires 'Slam450Belief.cls'
::requires 'Slam450VisualFix.cls'
::requires 'Slam450Sky.cls'
::requires 'Slam450RaceTactics.cls'
::requires 'Slam450RivalAir.cls'
::requires 'Slam450Learning.cls'
::routine wingEnvelope
  /* v0.92 fly-by-wire envelope for an LLM-flown wing (Tom Dyer's "replace
   * Haiku's quad with a wing"). Protection only, no autopilot: the LLM still
   * chooses where to go; the airframe refuses stall, hover, reverse and
   * side-slip, clamps bank (yaw) and path (climb) to what A3's flight
   * computer flies. Every override is logged and told to the pilot next tick.
   * Written by Claude (Opus 5.5). */
  use strict arg prefix,id,tick,cmd,notes
  numeric digits 16
  f=prefix||'_'||id||'_envelope.csv'
  if stream(f,'C','QUERY EXISTS')=='' then call lineout f,'tick,asked_yaw,asked_forward,asked_climb,asked_side,flown_yaw,flown_forward,flown_climb,flown_side,overrides'
  out=cmd~copy;why=''
  if out[2]<7.4 then do;out[2]=7.4;why=why 'STALL_PROTECT';end
  if out[2]>11 then do;out[2]=11;why=why 'VMAX';end
  if abs(out[1])>30 then do;out[1]=max(-30,min(30,out[1]));why=why 'BANK_LIMIT';end
  if out[3]>2 | out[3]<-3 then do;out[3]=max(-3,min(2,out[3]));why=why 'PATH_LIMIT';end
  if out[4]\=0 then do;out[4]=0;why=why 'NO_SIDESLIP';end
  why=why~strip
  call lineout f,tick','cmd[1]','cmd[2]','cmd[3]','cmd[4]','out[1]','out[2]','out[3]','out[4]','why
  call stream f,'C','CLOSE'
  if why\=='' then notes[id]='FLIGHT COMPUTER: last tick it overrode you ('why'): flew yaw' out[1] 'forward' out[2] 'climb' out[3]'. A wing cannot hover or slide.'
  return out
::requires 'Slam450FixedWingPilot.cls'
::requires 'Slam450AircraftType.cls'
::requires 'Slam450Situation.cls'
::requires 'Slam450Commander.cls'
::requires 'Slam450Roe.cls'
