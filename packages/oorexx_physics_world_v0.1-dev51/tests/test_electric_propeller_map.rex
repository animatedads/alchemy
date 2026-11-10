/* dev51: electric propeller map composes with PropulsionUnit. */
numeric digits 16
p=.ElectricPropellerMap~new(8,18,0.127,0.85,0.8)
if p~availableThrust(0,1.225)<>8 | p~availableThrust(18,1.225)<>0 then do; say 'FAIL thrust law ends'; exit 1; end
thr=p~throttleFor(2,8,1.225)
o=p~evaluate(.PropulsionOperatingPoint~new(thr,8,1.225))
if abs(o['THRUST']-2)>1e-12 then do; say 'FAIL throttle inverse'; exit 1; end
lane=.MathBinary64ScalarLane~new; area=lane~pi*0.127**2
vi=(-8+lane~sqrt(64+2*2/(1.225*area)))/2
if abs(o['ELECTRICAL_POWER']-2*(8+vi)/0.85/0.8)>1e-9 then do; say 'FAIL actuator-disc power'; exit 1; end
u=.PropulsionUnit~new(p); ob=u~step(1,.PropulsionOperatingPoint~new(0,8,1.225))
if ob~thrust<>0 | ob~totalFuel<>0 then do; say 'FAIL zero throttle, zero fuel'; exit 1; end
signal on syntax name ok
x=p~throttleFor(9,0,1.225)
say 'FAIL unattainable thrust accepted'; exit 1
ok:
say 'PHYSICS ELECTRIC PROPELLER MAP: OK P(2N@8m/s)=' o['ELECTRICAL_POWER'] 'W'
::requires 'Propulsion.cls'
