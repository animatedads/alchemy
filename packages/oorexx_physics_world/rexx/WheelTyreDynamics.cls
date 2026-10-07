/* Physics World dev18: wheel/tyre rolling, slip, dissipation and wear evidence. */
::class RollingResistanceModel public
::method force; use strict arg normalLoad,speed; raise syntax 93.900 array('RollingResistanceModel~force must be implemented')
::class ConstantRollingResistance subclass RollingResistanceModel public
::method init
 expose _coefficient
 use strict arg coefficient
 if coefficient<0 then raise syntax 88.900 array('non-negative rolling resistance coefficient')
 _coefficient=coefficient+0
::method force
 expose _coefficient
 use strict arg normalLoad,speed
 if normalLoad<0 then raise syntax 88.900 array('non-negative normal load')
 return _coefficient*normalLoad

::class TyreWearLaw public
::method wearIncrement; use strict arg dissipatedEnergy; raise syntax 93.900 array('TyreWearLaw~wearIncrement must be implemented')
::class EnergyProportionalWearLaw subclass TyreWearLaw public
/* Explicit calibration: wear depth per joule. No universal wear constant is claimed. */
::method init
 expose _metresPerJoule
 use strict arg metresPerJoule
 if metresPerJoule<0 then raise syntax 88.900 array('non-negative calibrated wear per joule')
 _metresPerJoule=metresPerJoule+0
::method wearIncrement
 expose _metresPerJoule
 use strict arg dissipatedEnergy
 if dissipatedEnergy<0 then raise syntax 88.900 array('non-negative dissipated energy')
 return _metresPerJoule*dissipatedEnergy

::class WheelTyreState public
::method init
 expose _radius _inertia _omega _wear _energy _wearLaw _rolling
 use strict arg radius,wheelInertia,rollingResistanceModel,wearLaw,angularVelocity=0
 if radius<=0 | wheelInertia<=0 then raise syntax 88.900 array('positive wheel radius and inertia')
 _radius=radius+0; _inertia=wheelInertia+0; _rolling=rollingResistanceModel; _wearLaw=wearLaw; _omega=angularVelocity+0; _wear=0; _energy=0
::method angularVelocity; expose _omega; return _omega
::method wearDepth; expose _wear; return _wear
::method dissipatedEnergy; expose _energy; return _energy
::method slipSpeed
 expose _radius _omega
 use strict arg groundSpeed
 return groundSpeed-_omega*_radius
::method step
 expose _radius _inertia _omega _wear _energy _wearLaw _rolling
 use strict arg dt,groundSpeed,normalLoad,frictionCoefficient
 if dt<=0 | normalLoad<0 | frictionCoefficient<0 then raise syntax 88.900 array('valid tyre step inputs')
 slip=self~slipSpeed(groundSpeed)
 rr=_rolling~force(normalLoad,groundSpeed)
 if abs(slip)<'0.000000000001' then friction=0
 else friction=sign(slip)*frictionCoefficient*normalLoad
 torque=friction*_radius
 _omega=_omega+(torque/_inertia)*dt
 power=abs(friction*slip)+abs(rr*groundSpeed)
 dE=power*dt; _energy=_energy+dE
 dw=_wearLaw~wearIncrement(dE); _wear=_wear+dw
 return .WheelTyreObservation~new(slip,friction,rr,power,dE,_energy,dw,_wear,_omega)

::class WheelTyreObservation public
::method init
 expose _slip _friction _rr _power _dE _energy _dw _wear _omega
 use strict arg slipSpeed,frictionForce,rollingResistance,dissipatedPower,energyIncrement,totalEnergy,wearIncrement,totalWear,angularVelocity
 _slip=slipSpeed; _friction=frictionForce; _rr=rollingResistance; _power=dissipatedPower; _dE=energyIncrement; _energy=totalEnergy; _dw=wearIncrement; _wear=totalWear; _omega=angularVelocity
::method slipSpeed; expose _slip; return _slip
::method frictionForce; expose _friction; return _friction
::method rollingResistance; expose _rr; return _rr
::method dissipatedPower; expose _power; return _power
::method energyIncrement; expose _dE; return _dE
::method totalEnergy; expose _energy; return _energy
::method wearIncrement; expose _dw; return _dw
::method totalWear; expose _wear; return _wear
::method angularVelocity; expose _omega; return _omega
