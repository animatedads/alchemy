/* Native simultaneous three-craft flight. A1 SOLO; A2<->A3 peer team.
 * Simulator state is strictly private to referee and renderer. No pilot,
 * tactics, peer or radio sees world coordinates or actual wind vectors.
 */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg prefix seed course maxSteps windMode batteryMode lookupMode a3Airframe projection
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
if a3Airframe=='' then a3Airframe='QUAD'
a3Airframe=a3Airframe~upper
if a3Airframe\=='QUAD' & a3Airframe\=='FIXED_WING' then raise syntax 88.900 array('A3 airframe must be QUAD or FIXED_WING')
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
world=.Slam450World~new(seed,course,.false)
kinds=.directory~new;kinds['A1']='QUAD';kinds['A2']='QUAD';kinds['A3']=a3Airframe
ref=.Slam450TrioReferee~new(world,windOn,batteryOn,kinds)
fwc=.directory~new
typeMem=.directory~new;beliefs=.directory~new
cam=.Slam450Camera~new(world)
feeds=.Slam450TrioCameraService~new(world,batteryOn,ref)
energyPolicy=.Slam450BatteryPolicy~new
energyMemory=.directory~new
radio=.Slam450BuddyRadio~new(ref)
ids=.array~of('A1','A2','A3')
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
  pilots[id]=.Slam450LearningPilot~new(.Slam450VisualMemory~new(48))
  tactics[id]=.Slam450RaceTactics~new(id,48)
  typeMem[id]=.Slam450AircraftTypeMemory~new(8)
  observer[id]=.Slam450RivalAir~new(id,48)
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
say 'SLAM450 TRIO START' seed course windMode batteryMode lookupMode 'A3' a3Airframe 'PROJECTION' cam~projectionLane 'GAP' ref~minSeparation
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
  /* Each craft gets its own panorama: R=opponent, P=buddy, never xyz. */
  do id over ids
    others=.directory~new
    if id=='A1' then do
      others['R']=poses['A2'];others['P']=poses['A3']
    end
    else do
      others['R']=poses['A1']
      friend='A2'
      if id=='A2' then friend='A3'
      others['P']=poses[friend]
    end
    /* Truth side only: each silhouette is drawn with its airframe shape. */
    kindsSeen=.directory~new
    do sym over others~allIndexes
      do who over ids
        if poses[who]==others[sym] then kindsSeen[sym]=ref~airframeKind(who)
      end
    end
    frames[id]=cam~renderAt(poses[id],480,121,.false,ref~claims,others,.nil,kindsSeen)
  end
  /* Pilot side: aircraft type is inferred from those pixels only. */
  do id over ids;beliefs[id]=typeMem[id]~observe(frames[id],ref~tick);end
  current=ref~nextAvailable(0)
  after=ref~nextAvailable(current)
  if after==0 then after=current
  epoch=trunc(ref~tick/16)
  /* Bid and send only own image evidence; private notes never shared. */
  do id over buddies
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
  do id over ids
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
  if batteryOn then do
    do id over ids
      if targets[id]>0 & energyPolicy~wantRemote(ref~batteryReport(id),ref~tick,frames[id],targets[id],lookupMode) then do
        do
          others=.array~new
          do other over ids
            if other\==id then others~append(poses[other])
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
  do id over ids;lastOwnCommand[id]=commands[id]~copy;end
  claimsNow=ref~advance(commands['A1'],commands['A2'],commands['A3'])
  if ref~status=='POWER_STOP' then do
    say 'TRIO BATTERY STOP' ref~lastHit 'STEP' ref~tick+1
    leave
  end
  if ref~status=='COLLISION' then do
    say 'TRIO SAFETY STOP' ref~lastHit 'STEP' ref~tick+1
    leave
  end
  if windOn & ref~tick//8==0 then do
    do id over buddies
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
      idea=pilots[id]~ingestWind(ref~tick,packet,pilots[id]~lastVisualEvidence)
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
    say 'TRIO CLAIM' ref~tick 'TARGET' target 'WINNER' winner
    call lineout prefix||'_claims.csv',,
      ref~tick||','||event['INTERCEPT_FRACTION']||','||target||','||winner||','||event['TIE']
    do id over ids
      if targets[id]==target & lastDecision[id]\=='' then do
        outcome='RIVAL_CLAIMED'
        if id==winner then outcome='SELF_CLAIMED'
        ignored=tactics[id]~outcome(lastDecision[id],outcome)
      end
    end
  end
  if ref~tick//25==0 then say 'TRIO TICK' ref~tick 'CLAIMS' ref~claims~items 'GAP' ref~minSeparation
 end
 do id over ids
  ignored=pilots[id]~savePolicy(prefix||'_'||id||'_steering.txt')
  ignored=typeMem[id]~save(prefix||'_'||id||'_aircraft_types.csv')
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
                          prefix||'_fixed_camera.csv',prefix||'_course_ORACLE_ONLY.csv')
  call stream path,'C','CLOSE'
 end
do id over fwc~allIndexes
  m='';do k over fwc[id]~counts~allIndexes~sort;m=m k'='fwc[id]~counts[k];end
  say 'FLIGHT_COMPUTER' id m
end
say 'SLAM450 TRIO RESULT' ref~status 'TICKS' ref~tick 'CLAIMS' ref~claims~items 'SOLO' wins['A1'] 'BUDDY2' wins['A2'] 'BUDDY3' wins['A3'] 'FEEDS' feeds~grants 'MIN_GAP' ref~minSeparation
if batteryOn then do
  do id over ids
    m=ref~batteryReport(id)
    say 'BATTERY' id 'REMAINING' m['REMAINING'] 'PERCENT' m['PERCENT'] 'FLIGHT' m['FLIGHT_USED'] 'REMOTE' m['LOOKUP_USED'] 'RADIO' m['RADIO_USED']
  end
end
if ref~status=='COMPLETE' then exit 0
if ref~status=='COLLISION' then exit 4
if ref~status=='POWER_STOP' then exit 6
exit 5
::requires 'Slam450VisualSeparation.cls'
::requires 'Slam450Buddy.cls'
::requires 'Slam450Trio.cls'
::requires 'Slam450RaceTactics.cls'
::requires 'Slam450RivalAir.cls'
::requires 'Slam450Learning.cls'
::requires 'Slam450FixedWingPilot.cls'
::requires 'Slam450AircraftType.cls'
