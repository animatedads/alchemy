numeric digits 30
loads=.array~new
loads~append(.StaticLateralMassElement~new('PORT-NFL',12020,2.2))
loads~append(.StaticLateralMassElement~new('STARBOARD-PERFORMERS',315,-2.2))
loads~append(.StaticLateralMassElement~new('CENTRED-GATORADE',50470,0))
m=.StaticLateralOffsetLoadModel~new(11)
o=m~resolve(loads,9.80665)
if o~totalMass<>62805 then exit 1
if abs(o~rollMoment-252531.04415)<0.001 then nop; else exit 1
if o~portLoad<=o~starboardLoad then exit 1
if o~starboardLoad<=0 then exit 1
say 'PHYSICS STATIC LATERAL GATORADE: OK mass=' o~totalMass 'moment=' o~rollMoment 'portN=' o~portLoad 'starboardN=' o~starboardLoad
::requires 'AircraftStaticLateralLoads.cls'
