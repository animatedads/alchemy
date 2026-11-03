::requires 'SlamHarbourPose.cls'
/* SLAM 450 v0.5 — wind physics, restricted airflow instruments, idea slots.
 * Architecture: Tom Dyer. Native ooRexx implementation: ChatGPT GPT-6.
 * ORACLE: Slam450WindField and its east/north vector never go to the pilot.
 * PILOT: only sample()'s restricted pitot/cup/sail/flight-level packet.
 * This is a synthetic discrete-time approximation, NOT calibrated aerodynamics.
 */
::class Slam450WindField public
::attribute bands get
::attribute lastTruth get
::method init
  expose seed bands lastTruth
  use strict arg randomSeed=45042
  seed=randomSeed+101
  bands=.array~new
  do i=1 to 3
    direction=trunc(360*self~random)
    minimum=0.4+0.65*self~random
    maximum=minimum+1.6+1.6*self~random
    initial=(minimum+maximum)/2
    bands~append(.array~of(direction,minimum,maximum,initial))
  end
  lastTruth=.nil
::method random
  expose seed
  seed=(seed*16807)//2147483647
  return seed/2147483647
::method levelAt
  use strict arg altitude
  if altitude<55 then return 1
  if altitude<105 then return 2
  return 3
::method advance
  expose bands lastTruth
  use strict arg altitude,step
  level=self~levelAt(altitude)
  band=bands[level]
  /* Bounded, correlated gusts: direction is never modified by advance. */
  lo=band[2];hi=band[3]
  mean=(lo+hi)/2
  speed=band[4]+0.18*(mean-band[4])+(self~random-0.5)*0.85
  speed=max(lo,min(hi,speed))
  band[4]=speed
  dir=band[1]
  v=.directory~new
  v['STEP']=step;v['LEVEL']=level;v['BEARING_DEG']=dir
  v['GUST_MPS']=speed;v['MIN_MPS']=lo;v['MAX_MPS']=hi
  v['EAST_MPS']=speed*RxCalcSin(dir)
  v['NORTH_MPS']=speed*RxCalcCos(dir)
  lastTruth=v
  return v

::class Slam450AirflowInstruments public
::method sample
  /* airE/airN = craft ground velocity minus local wind, in m/s.
     This is apparent air *relative to craft*, not privileged true wind. */
  use strict arg airE,airN,heading,level
  if level<1 | level>3 then raise syntax 88.900 array('invalid flight level')
  fwd=airE*RxCalcSin(heading)+airN*RxCalcCos(heading)
  right=airE*RxCalcCos(heading)-airN*RxCalcSin(heading)
  cup=HSqrt(fwd*fwd+right*right)
  packet=.directory~new
  packet['SOURCE']='VIRTUAL_PRESSURE_CUP_SAIL'
  packet['FLIGHT_LEVEL']='L'||level
  packet['CUP_AIRSPEED_MPS']=cup
  packet['PITOT_FORWARD_MPS']=0
  packet['PITOT_STATUS']='OUT_OF_FORWARD_ARC'
  packet['SAIL']='NEUTRAL'
  /* Static capture arc: 55 degrees either side of the front-port pitot.
     Negative/reverse airflow cannot be interpreted as forward airspeed. */
  if fwd>0.01 then do
    angle=RxCalcArcTan(abs(right)/fwd)
    if angle<=55 then do
      packet['PITOT_FORWARD_MPS']=fwd
      packet['PITOT_STATUS']='CAPTURED_FORWARD'
    end
  end
  /* Airflow (wind minus craft velocity) is the NEGATIVE of air-relative
     craft velocity. Positive craft-right motion is starboard-to-port flow.
     Only the categorical sail sign is exposed, not an angle. */
  if right>0.3 then packet['SAIL']='STARBOARD_TO_PORT'
  if right< -0.3 then packet['SAIL']='PORT_TO_STARBOARD'
  packet['CUP_STATUS']='SPEED_ONLY_NO_FINE_DIRECTION'
  packet['SAIL_STATUS']='COARSE_CROSS_DIRECTION_ONLY'
  return packet

