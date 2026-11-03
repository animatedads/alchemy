/* dev51: fixed-wing point mass — glide, trim, turn, wind, stall. */
numeric digits 16
polar=.FixedWingParabolicPolar~new(0.044,7,0.8,1.3,-2)
prop=.ElectricPropellerMap~new(8,18,0.127,0.85,0.8)
ac=.FixedWingAircraft~new(1.4,0.4,0.24,polar,prop,2,30)
lane=ac~lane
ld=polar~maximumLiftToDrag
if abs(ld-1/(2*lane~sqrt(0.044/(lane~pi*0.8*7))))>1e-12 then do; say 'FAIL L/Dmax formula'; exit 1; end
/* 1. Natural glide: T=0 at best-L/D path angle keeps speed, ratio = L/D. */
st=.FixedWingFlightState~new(ac,0,0,200,0,8)
g=-lane~degrees(lane~atan(1/ld))
do 30; p=st~propose(1,0,0,g); ignored=st~commit(p); end
ratio=st~y/(200-st~z)
if abs(ratio-ld)>0.01 | abs(st~airspeed-8)>0.1 then do; say 'FAIL glide ratio' ratio 'v' st~airspeed; exit 1; end
/* 2. Level trim: throttle for drag holds airspeed; energy = P*dt. */
t=ac~trim(9,0,0,1.225); thr=prop~throttleFor(t['DRAG'],9,1.225)
st=.FixedWingFlightState~new(ac,0,0,100,90,9); p=st~propose(1,thr,0,0)
pw=prop~evaluate(.PropulsionOperatingPoint~new(thr,9,1.225))['ELECTRICAL_POWER']+2
if abs(p['AIRSPEED']-9)>1e-6 | abs(p['ELECTRICAL_ENERGY']-pw)>1e-6 then do; say 'FAIL level trim/energy' p['AIRSPEED'] p['ELECTRICAL_ENERGY'] pw; exit 1; end
/* 3. Coordinated turn: dpsi = g tan(phi)/V; bank limited to 30 deg. */
st=.FixedWingFlightState~new(ac,0,0,100,0,9)
t=ac~trim(9,0,20,1.225); thr=prop~throttleFor(t['DRAG'],9,1.225)
p=st~propose(1,thr,20,0)
want=lane~degrees(9.80665*lane~tan(lane~radians(20))/9)
if abs(p['HEADING']-want)>1e-6 then do; say 'FAIL turn rate' p['HEADING'] want; exit 1; end
p=st~propose(1,1,75,0)
if p['BANK']<>30 then do; say 'FAIL bank limit'; exit 1; end
/* 4. Air-mass drift: wind adds exactly w*dt to ground track. */
st=.FixedWingFlightState~new(ac,0,0,100,0,9)
a=st~propose(1,thr,0,0); b=st~propose(1,thr,0,0,2,-1)
if abs(b['X']-a['X']-2)>1e-9 | abs(b['Y']-a['Y']+1)>1e-9 then do; say 'FAIL wind drift'; exit 1; end
/* 5. Stall fails closed and cannot be committed. */
st=.FixedWingFlightState~new(ac,0,0,100,0,6)
p=st~propose(1,0,0,0)
if p['STATUS']<>'STALL' then do; say 'FAIL stall not reported'; exit 1; end
signal on syntax name ok
ignored=st~commit(p)
say 'FAIL stalled proposal committed'; exit 1
ok:
say 'PHYSICS FIXED WING FLIGHT: OK L/D=' ld 'glide=' ratio 'stall=' ac~stallSpeed(1.225)
::requires 'FixedWingFlight.cls'
