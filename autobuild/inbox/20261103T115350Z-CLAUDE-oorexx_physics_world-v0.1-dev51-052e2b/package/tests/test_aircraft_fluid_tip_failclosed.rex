loads=.array~of(.StaticLateralMassElement~new('ALL',1000,0))
base=.StaticLateralOffsetLoadModel~new(10)~resolve(loads,10)
m=.AircraftFluidLateralLoadModel~new(10)
signal on syntax name bad
o=m~resolveMoment(base,60000)
exit 1
bad:
say 'PHYSICS AIRCRAFT FLUID TIP FAIL-CLOSED: OK'
exit 0
::requires 'AircraftFluidLateralLoads.cls'
