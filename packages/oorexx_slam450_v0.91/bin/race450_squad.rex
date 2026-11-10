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
parse arg prefix seed course maxSteps windMode batteryMode lookupMode llmMode eyesMode projection thinkMode seatMode targetMode mapMode groundMode
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
if mapMode=='MAP' & wordpos(course~upper,'LEGACY QUAYSIDE')==0 then raise syntax 88.900 array('the plan map crop is defined for LEGACY and QUAYSIDE only')
.local['SLAM450.MAP']=mapMode
/* v0.91 ground: NOGROUND (default; boxes + sea only, as v0.90) or GROUND
   (Power SLAM v0.40 heights + water words, Slam450Ground). */
if groundMode=='' then groundMode='NOGROUND'
groundMode=groundMode~upper
if groundMode\=='GROUND' & groundMode\=='NOGROUND' then raise syntax 88.900 array('ground mode GROUND or NOGROUND')
.local['SLAM450.GROUND']=groundMode
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
layout=.array~new
do spec over .array~of('A1 RED QUAD','A2 BLUE QUAD','A3 BLUE FIXED_WING','A4 RED QUAD','A5 BLUE QUAD')
  parse var spec i t a
  d=.directory~new;d['ID']=i;d['TEAM']=t;d['AIRFRAME']=a;layout~append(d)
end
ref=.Slam450SquadReferee~new(world,layout,windOn,batteryOn)
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
llm=.directory~new;llmFixed=.directory~new;llmWantsLookup=.directory~new
client=.nil;rates=.AnthropicModelCatalog~new
if llmMode=='LIVE' then client=.AnthropicMessageClient~new(.AnthropicRuntimeConfig~fromEnvironment)
redNote='RED = you (H1, LLM quad) + A1 (SLAM quad, autonomous, no radio). Rivals BLUE = A2 quad + A3 fixed-wing + H2 quad.'
blueNote='BLUE = you (H2, LLM quad) + A2 (SLAM quad) + A3 (SLAM fixed-wing); A2/A3 run their own buddy radio and you can read its summary. Rivals RED = A1 quad + H1 quad.'
if mapMode=='MAP' then do
  /* Rendered once, before any pilot is built; identical for every seed. */
  planMap=.Slam450PlanMap~new(world)
  mapProvider=.nil;if .ForeignPngProvider~available then mapProvider=.ForeignPngProvider~new
  .local['SLAM450.MAP_PNG']=planMap~pngBase64(mapProvider)
  .local['SLAM450.MAP_W']=planMap~width;.local['SLAM450.MAP_H']=planMap~height
end
llm['A4']=.Slam450LlmPilot~new('A4','H1','RED',redNote,pilotMode,eyesMode,'claude-haiku-5-5',client,rates,'AUTO',thinkMode)
llm['A5']=.Slam450LlmPilot~new('A5','H2','BLUE',blueNote,pilotMode,eyesMode,'claude-haiku-5-5',client,rates,'AUTO',thinkMode)
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
say 'SLAM450 SQUAD START' seed course windMode batteryMode lookupMode 'LLM' llmMode eyesMode 'THINK' thinkMode 'SEAT' seatMode 'TARGETS' targetKind 'MAP' mapMode 'GROUND' groundMode 'PROJECTION' cam~projectionLane 'GAP' ref~minSeparation
 do loop=1 to maxSteps
  if ref~status\=='RUNNING' then leave
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
      msg=.message~new(llm[id],'ADVISE','A',.array~of(ref~tick,frames[id],ref~batteryReport(id),available,claimsText(ref),feed,ps))
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
    commands[id]=separation~adjust(id,frames[id],commands[id])
    if batteryOn then commands[id]=energyPolicy~adjust(commands[id],ref~batteryReport(id))
    if advice~hasIndex(id) then if advice[id]['SPEED']=='FAST' & \hold then ,
      if commands[id][2]>=3.5 then commands[id][2]=7
    if fwc~hasIndex(id) then do
      /* The wing's own flight computer turns intent into what a wing can fly. */
      meter=.nil
      if batteryOn then meter=ref~batteryReport(id)
      commands[id]=fwc[id]~command(frames[id],selected,commands[id],hold,meter)
      ignored=pilots[id]~executed(commands[id])
    end
  end
  /* v0.84 changes the old throttle: costly remote lookup may happen on
   * any turn. Battery price, not a shared five-step gate, restrains use. */
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
    msg=.message~new(llm[id],'DECIDE','A',.array~of(ref~tick,frames[id],ref~batteryReport(id),pk,available,claimsText(ref),feed,fixed))
    msg~start
    pending[id]=msg
  end
  do id over pending~allIndexes
    out=pending[id]~result
    commands[id]=out[1];targets[id]=out[2];llmWantsLookup[id]=out[3]
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
      response=feeds~request(id,view,ref~tick,ref~claims,poses[id],others)
      call lineout prefix||'_fixed_camera.csv',ref~tick||','||id||','||view||','||response['STATUS']||','||response['REASON']
      if response['STATUS']=='GRANTED' then do
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
  outsBefore=ref~outEvents~items
  claimsNow=ref~advanceAll(commands)
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
::requires 'Slam450VisualSeparation.cls'
::requires 'Slam450Buddy.cls'
::requires 'Slam450Trio.cls'
::requires 'Slam450Squad.cls'
::requires 'Slam450TargetMovers.cls'
::requires 'Slam450PlanMap.cls'
::requires 'Slam450LlmPilot.cls'
::requires 'Slam450RaceTactics.cls'
::requires 'Slam450RivalAir.cls'
::requires 'Slam450Learning.cls'
::requires 'Slam450FixedWingPilot.cls'
::requires 'Slam450AircraftType.cls'