::class Slam450WindMemory public
::attribute slots get
::attribute ideas get
::attribute capacity get
::method init
  expose slots ideas capacity
  use strict arg maxSlots=36
  if maxSlots<6 | maxSlots>256 then raise syntax 88.900 array('wind memory capacity outside limits')
  slots=.array~new;ideas=.directory~new;capacity=maxSlots
::method record
  expose slots ideas capacity
  use strict arg step,packet,ownForward=0,visualEvidence='UNKNOWN'
  if \datatype(step,'W') | step<1 then raise syntax 88.900 array('wind observation step invalid')
  /* Reject privileged oracle fields instead of quietly storing them. */
  if packet~hasIndex('WIND_EAST_MPS') | packet~hasIndex('WIND_NORTH_MPS') | ,
      packet~hasIndex('WIND_BEARING_DEG') | packet~hasIndex('TRUE_X') then ,
       raise syntax 88.900 array('oracle wind or pose in pilot sensor packet')
  level=packet['FLIGHT_LEVEL']
  if level\=='L1' & level\=='L2' & level\=='L3' then raise syntax 88.900 array('bad wind band')
  cup=packet['CUP_AIRSPEED_MPS'];pressure=packet['PITOT_FORWARD_MPS']
  if \datatype(cup,'N') | \datatype(pressure,'N') | cup<0 | pressure<0 then ,
      raise syntax 88.900 array('invalid airflow measurement')
  sail=packet['SAIL']
  if sail\=='NEUTRAL' & sail\=='STARBOARD_TO_PORT' & sail\=='PORT_TO_STARBOARD' then ,
      raise syntax 88.900 array('invalid sail coarse direction')
  if \ideas~hasIndex(level) then do
    h=.directory~new
    h['COUNT']=0;h['LAST_CUP']='UNKNOWN';h['LAST_SAIL']='UNKNOWN';h['LAST_FORWARD']='UNKNOWN'
    h['CONSISTENT']=0;h['GUST_TREND']='UNKNOWN'
    h['IDEA']='INSUFFICIENT_EVIDENCE';h['CONFIDENCE']='UNTESTED'
    ideas[level]=h
  end
  h=ideas[level]
  trend='UNKNOWN'
  if h['LAST_CUP']\=='UNKNOWN' then do
    if h['LAST_FORWARD']=='UNKNOWN' | abs(ownForward-h['LAST_FORWARD'])>0.25 then ,
      trend='CONFOUNDED_BY_CONTROL_CHANGE'
    else if cup>h['LAST_CUP']+0.12 then trend='GUST_CANDIDATE_RISING'
    else if cup<h['LAST_CUP']-0.12 then trend='GUST_CANDIDATE_FALLING'
    else trend='APPARENT_AIRSPEED_NEAR_STEADY'
  end
  if sail\=='NEUTRAL' & sail==h['LAST_SAIL'] then h['CONSISTENT']+=1
  else if sail\=='NEUTRAL' then h['CONSISTENT']=1
  else h['CONSISTENT']=0
  h['COUNT']+=1;h['LAST_CUP']=cup;h['LAST_SAIL']=sail;h['LAST_FORWARD']=ownForward;h['GUST_TREND']=trend
  idea='FLOW_MEASURED_DIRECTION_UNRESOLVED';confidence='LOW'
  if h['CONSISTENT']>=3 then do
    idea='REPEATED_'||sail||'_AT_THIS_HEADING_CANDIDATE';confidence='CANDIDATE'
  end
  if packet['PITOT_STATUS']=='OUT_OF_FORWARD_ARC' then do
    idea='SIDE_OR_REVERSE_FLOW_CANDIDATE'
    confidence='LOW'
  end
  if h['CONSISTENT']>=3 & visualEvidence=='VISUAL_MOTION_RESIDUAL_CANDIDATE' then do
    idea='CROSSWIND_ASSOCIATED_WITH_VISUAL_DRIFT_CANDIDATE'
    confidence='CANDIDATE'
  end
  h['IDEA']=idea;h['CONFIDENCE']=confidence
  slot=.directory~new
  slot['STEP']=step;slot['LEVEL']=level
  slot['PRESSURE_FORWARD_MPS']=pressure;slot['PITOT_STATUS']=packet['PITOT_STATUS']
  slot['CUP_AIRSPEED_MPS']=cup;slot['SAIL']=sail
  slot['OWN_COMMANDED_FORWARD_MPS']=ownForward
  slot['VISUAL_DRIFT_EVIDENCE']=visualEvidence
  slot['GUST_TREND']=trend;slot['IDEA']=idea;slot['CONFIDENCE']=confidence
  if slots~items>=capacity then do
    kept=.array~new
    do i=2 to slots~items;kept~append(slots[i]);end
    slots=kept
  end
  slots~append(slot)
  return slot
