/* SLAM450 v0.88 airframes — adapters over Physics World dev51.
 * Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.
 *
 * Physics is NOT implemented here. This file binds SLAM's command/pose
 * conventions to the Alchemy physics authorities:
 *   QUAD        -> MultirotorMomentumModel (momentum theory, Glauert)
 *   FIXED_WING  -> FixedWingAircraft + FixedWingFlightState (point mass,
 *                  parabolic polar as alpha tables) + ElectricPropellerMap
 * Scalar maths uses the Maths v0.20 BINARY64 lane.
 *
 * Energy unit: 1 unit = the quad's hover electrical power for 1 s
 * (143.45 J at sea level). Both airframes are priced in the same joules.
 * Tick = 1 s. Pose = array(east_m, north_m, up_m, heading_deg).
 *
 * Commands:
 *   QUAD        array(yaw_deg, forward_mps, climb_mps, side_mps)
 *   FIXED_WING  array(turn_deg_per_tick, airspeed_setpoint_mps, climb_mps, 0)
 *               — setpoints for the aircraft's own inner-loop autopilot,
 *               which computes throttle, bank and flight-path angle from
 *               its own airspeed only (no oracle).
 */
::requires 'Slam450Flight.cls'
::requires 'Propulsion.cls'
::requires 'FixedWingFlight.cls'
::requires 'MathFastLanes.cls'

::class Slam450AirframeConstants public
::constant RHO 1.225
::method hoverJoules class
  /* The energy unit, from the quad physics model itself. */
  numeric digits 16
  return .Slam450QuadAirframe~physicsModel~hoverElectricalPower(self~RHO)

/* ------------------------------------------------------------------ */
::class Slam450QuadAirframe public
/* 450-size quad: 1.2 kg AUW, 4 x 9in (0.1143 m) rotors, FM 0.60,
 * tip speed 95.8 m/s (8000 rpm), parasite drag area 0.04 m^2,
 * motor+ESC efficiency 0.75, avionics 2 W. 4S 2400 mAh ~ 35.9 Wh pack. */
::constant KIND 'QUAD'
::constant CAPACITY 900
::method physicsModel class
  return .MultirotorMomentumModel~new(1.2,4,0.1143,0.6,95.8,0.04,0.75,2)
::method init
  expose model ph lane
  model=.Slam450QuadAirframe~physicsModel
  ph=model~hoverElectricalPower(.Slam450AirframeConstants~RHO)
  lane=.MathBinary64ScalarLane~new
::method units private
  expose ph
  use strict arg watts
  numeric digits 16
  return watts/ph
::method powerUnits
  expose model
  use strict arg airspeed,climb
  return self~units(model~power(airspeed,climb,.Slam450AirframeConstants~RHO)['ELECTRICAL_POWER'])
::method spec
  expose specCache
  if var('specCache') then if specCache\==.nil then return specCache
  specCache=self~computeSpec
  return specCache
::method computeSpec
  numeric digits 16
  best=1;bestCost=1e9
  do v=1 to 7 by 0.5
    c=self~powerUnits(v,0)/v
    if c<bestCost then do;bestCost=c;best=v;end
  end
  d=.directory~new
  d['AIRFRAME']=self~KIND
  d['CAPACITY']=self~CAPACITY
  d['HOVER_COST']=self~powerUnits(0,0)
  d['CRUISE_SPEED']=3
  d['CRUISE_COST']=self~powerUnits(3,0)
  d['BEST_RANGE_SPEED']=best
  d['BEST_RANGE_COST']=self~powerUnits(best,0)
  d['CLIMB_COST_PER_M']=self~powerUnits(0,1)-self~powerUnits(0,0)
  d['MIN_SPEED']=0
  d['MAX_SPEED']=7
  d['CAN_HOVER']=1
  d['PHYSICS']='MultirotorMomentumModel dev51'
  return d
::method clamp
  use strict arg command
  if \command~isA(.array) | command~items<3 then ,
    raise syntax 88.900 array('invalid flight command for airframe')
  do j=1 to min(4,command~items)
    if \datatype(command[j],'N') then ,
      raise syntax 88.900 array('non numeric flight command')
  end
  yaw=max(-25,min(25,command[1]))
  fwd=max(-3,min(7,command[2]))
  up=max(-4,min(4,command[3]))
  side=0
  if command~items>=4 then side=max(-3,min(3,command[4]))
  return .array~of(yaw,fwd,up,side)
