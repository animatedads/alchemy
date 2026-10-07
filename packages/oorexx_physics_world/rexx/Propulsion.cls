/* Physics World dev18: reduced-order propulsion with explicit operating map authority. */
::class PropulsionOperatingPoint public
::method init
 expose _throttle _speed _rho _temp _pressure
 use strict arg throttle,flightSpeed,airDensity,temperature=.nil,pressure=.nil
 if throttle<0 | throttle>1 | flightSpeed<0 | airDensity<=0 then raise syntax 88.900 array('valid throttle, speed and density')
 _throttle=throttle+0; _speed=flightSpeed+0; _rho=airDensity+0; _temp=temperature; _pressure=pressure
::method throttle; expose _throttle; return _throttle
::method flightSpeed; expose _speed; return _speed
::method airDensity; expose _rho; return _rho
::method temperature; expose _temp; return _temp
::method pressure; expose _pressure; return _pressure

::class PropulsionMap public
::method evaluate; use strict arg operatingPoint; raise syntax 93.900 array('PropulsionMap~evaluate must be implemented')

::class LinearStaticThrustMap subclass PropulsionMap public
/* Qualification/reference map, not a real turbofan deck. */
::method init
 expose _staticThrust _fuelAtFull _referenceDensity
 use strict arg staticThrust,fuelMassFlowAtFull,referenceDensity=1.225
 if staticThrust<0 | fuelMassFlowAtFull<0 | referenceDensity<=0 then raise syntax 88.900 array('non-negative thrust/fuel and positive density')
 _staticThrust=staticThrust+0; _fuelAtFull=fuelMassFlowAtFull+0; _referenceDensity=referenceDensity+0
::method evaluate
 expose _staticThrust _fuelAtFull _referenceDensity
 use strict arg op
 densityRatio=op~airDensity/_referenceDensity
 d=.directory~new
 d['THRUST']=_staticThrust*op~throttle*densityRatio
 d['FUEL_MASS_FLOW']=_fuelAtFull*op~throttle
 return d

::class PropulsionUnit public
::method init
 expose _map _fuelUsed _time
 use strict arg propulsionMap,startTime=0
 _map=propulsionMap; _fuelUsed=0; _time=startTime+0
::method step
 expose _map _fuelUsed _time
 use strict arg dt,operatingPoint
 if dt<=0 then raise syntax 88.900 array('positive propulsion timestep')
 r=_map~evaluate(operatingPoint); dm=r['FUEL_MASS_FLOW']*dt
 if dm<0 then raise syntax 93.900 array('propulsion map returned negative fuel flow')
 _fuelUsed=_fuelUsed+dm; _time=_time+dt
 return .PropulsionObservation~new(_time,r['THRUST'],r['FUEL_MASS_FLOW'],dm,_fuelUsed)
::method fuelUsed; expose _fuelUsed; return _fuelUsed
::method time; expose _time; return _time

::class PropulsionObservation public
::method init
 expose _time _thrust _flow _increment _total
 use strict arg time,thrust,fuelMassFlow,fuelIncrement,totalFuel
 _time=time; _thrust=thrust; _flow=fuelMassFlow; _increment=fuelIncrement; _total=totalFuel
::method time; expose _time; return _time
::method thrust; expose _thrust; return _thrust
::method fuelMassFlow; expose _flow; return _flow
::method fuelIncrement; expose _increment; return _increment
::method totalFuel; expose _total; return _total
