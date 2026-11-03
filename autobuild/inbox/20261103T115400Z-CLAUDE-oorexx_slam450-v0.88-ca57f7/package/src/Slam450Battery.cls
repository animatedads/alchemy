/* SLAM450 v0.84/v0.88 — battery accounting and bounded private energy ideas.
 * User architecture: per-tick battery meter, costly lookups, cheap comms,
 * speed-sensitive forward flight and gravity-assisted descent.
 * Units are synthetic energy units, NOT measured electrical joules.
 * Authority holds the battery; pilot receives only report copies.
 */
::requires 'Slam450Flight.cls'
::requires 'Slam450Airframe.cls'
::class Slam450Battery public
::attribute capacity get
::attribute remaining get
::attribute radioCost get
::attribute remoteCost get
::attribute used get
::attribute flightUsed get
::attribute lookupUsed get
::attribute commUsed get
::attribute airframe get
::method init
  expose capacity remaining radioCost remoteCost used flightUsed lookupUsed commUsed airframe
  use strict arg startCapacity=900,frame=.nil
  if \datatype(startCapacity,'N') | startCapacity<=0 then ,
    raise syntax 88.900 array('battery capacity invalid')
  if frame==.nil then frame=.Slam450QuadAirframe~new
  airframe=frame
  capacity=startCapacity;remaining=capacity
  radioCost=0.03;remoteCost=100*radioCost
  used=0;flightUsed=0;lookupUsed=0;commUsed=0
::method quote
  /* v0.88: the price list belongs to the airframe (quad power curve or
     fixed-wing energy-height budget). The battery only holds charge. */
  expose airframe
  use strict arg command,powerAvailable=.true
  if airframe~KIND=='FIXED_WING' then return airframe~quote(command,powerAvailable)
  return airframe~quote(command)
::method affordable
  expose remaining
  numeric digits 16
  use strict arg amount
  if \datatype(amount,'N') | amount<0 then ,
    raise syntax 88.900 array('invalid debit quote')
  return amount<=remaining+0.0000000001
::method debit
  expose remaining used flightUsed lookupUsed commUsed
  numeric digits 16
  use strict arg kind,amount
  if kind\=='FLIGHT' & kind\=='LOOKUP' & kind\=='RADIO' then ,
    raise syntax 88.900 array('unknown battery debit category')
  if \self~affordable(amount) then return .false
  remaining=max(0,remaining-amount)
  used+=amount
  select
    when kind=='FLIGHT' then flightUsed+=amount
    when kind=='LOOKUP' then lookupUsed+=amount
    when kind=='RADIO' then commUsed+=amount
  end
  return .true
::method report
  expose remaining capacity used flightUsed lookupUsed commUsed radioCost remoteCost airframe
  numeric digits 16
  packet=.directory~new
  packet['SOURCE']='OWN_BATTERY_METER'
  packet['REMAINING']=remaining
  packet['CAPACITY']=capacity
  packet['PERCENT']=100*remaining/capacity
  packet['FLIGHT_USED']=flightUsed
  packet['LOOKUP_USED']=lookupUsed
  packet['RADIO_USED']=commUsed
  packet['TOTAL_USED']=used
  packet['REMOTE_COST']=remoteCost
  packet['RADIO_COST']=radioCost
  /* Own aircraft data sheet: public spec of THIS airframe, not oracle. */
  spec=airframe~spec
  packet['AIRFRAME']=spec['AIRFRAME']
  packet['CRUISE_SPEED']=spec['CRUISE_SPEED']
  packet['CRUISE_COST']=spec['CRUISE_COST']
  packet['CLIMB_COST_PER_M']=spec['CLIMB_COST_PER_M']
  packet['HOVER_COST']=spec['HOVER_COST']
  packet['CAN_HOVER']=spec['CAN_HOVER']
  packet['BEST_RANGE_SPEED']=spec['BEST_RANGE_SPEED']
  packet['CRUISE_STEPS_ESTIMATE']=trunc(remaining/spec['CRUISE_COST'])
  return packet

::class Slam450BatteryPolicy public
::method adjust
  /* An advisory pilot-side policy. Only the craft's OWN meter is visible;
     the power oracle never discloses its hidden trajectory or wind. */
  use strict arg requested,meter
  /* v0.88: below 32% stop sprinting above the airframe's own best-range
     speed (quad 6 m/s on the physical power curve). Under 15% the quad
     keeps best-range speed: crawling at 3 m/s costs MORE per metre now. */
  command=requested~copy
  cap=6
  if meter~hasIndex('BEST_RANGE_SPEED') then cap=meter['BEST_RANGE_SPEED']
  if meter['PERCENT']<32 then do
    if command[2]>cap then command[2]=cap
  end
  return command
::method wantRemote
  use strict arg meter,tick,frame,target,mode='AUTO'
  mode=mode~upper
  if mode=='NONE' then return .false
  if meter['REMAINING']<meter['REMOTE_COST']+meter['CRUISE_COST'] then return .false
  if mode=='EVERY' then return .true
  if mode=='FIFTH' then return tick>0 & tick//5==0
  if mode\=='AUTO' then raise syntax 88.900 array('unsupported lookup policy')
  if meter['PERCENT']<20 then return .false
  if meter['PERCENT']<40 then return tick>0 & tick//10==0
  /* Ordinary rhythm: 1/5. If a target is unseen, an earlier request
     can be rational, demonstrating the new any-turn capability. */
  if tick>0 & tick//5==0 then return .true
  obs=(.Slam450Vision~new)~observe(frame,target)
  if obs==.nil & tick>0 & tick//7==0 then return .true
  return .false
