/* Native ooRexx simultaneous two-aircraft SLAM450 race.
 * Truth stays in referee and separate oracle CSVs. No aircraft knows XYZ.
 * Each aircraft owns distinct image, yaw-response, tactical and wind memory.
 */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg prefix seed course maxSteps windMode
if prefix=='' then prefix='slam450_race'
if seed=='' then seed=45045
if course=='' then course='LEGACY'
if maxSteps=='' then maxSteps=500
if windMode=='' then windMode='WIND'
windOn=(windMode~upper=='WIND')
world=.Slam450World~new(seed,course,.false)
ref=.Slam450RaceReferee~new(world,windOn)
cam=.Slam450Camera~new(world)
net=.Slam450RaceCameraService~new(world)
vision=.Slam450Vision~new
memory=.directory~new;tactics=.directory~new;pilots=.directory~new
rivalAir=.directory~new;lastOwnCommand=.directory~new;trialUntil=.directory~new
imageGuesser=.directory~new;priorImagePose=.directory~new
trialDirection=.directory~new;lastTrial=.directory~new
lastTgt=.directory~new;lastAction=.directory~new;lastDecision=.directory~new
wins=.directory~new
ids=.array~of('A1','A2')
do id over ids
  memory[id]=.Slam450VisualMemory~new(48)
  pilots[id]=.Slam450LearningPilot~new(memory[id])
  tactics[id]=.Slam450RaceTactics~new(id,48)
  rivalAir[id]=.Slam450RivalAir~new(id,48)
  imageGuesser[id]=.Slam450PoseGuesser~new(world~scene)
  priorImagePose[id]=.nil
  lastOwnCommand[id]=.nil;trialUntil[id]=0;trialDirection[id]=0;lastTrial[id]=-99
  lastTgt[id]=0;lastAction[id]='NONE';lastDecision[id]=''
  wins[id]=0
  call lineout prefix||'_'||id||'_truth_ORACLE_ONLY.csv',,
    'tick,x_east_m,y_north_m,z_m,heading_deg,own_objective,action,minimum_separation_m'
  call lineout prefix||'_'||id||'_tactics.csv',,
    'tick,prior_target,chosen_target,action,rival_cue,reason,visual_provenance'
  call lineout prefix||'_'||id||'_altitude_trials.csv',,
    'tick,action,change_m_per_step,reason,observed_own_level,rival_height_order,wind_hypothesis'
  if windOn then do
    call lineout prefix||'_'||id||'_sensors.csv',,
      'tick,level,pitot_mps,pitot_status,cup_mps,sail,wind_idea'
    call lineout prefix||'_'||id||'_wind_ORACLE_ONLY.csv',,
      'tick,level,bearing_deg,speed_mps,east_mps,north_mps'
  end
end
call lineout prefix||'_claims.csv','tick,contact_fraction,target,winner,tie'
call lineout prefix||'_fixed_camera.csv','tick,aircraft,camera,status,reason'
call lineout prefix||'_course_ORACLE_ONLY.csv','target,region,east_m,north_m,z_m'
do i=1 to 5
  p=world~targets[i]
  call lineout prefix||'_course_ORACLE_ONLY.csv',i||','||world~courseAreas[i]||','||p[1]||','||p[2]||','||p[3]
end
say 'SLAM450 RACE START' seed course windMode 'START_GAP' ref~minSeparation
/* Both consult their own onboard panorama only. An arbitrary policy decides
 * when to commit to another red square; the camera never transmits world XYZ. */
