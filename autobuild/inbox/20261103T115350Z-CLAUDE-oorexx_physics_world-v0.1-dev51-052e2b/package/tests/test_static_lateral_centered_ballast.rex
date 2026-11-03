numeric digits 30
a=.array~of(.StaticLateralMassElement~new('PORT',1000,2),.StaticLateralMassElement~new('CENTRE',1000,0))
m=.StaticLateralOffsetLoadModel~new(10)
o=m~resolve(a,10)
if o~rollMoment<>20000 | o~portLoad<>12000 | o~starboardLoad<>8000 then exit 1
say 'PHYSICS STATIC LATERAL CENTRED BALLAST: OK'
::requires 'AircraftStaticLateralLoads.cls'