::method quote
  expose model lane
  use strict arg command
  numeric digits 16
  c=self~clamp(command)
  v=lane~sqrt(c[2]**2+c[4]**2)
  p=model~power(v,c[3],.Slam450AirframeConstants~RHO)
  q=.directory~new
  q['AIRFRAME']=self~KIND
  q['INDUCED']=self~units(p['INDUCED_POWER']/0.75)
  q['PROFILE']=self~units(p['PROFILE_POWER']/0.75)
  q['PARASITE']=self~units(p['PARASITE_POWER']/0.75)
  q['ASCENT']=self~units(p['CLIMB_POWER']/0.75)
  q['AVIONICS']=self~units(2)
  q['AIRSPEED']=v
  q['THROTTLE']=''
  q['MODE']=p['REGIME']
  q['TOTAL']=self~units(p['ELECTRICAL_POWER'])
  return q
::method propose
  /* Kinematics unchanged from v0.6-v0.87: a quad station-keeps, so only
     45% of the wind displaces it per tick. */
  expose lane
  use strict arg old,command,wind
  numeric digits 16
  c=self~clamp(command)
  heading=old[4]+c[1]
  do while heading<0;heading+=360;end
  do while heading>=360;heading-=360;end
  hr=lane~radians(heading)
  e=c[2]*lane~sin(hr)+c[4]*lane~cos(hr)
  n=c[2]*lane~cos(hr)-c[4]*lane~sin(hr)
  windE=0;windN=0
  if wind\==.nil then do;windE=wind['EAST_MPS'];windN=wind['NORTH_MPS'];end
  next=.array~of(old[1]+e+0.45*windE,old[2]+n+0.45*windN,old[3]+c[3],heading)
  packet=.nil
  if wind\==.nil then packet=(.Slam450AirflowInstruments~new)~sample(,
    e-0.55*windE,n-0.55*windN,heading,wind['LEVEL'])
  state=.directory~new;state['MODE']='POWERED';state['STATUS']='OK'
  state['AIRSPEED']=lane~sqrt(c[2]**2+c[4]**2)
  state['THROTTLE']=''
  return .array~of(next,packet,state)
::method commit
  use strict arg state
  return .true
::method airspeed
  return 0
::method glideCommand
  return .nil

/* ------------------------------------------------------------------ */
::class Slam450FixedWingAirframe public
/* Electric prop trainer: 1.4 kg, wing 0.40 m^2, AR 7 (span 1.67 m),
 * chord 0.24 m, CD0 0.044, Oswald 0.8, CLmax 1.3, alpha0 -2 deg
 *   -> L/Dmax 10.0 at ~8 m/s, stall 6.57 m/s (Physics-derived).
 * Propeller 10in (0.127 m), static thrust 8 N, pitch speed 18 m/s,
 * profile efficiency 0.85, motor 0.80, avionics 2 W, bank limit 30 deg.
 * Pack: 3S 2200 mAh (24.42 Wh). Air-mass drift is the full wind vector. */
::constant KIND 'FIXED_WING'
::constant PACK_WH 24.42
::constant VMIN 7.2
::constant VMAX 11
::constant VBG 8
::constant ACCEL 1.0
::constant DECEL 1.5
::constant MAXCLIMB 3
::constant MAXDESCENT 3
::attribute lastMode get
::method aircraft class
  polar=.FixedWingParabolicPolar~new(0.044,7,0.8,1.3,-2)
  prop=.ElectricPropellerMap~new(8,18,0.127,0.85,0.8)
  return .FixedWingAircraft~new(1.4,0.4,0.24,polar,prop,2,30)
::method init
  expose ac state ph lane lastMode started polar
  use strict arg startSpeed=8
  ac=.Slam450FixedWingAirframe~aircraft
  polar=.FixedWingParabolicPolar~new(0.044,7,0.8,1.3,-2)
  ph=.Slam450AirframeConstants~hoverJoules
  lane=ac~lane
  state=.FixedWingFlightState~new(ac,0,0,0,0,startSpeed)
  started=.false;lastMode='POWERED'
