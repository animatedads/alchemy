/* Physics World dev20: reduced-order multi-station aircraft ground/landing experiment.
   Load shares are explicit projections; no aircraft-specific geometry is invented. */
::class GroundGearStation public
::method init
 expose _name _gear _share
 use strict arg name,landingGearState,loadShare
 if loadShare<0 then raise syntax 88.900 array('non-negative gear load share')
 _name=name; _gear=landingGearState; _share=loadShare+0
::method name; expose _name; return _name
::method gear; expose _gear; return _gear
::method loadShare; expose _share; return _share

::class AircraftGroundExperiment public
::method init
 expose _mass _speed _stations _time _distance
 use strict arg aircraftMass,groundSpeed,stations,startTime=0
 if aircraftMass<=0 | groundSpeed<0 then raise syntax 88.900 array('positive aircraft mass and non-negative speed')
 if stations~items=0 then raise syntax 88.900 array('at least one gear station')
 total=0
 do s over stations; total=total+s~loadShare; end
 if abs(total-1)>.000000001 then raise syntax 88.900 array('gear load shares must sum to one')
 _mass=aircraftMass+0; _speed=groundSpeed+0; _stations=stations; _time=startTime+0; _distance=0
::method groundSpeed; expose _speed; return _speed
::method distance; expose _distance; return _distance
::method time; expose _time; return _time
::method step
 expose _mass _speed _stations _time _distance
 use strict arg dt,frictionCoefficient,gravity=9.80665
 if dt<=0 | frictionCoefficient<0 then raise syntax 88.900 array('valid ground experiment step')
 observations=.array~new; resisting=0
 do station over _stations
   /* Each station's supported mass/load authority is established at construction.
      The share is retained here for evidence and future load-transfer providers. */
   o=station~gear~step(dt,_speed,frictionCoefficient,gravity)
   observations~append(.GroundGearStationObservation~new(station~name,station~loadShare,o))
   resisting=resisting+abs(o~tyre~frictionForce)+abs(o~tyre~rollingResistance)
 end
 oldSpeed=_speed
 _speed=max(0,_speed-resisting/_mass*dt)
 _distance=_distance+(oldSpeed+_speed)/2*dt
 _time=_time+dt
 return .AircraftGroundObservation~new(_time,_distance,_speed,resisting,observations)

::class GroundGearStationObservation public
::method init
 expose _name _share _landing
 use strict arg name,loadShare,landingObservation
 _name=name; _share=loadShare; _landing=landingObservation
::method name; expose _name; return _name
::method loadShare; expose _share; return _share
::method landing; expose _landing; return _landing

::class AircraftGroundObservation public
::method init
 expose _time _distance _speed _force _stations
 use strict arg time,distance,groundSpeed,resistingForce,stationObservations
 _time=time; _distance=distance; _speed=groundSpeed; _force=resistingForce; _stations=stationObservations
::method time; expose _time; return _time
::method distance; expose _distance; return _distance
::method groundSpeed; expose _speed; return _speed
::method resistingForce; expose _force; return _force
::method stations; expose _stations; return _stations
::requires 'LandingGearDynamics.cls'
