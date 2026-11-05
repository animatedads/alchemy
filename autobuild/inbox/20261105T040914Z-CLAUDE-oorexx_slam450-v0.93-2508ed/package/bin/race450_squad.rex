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
parse arg prefix seed course maxSteps windMode batteryMode lookupMode llmMode eyesMode projection thinkMode seatMode targetMode mapMode groundMode modelMode avoidMode llmCraft visRange searchMode visFixMode utcStart
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
do spec over .array~of('A1 RED QUAD','A2 BLUE QUAD','A3 BLUE FIXED_WING','A4 RED' llmAirframe,'A5 BLUE' llmAirframe)
  parse var spec i t a
  d=.directory~new;d['ID']=i;d['TEAM']=t;d['AIRFRAME']=a;layout~append(d)
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
do id over .array~of('A1','A2','A3','A4','A5')
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
advice=.directory~new;adviseNow=.true
labels=.directory~new;labels['A4']='H1';labels['A5']='H2'
llm=.directory~new;llmFixed=.directory~new;llmWantsLookup=.directory~new;envelopeNote=.directory~new
client=.nil;rates=.AnthropicModelCatalog~new
if llmMode=='LIVE' then client=.AnthropicMessageClient~new(.AnthropicRuntimeConfig~fromEnvironment)
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
ids=.array~of('A1','A2','A3','A4','A5')
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
    lastTgt[id]=selected;targets[id]=selected
    if hold then commands[id]=.array~of(0,0,0,0)
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
    commands[id]=separation~adjust(id,frames[id],commands[id])
    if batteryOn then commands[id]=energyPolicy~adjust(commands[id],ref~batteryReport(id))
    if advice~hasIndex(id) then if advice[id]['SPEED']=='FAST' & \hold then ,
      if commands[id][2]>=3.5 then commands[id][2]=7
    if fwc~hasIndex(id) then do
      /* The wing's own flight computer turns intent into what a wing can fly. */
      meter=.nil
      if batteryOn then meter=ref~batteryReport(id)
      commands[id]=fwc[id]~command(frames[id],selected,commands[id],hold,meter)
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
if movers\==.nil then say 'TARGET_LEGS' movers~legs 'AIRSPEED' movers~airspeed
say 'SLAM450 SQUAD RESULT' ref~status 'TICKS' ref~tick 'CLAIMS' ref~claims~items 'RED' red '(A1' wins['A1'] 'H1' wins['A4']') BLUE' blue '(A2' wins['A2'] 'A3' wins['A3'] 'H2' wins['A5']') FEEDS' feeds~grants 'MIN_GAP' format(ref~minSeparation,,3)
do id over llmIds
  L=llm[id]
  say 'LLM' labels[id] id ref~craftStatus[id] 'calls' L~calls 'faults' L~faults 'in' L~totalIn 'cache_read' L~totalCacheRead 'cache_write' L~totalCacheWrite 'out' L~totalOut 'cost_usd' format(L~totalCost,,4) 'mean_latency_ms' trunc(L~totalLatency/max(1,L~calls))
end
do id over ids;say 'STATUS' id ref~teams[id] ref~airframeKind(id) ref~craftStatus[id];end
do id over ids;say 'BELIEF' id books[id]~summary;end
if batteryOn then do
  do id over ids
    m=ref~batteryReport(id)
    say 'BATTERY' id 'REMAINING' m['REMAINING'] 'PERCENT' m['PERCENT'] 'FLIGHT' m['FLIGHT_USED'] 'REMOTE' m['LOOKUP_USED'] 'RADIO' m['RADIO_USED']
  end
end
if ref~status=='COMPLETE' then exit 0
exit 5
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