::method CAPACITY
  expose ph
  numeric digits 16
  return self~PACK_WH*3600/ph
::method airspeed
  expose state
  return state~airspeed
::method sync private
  /* The referee owns pose; the physics state follows it each tick. */
  expose state ac started
  use strict arg old
  numeric digits 16
  if started then do
    if abs(state~x-old[1])<1e-6 & abs(state~y-old[2])<1e-6 & abs(state~z-old[3])<1e-6 then return
  end
  v=state~airspeed
  state=.FixedWingFlightState~new(ac,old[1],old[2],old[3],old[4],v)
  started=.true
::method autopilot
  /* Inner loop: setpoints -> throttle, bank, gamma, from own airspeed. */
  expose ac lane state
  use strict arg command,powerAvailable=.true
  numeric digits 16
  if \command~isA(.array) | command~items<3 then ,
    raise syntax 88.900 array('invalid flight command for airframe')
  do j=1 to min(4,command~items)
    if \datatype(command[j],'N') then ,
      raise syntax 88.900 array('non numeric flight command')
  end
  rho=.Slam450AirframeConstants~RHO
  g=ac~gravity;m=ac~mass;w=ac~weight
  v=state~airspeed
  vset=max(self~VMIN,min(self~VMAX,command[2]))
  climb=max(-self~MAXDESCENT,min(self~MAXCLIMB,command[3]))
  omega=lane~radians(command[1])
  bank=lane~degrees(lane~atan(v*omega/g))
  bank=max(-ac~bankLimit,min(ac~bankLimit,bank))
  gamma=lane~degrees(lane~asin(max(-0.99,min(0.99,climb/v))))
  aReq=max(-self~DECEL,min(self~ACCEL,vset-v))
  aReq=max(aReq,self~VMIN-v)                    /* stall protection */
  trimmed=ac~trim(v,gamma,bank,rho)
  if trimmed['STATUS']\=='TRIMMED' then do
    gamma=0;bank=0;trimmed=ac~trim(v,0,0,rho)
  end
  drag=trimmed['DRAG']
  mode='POWERED'
  if \powerAvailable then do
    /* Natural glide: T=0, choose the path angle whose along-path balance
       gives the requested speed change (holding VBG -> best L/D glide). */
    s=(-drag-m*aReq)/w
    gamma=lane~degrees(lane~asin(max(-0.99,min(0.99,s))))
    d=.directory~new
    d['THROTTLE']=0;d['BANK']=bank;d['GAMMA']=gamma;d['MODE']='POWER_OUT_GLIDE'
    return d
  end
  full=ac~propellerMap~availableThrust(v,rho)
  need=drag+w*lane~sin(lane~radians(gamma))+m*aReq
  if need>full then do
    /* Speed has priority: give up climb until thrust suffices. */
    s=(full-drag-m*max(0,aReq))/w
    gamma=min(gamma,lane~degrees(lane~asin(max(-0.99,min(0.99,s)))))
    throttle=1
  end
  else if need<0 then do
    /* Thrust off. Limit the dive so the airframe stays below VMAX. */
    throttle=0
    aGlide=(-drag-w*lane~sin(lane~radians(gamma)))/m
    if v+aGlide>self~VMAX then do
      s=(-drag-m*(self~VMAX-v))/w
      gamma=lane~degrees(lane~asin(max(-0.99,min(0.99,s))))
    end
  end
  else throttle=need/full
  throttle=max(0,min(1,throttle))
  if throttle<0.000001 then mode='GLIDE'
  d=.directory~new
  d['THROTTLE']=throttle;d['BANK']=bank;d['GAMMA']=gamma;d['MODE']=mode
  return d
::method spec
  expose specCache
  if var('specCache') then if specCache\==.nil then return specCache
  specCache=self~computeSpec
  return specCache