::method ideaAt
  expose ideas
  use strict arg level
  if \ideas~hasIndex(level) then return 'NO_OBSERVATION'
  return ideas[level]['IDEA']
::method saveObservations
  expose slots
  use strict arg file
  call SysFileDelete file
  call lineout file,'step,level,pitot_forward_mps,pitot_status,cup_airspeed_mps,sail,own_forward_command_mps,visual_drift_evidence,gust_trend,idea,confidence'
  do s over slots
    call lineout file,s['STEP']||','||s['LEVEL']||','||s['PRESSURE_FORWARD_MPS']||','||s['PITOT_STATUS']||','||s['CUP_AIRSPEED_MPS']||','||s['SAIL']||','||s['OWN_COMMANDED_FORWARD_MPS']||','||s['VISUAL_DRIFT_EVIDENCE']||','||s['GUST_TREND']||','||s['IDEA']||','||s['CONFIDENCE']
  end
  call stream file,'C','CLOSE'
  return slots~items

::method loadObservations
  expose slots ideas capacity
  use strict arg file
  if stream(file,'C','QUERY EXISTS')=='' then return 'NO_ARCHIVE'
  header=linein(file)
  expected='step,level,pitot_forward_mps,pitot_status,cup_airspeed_mps,sail,own_forward_command_mps,visual_drift_evidence,gust_trend,idea,confidence'
  if header\==expected then do
    call stream file,'C','CLOSE'
    return 'REJECTED_HEADER'
  end
  /* Replay only raw recorded measurements into a temporary memory.
     Never trust an archived idea, interpretation or simulator wind vector. */
  replay=.Slam450WindMemory~new(capacity)
  n=0;prior=0
  do while lines(file)>0
    line=linein(file)
    if line~strip=='' then iterate
    parse var line step ',' level ',' pitot ',' status ',' cup ',' sail ',' ownForward ',' visual ',' oldTrend ',' oldIdea ',' oldConfidence ',' trailing
    if trailing\=='' | \datatype(step,'W') | step<=prior | ,
       \datatype(pitot,'N') | \datatype(cup,'N') | \datatype(ownForward,'N') then ,
         raise syntax 88.900 array('invalid archived wind observation')
    if status\=='CAPTURED_FORWARD' & status\=='OUT_OF_FORWARD_ARC' then ,
         raise syntax 88.900 array('invalid archived pitot status')
    allowed=.array~of('UNKNOWN','INSUFFICIENT_IMAGE_HISTORY',,
       'VISUAL_MOTION_RESIDUAL_CANDIDATE','VISUAL_MOTION_CONSISTENT_WITH_YAW',,
       'IMAGE_SHIFT_UNRESOLVED')
    okay=.false
    do opt over allowed
      if visual==opt then okay=.true
    end
    if \okay then raise syntax 88.900 array('invalid archived visual evidence')
    packet=.directory~new
    packet['FLIGHT_LEVEL']=level;packet['PITOT_FORWARD_MPS']=pitot
    packet['CUP_AIRSPEED_MPS']=cup;packet['SAIL']=sail
    packet['PITOT_STATUS']=status
    ignored=replay~record(step,packet,ownForward,visual)
    n+=1;prior=step
    if n>capacity then raise syntax 88.900 array('wind archive exceeds memory slots')
  end
  call stream file,'C','CLOSE'
  slots=replay~slots;ideas=replay~ideas
  return n