do loop=1 to maxSteps
  if ref~status\=='RUNNING' then leave
  images=.directory~new;commands=.directory~new;nextTarget=.directory~new
  poses=.directory~new
  poses['A1']=ref~poseOf('A1');poses['A2']=ref~poseOf('A2')
  images['A1']=cam~renderAt(poses['A1'],480,121,.false,ref~claims,poses['A2'])
  images['A2']=cam~renderAt(poses['A2'],480,121,.false,ref~claims,poses['A1'])
  current=ref~nextAvailable(0)
  after=ref~nextAvailable(current)
  if after==0 then after=current
  do id over ids
    ownPacket=.nil
    if ref~tick>0 & windOn then ownPacket=ref~lastPackets[id]
    /* Rival motion is read from ONE onboard IMAGE plus own last command
       and (when available) one's own restricted airflow packet. No oracle. */
    ownImageAltitude=.nil
    if ref~tick//10==0 then do
      /* Guesser has only STATIC LANDMARK REFERENCE GEOMETRY, never poseOf.
         Run inverse on the actual 360 pixel image, then pass only its
         altitude estimate and stated uncertainty to rival hypothesis. */
      pg=imageGuesser[id]~guess(images[id],priorImagePose[id])
      if pg['STATUS']=='IMAGE_BEARING_ESTIMATE' then do
        if pg['BEARING_RMS_DEG']<2 then do
          priorImagePose[id]=pg
          ownImageAltitude=.directory~new
          ownImageAltitude['ESTIMATE_SOURCE']='ONBOARD_LANDMARK_INVERSE'
          ownImageAltitude['STATUS']=pg['STATUS']
          ownImageAltitude['Z']=pg['Z']
          ownImageAltitude['Z_UNCERTAINTY_M']=max(12,6*pg['BEARING_RMS_DEG'])
        end
      end
    end
    rivalNote=rivalAir[id]~observe(images[id],ref~tick,ownPacket,lastOwnCommand[id],0,ownImageAltitude)
    /* Retest tactic on a periodic event, or immediately after a capture.
     Commitment prevents unrealistic objective switching on every pixel. */
    chosen=lastTgt[id]
    if chosen==0 | \ref~available(chosen) | ref~tick//5==0 then do
      d=tactics[id]~choose(images[id],current,after,ref~tick)
      chosen=d['TARGET']
      if \ref~available(chosen) then chosen=current
      if lastTgt[id]\==chosen | lastAction[id]\==d['ACTION'] then do
        call lineout prefix||'_'||id||'_tactics.csv',,
          ref~tick||','||current||','||chosen||','||d['ACTION']||','||d['RIVAL_CUE']||','||d['REASON']||',ONBOARD_IMAGE_ONLY'
        say 'TACTIC' ref~tick id d['ACTION'] 'target' chosen 'cue' d['RIVAL_CUE']
      end
      lastAction[id]=d['ACTION'];lastDecision[id]=d['DECISION_ID']
    end
    lastTgt[id]=chosen
    commands[id]=pilots[id]~control(images[id],chosen)
    nextTarget[id]=chosen
    /* At most one short altitude EXPERIMENT per 30 ticks. An observed
       headwind/sideways-drift candidate is not an exact wind field. The
       pilot may trial another flight level using its own climb control. */
    if trialUntil[id]>ref~tick then do
      commands[id][3]=max(-4,min(4,commands[id][3]+1.5*trialDirection[id]))
    end
    else if ownPacket\==.nil & ref~tick-lastTrial[id]>=30 then do
      advice=rivalAir[id]~recommendAltitude(ownPacket['FLIGHT_LEVEL'],commands[id])
      if advice['ACTION']=='ALTITUDE_EXPERIMENT' then do
        /* Don't ignore target approach by trialling a new level when
           an already-near square has a firm visible vertical correction. */
        visible=vision~observe(images[id],chosen)
        trialOK=.true
        if visible\==.nil then do
          if visible['WIDTH']>=12 then trialOK=.false
        end
        if trialOK then do
          trialDirection[id]=advice['CLIMB_M_PER_STEP']/1.5
          trialUntil[id]=ref~tick+10
          lastTrial[id]=ref~tick
          commands[id][3]=max(-4,min(4,commands[id][3]+advice['CLIMB_M_PER_STEP']))
          call lineout prefix||'_'||id||'_altitude_trials.csv',,
            ref~tick||','||advice['ACTION']||','||advice['CLIMB_M_PER_STEP']||','||advice['REASON']||','||ownPacket['FLIGHT_LEVEL']||','||rivalNote['HEIGHT_ORDER']||','||rivalNote['WIND_IDEA']
          say 'ALTITUDE_TRIAL' ref~tick id advice['REASON'] 'direction' trialDirection[id]
        end
      end
    end
    /* Direct visual collision caution; no relative XYZ or range oracle.
     Distinct reactive sidesteps for close, front-facing rival pixels. */
    rival=vision~observe(images[id],'R')
    if rival\==.nil then do
      if abs(rival['AZ'])<9 & rival['COUNT']>=25 then do
        c=commands[id]
        if c~items<4 then c~append(0)
        if id=='A1' then c[4]=-1.0
        else c[4]=1.0
        c[2]=min(c[2],3)
      end
    end
  end
  /* One fixed camera total every five completed steps across BOTH craft.
     Deterministic alternating priority; no camera repositioning. */
  if ref~tick>0 & ref~tick//5==0 then do
    turn=trunc(ref~tick/5)
    id=ids[1+(turn//2)]
    other='A1'
    if id=='A1' then other='A2'
    viewID=net~views[1+((turn-1)//net~views~items)]
    response=net~request(id,viewID,ref~tick,ref~claims,poses[id],poses[other])
    call lineout prefix||'_fixed_camera.csv',,
      ref~tick||','||id||','||viewID||','||response['STATUS']||','||response['REASON']
    if response['STATUS']=='GRANTED' then do
      ignored=pilots[id]~consultFixedCamera(viewID,response['FRAME'],nextTarget[id])
      fixedMotion=rivalAir[id]~observeFixed(viewID,response['FRAME'],ref~tick)
    end
  end
  /* Retain the ACTUAL commands the pilot issued, not a rival's controls. */
  do id over ids;lastOwnCommand[id]=commands[id]~copy;end
  captures=ref~advance(commands['A1'],commands['A2'])
  if ref~status=='COLLISION' then do
    say 'RACE SAFETY STOP' ref~lastHit 'step' ref~tick+1
    leave
  end
  do id over ids
    p=ref~poseOf(id)
    call lineout prefix||'_'||id||'_truth_ORACLE_ONLY.csv',,
      ref~tick||','||p[1]||','||p[2]||','||p[3]||','||p[4]||','||nextTarget[id]||','||lastAction[id]||','||ref~minSeparation
    if windOn then do
      packet=ref~lastPackets[id]
      idea=pilots[id]~ingestWind(ref~tick,packet,pilots[id]~lastVisualEvidence)
      wind=ref~lastWind[id]
      call lineout prefix||'_'||id||'_sensors.csv',,
        ref~tick||','||packet['FLIGHT_LEVEL']||','||packet['PITOT_FORWARD_MPS']||','||packet['PITOT_STATUS']||','||packet['CUP_AIRSPEED_MPS']||','||packet['SAIL']||','||idea['IDEA']
      call lineout prefix||'_'||id||'_wind_ORACLE_ONLY.csv',,
        ref~tick||','||wind['LEVEL']||','||wind['BEARING_DEG']||','||wind['GUST_MPS']||','||wind['EAST_MPS']||','||wind['NORTH_MPS']
    end
  end
  do claim over captures
    number=claim['TARGET'];winner=claim['WINNER']
    wins[winner]+=1
    say 'CLAIM' 'step' ref~tick 'target' number 'winner' winner 'fraction' claim['INTERCEPT_FRACTION']
    call lineout prefix||'_claims.csv',,
      ref~tick||','||claim['INTERCEPT_FRACTION']||','||number||','||winner||','||claim['TIE']
    do id over ids
      if nextTarget[id]==number & lastDecision[id]\=='' then do
        event='RIVAL_CLAIMED'
        if id==winner then event='SELF_CLAIMED'
        result=tactics[id]~outcome(lastDecision[id],event)
      end
    end
  end
  if ref~tick//50==0 then say 'RACE TICK' ref~tick 'CLAIMS' ref~claims~items 'GAP' ref~minSeparation
end
/* Never write one aircraft's learning state into the other's storage. */
do id over ids
  ignored=pilots[id]~savePolicy(prefix||'_'||id||'_steering.txt')
  ignored=pilots[id]~windMemory~saveObservations(prefix||'_'||id||'_wind_memory.csv')
  ignored=rivalAir[id]~saveObservations(prefix||'_'||id||'_rival_air_memory.csv')
  call stream prefix||'_'||id||'_altitude_trials.csv','C','CLOSE'
  say 'PILOT' id 'CLAIMS' wins[id] 'TACTIC_SLOTS' tactics[id]~notes~items 'WIND_SLOTS' pilots[id]~windMemory~slots~items 'RIVAL_AIR_SLOTS' rivalAir[id]~slots~items 'ALTITUDE_TRIALS' rivalAir[id]~trials
  call stream prefix||'_'||id||'_truth_ORACLE_ONLY.csv','C','CLOSE'
  call stream prefix||'_'||id||'_tactics.csv','C','CLOSE'
  if windOn then do
    call stream prefix||'_'||id||'_sensors.csv','C','CLOSE'
    call stream prefix||'_'||id||'_wind_ORACLE_ONLY.csv','C','CLOSE'
  end
end
do path over .array~of(prefix||'_claims.csv',prefix||'_fixed_camera.csv',prefix||'_course_ORACLE_ONLY.csv')
  call stream path,'C','CLOSE'
end
say 'SLAM450 RACE RESULT' ref~status 'TICKS' ref~tick 'CLAIMS' ref~claims~items 'A1' wins['A1'] 'A2' wins['A2'] 'FIXED_FEEDS' net~grants 'MIN_GAP' ref~minSeparation
if ref~status=='COMPLETE' then exit 0
if ref~status=='COLLISION' then exit 4
exit 5
::requires 'Slam450Race.cls'
::requires 'Slam450RaceTactics.cls'
::requires 'Slam450RivalAir.cls'
::requires 'Slam450Learning.cls'