::method computeSpec
  expose ac polar
  numeric digits 16
  rho=.Slam450AirframeConstants~RHO
  best=self~VBG;bestCost=1e9
  do v=self~VMIN to self~VMAX by 0.2
    c=self~levelUnits(v)/v
    if c<bestCost then do;bestCost=c;best=v;end
  end
  d=.directory~new
  d['AIRFRAME']=self~KIND
  d['CAPACITY']=self~CAPACITY
  d['HOVER_COST']=''
  d['CRUISE_SPEED']=self~VBG
  d['CRUISE_COST']=self~levelUnits(self~VBG)
  d['BEST_RANGE_SPEED']=best
  d['BEST_RANGE_COST']=self~levelUnits(best)
  /* Energy per metre of climb at cruise: P(1 m/s climb) - P(level). */
  d['CLIMB_COST_PER_M']=self~climbUnits(self~VBG,1)-self~levelUnits(self~VBG)
  d['MIN_SPEED']=self~VMIN
  d['MAX_SPEED']=self~VMAX
  d['STALL_SPEED']=ac~stallSpeed(rho)
  d['GLIDE_RATIO']=polar~maximumLiftToDrag
  d['CAN_HOVER']=0
  d['PHYSICS']='FixedWingAircraft/FixedWingFlightState dev51'
  return d
::method levelUnits
  use strict arg v
  return self~climbUnits(v,0)
::method climbUnits
  expose ac ph lane
  use strict arg v,climb
  numeric digits 16
  rho=.Slam450AirframeConstants~RHO
  gamma=lane~degrees(lane~asin(climb/v))
  t=ac~trim(v,gamma,0,rho)
  thrust=t['DRAG']+ac~weight*lane~sin(lane~radians(gamma))
  thr=ac~propellerMap~throttleFor(thrust,v,rho)
  p=ac~propellerMap~evaluate(.PropulsionOperatingPoint~new(thr,v,rho))
  return (p['ELECTRICAL_POWER']+ac~avionicsPower)/ph
::method plan private
  expose state
  use strict arg old,command,wind,powerAvailable
  numeric digits 16
  self~sync(old)
  ap=self~autopilot(command,powerAvailable)
  windE=0;windN=0
  if wind\==.nil then do;windE=wind['EAST_MPS'];windN=wind['NORTH_MPS'];end
  p=state~propose(1,ap['THROTTLE'],ap['BANK'],ap['GAMMA'],windE,windN,.Slam450AirframeConstants~RHO,4)
  p['MODE']=ap['MODE']
  return p
::method quote
  /* Energy is air-relative: independent of wind, so quote without it. */
  expose ph state started
  use strict arg command,powerAvailable=.true
  numeric digits 16
  base=.array~of(state~x,state~y,state~z,state~heading)
  if \started then base=.array~of(0,0,100,0)
  p=self~plan(base,command,.nil,powerAvailable)
  q=.directory~new
  q['AIRFRAME']=self~KIND
  q['THROTTLE']=p['THROTTLE'];q['AIRSPEED']=p['AIRSPEED'];q['MODE']=p['MODE']
  q['BANK']=p['BANK'];q['GAMMA']=p['GAMMA'];q['STATUS']=p['STATUS']
  q['TOTAL']=p['ELECTRICAL_ENERGY']/ph
  return q
::method propose
  expose lane
  use strict arg old,command,wind,powerAvailable=.true
  numeric digits 16
  p=self~plan(old,command,wind,powerAvailable)
  next=.array~of(p['X'],p['Y'],p['Z'],p['HEADING'])
  packet=.nil
  if wind\==.nil then do
    /* Pitot sees air-relative velocity only. */
    gr=lane~radians(p['GAMMA']);hr=lane~radians(p['HEADING'])
    ve=p['AIRSPEED']*lane~cos(gr)*lane~sin(hr)
    vn=p['AIRSPEED']*lane~cos(gr)*lane~cos(hr)
    packet=(.Slam450AirflowInstruments~new)~sample(ve,vn,p['HEADING'],wind['LEVEL'])
  end
  return .array~of(next,packet,p)
::method commit
  expose state lastMode
  use strict arg proposal
  ignored=state~commit(proposal)
  lastMode=proposal['MODE']
  return .true
::method glideCommand
  /* Power-out: hold the turn, aim for best-glide speed. */
  use strict arg turn=0
  return .array~of(turn,self~VBG,0,0)
