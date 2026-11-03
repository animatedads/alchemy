numeric digits 30
loads=.array~of(.StaticLateralMassElement~new('PORT',12020.4,2.2),.StaticLateralMassElement~new('STARBOARD',315,-2.2),.StaticLateralMassElement~new('FLUID-MASS-ONCE',25235,0))
base=.StaticLateralOffsetLoadModel~new(11)~resolve(loads,9.80665)
o=.AircraftFluidLateralLoadModel~new(11)~resolveMoment(base,-13522)
if o~totalLoad<>base~portLoad+base~starboardLoad then exit 1
if o~fluidRollMoment<>-13522 then exit 1
if o~portLoad>=base~portLoad then exit 1
if o~starboardLoad<=base~starboardLoad then exit 1
say 'PHYSICS AIRCRAFT FLUID LATERAL COMPOSITION: OK port=' o~portLoad 'starboard=' o~starboardLoad
::requires 'AircraftFluidLateralLoads.cls'
