/* dev51: multirotor momentum-theory power. Claude (Opus 5.5). */
numeric digits 16
m=.MultirotorMomentumModel~new(1.2,4,0.1143,0.6,95.8,0.04,0.75,2)
lane=.MathBinary64ScalarLane~new
w=1.2*9.80665; a=4*lane~pi*0.1143**2
ideal=w*lane~sqrt(w/(2*1.225*a))
h=m~power(0,0,1.225)
if abs(h['ELECTRICAL_POWER']-(ideal/0.6/0.75+2))>1e-6 then do; say 'FAIL hover = Pideal/FM/eta + avionics'; exit 1; end
if abs(h['INDUCED_VELOCITY']-h['HOVER_INDUCED_VELOCITY'])>1e-9 then do; say 'FAIL hover vi=vh'; exit 1; end
p5=m~power(5,0,1.225)['ELECTRICAL_POWER']; p20=m~power(20,0,1.225)['ELECTRICAL_POWER']
if \(p5<h['ELECTRICAL_POWER']) then do; say 'FAIL translational lift lowers power at 5 m/s'; exit 1; end
if \(p20>h['ELECTRICAL_POWER']) then do; say 'FAIL parasite drag dominates at 20 m/s'; exit 1; end
c=m~power(0,2,1.225)
if \(c['ELECTRICAL_POWER']>h['ELECTRICAL_POWER']) | c['CLIMB_POWER']<=0 then do; say 'FAIL climb costs power'; exit 1; end
d=m~power(0,-2,1.225)
if d['ELECTRICAL_POWER']<>h['ELECTRICAL_POWER'] | d['REGIME']<>'VORTEX_RING_RISK_NOT_MODELLED' then do; say 'FAIL descent gets no credit and flags VRS'; exit 1; end
r=m~power(7,1,1.225); vi=r['INDUCED_VELOCITY']; vh=r['HOVER_INDUCED_VELOCITY']
res=vi**4+2*1*vi**3+(49+1)*vi*vi-vh**4
if abs(res)>1e-6 then do; say 'FAIL Glauert residual' res; exit 1; end
signal on syntax name ok
x=.MultirotorMomentumModel~new(1.2,4,0.1143,0.9,95.8,0.04,0.75,2,1.15)
say 'FAIL negative profile power accepted'; exit 1
ok:
say 'PHYSICS MULTIROTOR MOMENTUM POWER: OK hover=' h['ELECTRICAL_POWER'] 'W p5=' p5 'p20=' p20
::requires 'Propulsion.cls'
