a=.array~of(.StaticLateralMassElement~new('OFFSET',1000,6))
m=.StaticLateralOffsetLoadModel~new(10)
signal on syntax name bad
o=m~resolve(a,10)
exit 1
bad:
say 'PHYSICS STATIC LATERAL TIP FAIL-CLOSED: OK'
exit 0
::requires 'AircraftStaticLateralLoads.cls'