::method canTransmit
  use strict arg meter
  return meter['REMAINING']>meter['RADIO_COST']+meter['CRUISE_COST']

::class Slam450BatteryMemory public
::attribute slots get
::attribute capacity get
::attribute idea get
::method init
  expose slots capacity idea
  use strict arg maxSlots=48
  if maxSlots<8 | maxSlots>256 then raise syntax 88.900 array('bad energy memory capacity')
  capacity=maxSlots;slots=.array~new;idea='UNKNOWN'
::method observe
  expose slots capacity idea
  use strict arg tick,meter,command,lookedUp=.false,sent=0
  if meter['SOURCE']\=='OWN_BATTERY_METER' then ,
    raise syntax 88.900 array('not a local battery meter')
  if meter~hasIndex('TRUE_X') | meter~hasIndex('WIND_EAST_MPS') then ,
    raise syntax 88.900 array('oracle field in energy memory')
  if \datatype(tick,'W') | tick<0 then raise syntax 88.900 array('invalid energy tick')
  note=.directory~new
  note['TICK']=tick;note['REMAINING']=meter['REMAINING']
  note['PERCENT']=meter['PERCENT'];note['FLIGHT_USED']=meter['FLIGHT_USED']
  note['LOOKUP_USED']=meter['LOOKUP_USED'];note['RADIO_USED']=meter['RADIO_USED']
  note['CRUISE_STEPS_ESTIMATE']=meter['CRUISE_STEPS_ESTIMATE']
  note['FORWARD_REQUEST']=command[2];note['CLIMB_REQUEST']=command[3]
  note['REMOTE_LOOKUP']=lookedUp;note['RADIO_SENT']=sent
  idea='CRUISE_AVAILABLE'
  if command[2]>3 then idea='FAST_FORWARD_HAS_SUPERLINEAR_COST'
  if command[3]>0 then idea='ASCENT_ADDS_COST'
  if lookedUp then idea='REMOTE_IMAGE_COSTS_100_RADIO_MESSAGES'
  if meter['PERCENT']<32 then idea='CONSERVE_FAST_THRUST'
  if meter['PERCENT']<20 then idea='PRIORITISE_VISIBLE_TARGETS_AND_SKIP_REMOTE'
  note['IDEA']=idea
  if slots~items>=capacity then do
    shorter=.array~new
    do i=2 to slots~items;shorter~append(slots[i]);end
    slots=shorter
  end
  slots~append(note)
  return note
::method peerSummary
  /* Local bounded observation ring. Report measured category deltas and a
     separate tentative idea; exact wind, XYZ and route stay unavailable. */
  expose slots
  use strict arg tick,meter,window=8
  if meter['SOURCE']\=='OWN_BATTERY_METER' then ,
    raise syntax 88.900 array('only local battery observations may be summarised')
  if meter~hasIndex('TRUE_X') | meter~hasIndex('WIND_EAST_MPS') then ,
    raise syntax 88.900 array('oracle field not permitted')
  dt=0;df=0;dl=0;dr=0;climbed=.false
  n=slots~items
  if n>0 then do
    oldest=max(1,n-window+1)
    start=slots[oldest]
    dt=max(0,tick-start['TICK'])
    df=max(0,meter['FLIGHT_USED']-start['FLIGHT_USED'])
    dl=max(0,meter['LOOKUP_USED']-start['LOOKUP_USED'])
    dr=max(0,meter['RADIO_USED']-start['RADIO_USED'])
    do j=oldest to n
      if slots[j]['CLIMB_REQUEST']>0 then climbed=.true
    end
  end
  rate=0
  if dt>0 then rate=(df+dl+dr)/dt
  idea='INITIAL_SAMPLE';confidence='TENTATIVE'
  if dt>=2 then do
    idea='NORMAL_CRUISE_DRAIN';confidence='OBSERVED_COST'
    if rate>2 then idea='HIGH_RECENT_DRAIN'
    if climbed & df>0 then idea='CLIMB_ADDS_DRAIN'
    if dl>df & dl>dr then idea='REMOTE_LOOKUPS_DOMINATE'
    if meter['PERCENT']<20 then idea='LOW_BATTERY_RESERVE'
  end
  d=.directory~new
  d['WINDOW_TURNS']=dt;d['DELTA_FLIGHT']=df
  d['DELTA_REMOTE']=dl;d['DELTA_RADIO']=dr
  d['BURN_RATE']=rate;d['THEORY']=idea;d['CONFIDENCE']=confidence
  return d
::method save
  expose slots
  use strict arg file
  call SysFileDelete file
  call lineout file,'tick,remaining,percent,flight_used,lookup_used,radio_used,cruise_steps_est,forward_cmd,up_cmd,lookup,radio_sent,idea'
  do note over slots
    call lineout file,note['TICK']||','||note['REMAINING']||','||note['PERCENT']||','||note['FLIGHT_USED']||','||note['LOOKUP_USED']||','||note['RADIO_USED']||','||note['CRUISE_STEPS_ESTIMATE']||','||note['FORWARD_REQUEST']||','||note['CLIMB_REQUEST']||','||note['REMOTE_LOOKUP']||','||note['RADIO_SENT']||','||note['IDEA']
  end
  call stream file,'C','CLOSE'
  return slots~items
