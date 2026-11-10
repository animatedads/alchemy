numeric digits 30
loads=.array~of(.StaticLateralMassElement~new('AIRFRAME-PAYLOAD',10000,0),.StaticLateralMassElement~new('FLUID-MASS-ONCE',5000,0))
base=.StaticLateralOffsetLoadModel~new(10)~resolve(loads,10)
o=.AircraftFluidLateralLoadModel~new(10)~resolveMoment(base,0)
if o~totalLoad<>150000 | o~portLoad<>75000 | o~starboardLoad<>75000 then exit 1
say 'PHYSICS AIRCRAFT FLUID NO DOUBLE MASS: OK total=' o~totalLoad
::requires 'AircraftFluidLateralLoads.cls'
