/* SLAM450 v0.84 — battery accounting and bounded private energy ideas.
 * User architecture: per-tick battery meter, costly lookups, cheap comms,
 * speed-sensitive forward flight and gravity-assisted descent.
 * Units are synthetic energy units, NOT measured electrical joules.
 * Authority holds the battery; pilot receives only report copies.
 */
::requires 'Slam450Flight.cls'
::class Slam450Battery public
::attribute capacity get
::attribute remaining get
::attribute radioCost get
::attribute remoteCost get
::attribute used get
::attribute flightUsed get
::attribute lookupUsed get
::attribute commUsed get
::method init
  expose capacity remaining radioCost remoteCost used flightUsed lookupUsed commUsed
  use strict arg startCapacity=900
  if \datatype(startCapacity,'N') | startCapacity<=0 then ,
    raise syntax 88.900 array('battery capacity invalid')
  capacity=startCapacity;remaining=capacity
  radioCost=0.03;remoteCost=100*radioCost
  used=0;flightUsed=0;lookupUsed=0;commUsed=0
::method quote
  /* Identical clamp limits to the world dynamics. The command denotes
     requested airframe movement; energy uses requested speed, not the
     wind-influenced movement reported by the truth oracle. */
  use strict arg command
  if \command~isA(.array) | command~items<3 then ,
    raise syntax 88.900 array('invalid flight command for battery')
  do j=1 to min(4,command~items)
    if \datatype(command[j],'N') then ,
      raise syntax 88.900 array('non numeric flight command')
  end
  yaw=max(-25,min(25,command[1]))
  forward=max(-3,min(7,command[2]))
  up=max(-4,min(4,command[3]))
  side=0
  if command~items>=4 then side=max(-3,min(3,command[4]))
  base=0.08
  forwardCost=0.92*(abs(forward)/3)**2
  sideCost=0.35*(abs(side)/3)**2
  turnCost=0.06*abs(yaw)/25
  climbCost=0.90*max(0,up)   /* gravity: descent adds no climb charge */
  q=.directory~new
  q['BASE']=base;q['FORWARD']=forwardCost;q['SIDE']=sideCost
  q['TURN']=turnCost;q['ASCENT']=climbCost
  q['TOTAL']=base+forwardCost+sideCost+turnCost+climbCost
  return q
::method affordable
  expose remaining
  use strict arg amount
  if \datatype(amount,'N') | amount<0 then ,
    raise syntax 88.900 array('invalid debit quote')
  return amount<=remaining+0.0000000001
::method debit
  expose remaining used flightUsed lookupUsed commUsed
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
  expose remaining capacity used flightUsed lookupUsed commUsed radioCost remoteCost
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
  packet['CRUISE_STEPS_ESTIMATE']=trunc(remaining) /* forward=3, level, straight */
  return packet

::class Slam450BatteryPolicy public
::method adjust
  /* An advisory pilot-side policy. Only the craft's OWN meter is visible;
     the power oracle never discloses its hidden trajectory or wind. */
  use strict arg requested,meter
  command=requested~copy
  if meter['PERCENT']<32 then do
    if command[2]>3 then command[2]=3
  end
  if meter['PERCENT']<15 then do
    if command[2]>2.8 then command[2]=2.8
  end
  return command
::method wantRemote
  use strict arg meter,tick,frame,target,mode='AUTO'
  mode=mode~upper
  if mode=='NONE' then return .false
  if meter['REMAINING']<meter['REMOTE_COST']+0.08 then return .false
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
  return meter['REMAINING']>meter['RADIO_COST']+0.08

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
