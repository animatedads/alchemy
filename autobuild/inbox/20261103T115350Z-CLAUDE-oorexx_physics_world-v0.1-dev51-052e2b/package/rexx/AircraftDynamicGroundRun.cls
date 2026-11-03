/* Physics World dev22: ground run with geometry-derived longitudinal axle loads.
   Main-gear left/right split is explicit pending lateral load-transfer physics. */
::class DynamicGroundTyreStation public
::method init
 expose _name _axle _share _tyre
 use strict arg name,axle,lateralShare,tyreState
 a=axle~string~upper
 if a<>'NOSE' & a<>'MAIN' then raise syntax 88.900 array('axle must be NOSE or MAIN')
 if lateralShare<0 | lateralShare>1 then raise syntax 88.900 array('station axle share must be within 0..1')
 _name=name; _axle=a; _share=lateralShare+0; _tyre=tyreState
::method name; expose _name; return _name
::method axle; expose _axle; return _axle
::method axleShare; expose _share; return _share
::method tyre; expose _tyre; return _tyre

::class DynamicAircraftGroundExperiment public
::method init
 expose _mass _speed _stations _loads _time _distance
 use strict arg aircraftMass,groundSpeed,stations,loadTransferModel,startTime=0
 if aircraftMass<=0 | groundSpeed<0 | stations~items=0 then raise syntax 88.900 array('valid aircraft ground experiment inputs')
 nose=0; main=0
 do s over stations
   if s~axle='NOSE' then nose=nose+s~axleShare
   else main=main+s~axleShare
 end
 if abs(nose-1)>.000000001 | abs(main-1)>.000000001 then raise syntax 88.900 array('station shares must sum to one within each axle group')
 _mass=aircraftMass+0; _speed=groundSpeed+0; _stations=stations; _loads=loadTransferModel
 _time=startTime+0; _distance=0
::method groundSpeed; expose _speed; return _speed
::method distance; expose _distance; return _distance
::method time; expose _time; return _time
::method step
 expose _mass _speed _stations _loads _time _distance
 use strict arg dt,frictionCoefficient,longitudinalAcceleration,gravity=9.80665
 if dt<=0 | frictionCoefficient<0 then raise syntax 88.900 array('valid dynamic ground step')
 loadObs=_loads~resolve(_mass,longitudinalAcceleration,gravity)
 stationObs=.array~new; resisting=0
 do s over _stations
   if s~axle='NOSE' then axleLoad=loadObs~noseLoad
   else axleLoad=loadObs~mainLoad
   normalLoad=axleLoad*s~axleShare
   t=s~tyre~step(dt,_speed,normalLoad,frictionCoefficient)
   resisting=resisting+abs(t~frictionForce)+abs(t~rollingResistance)
   stationObs~append(.DynamicGroundTyreObservation~new(s~name,s~axle,normalLoad,t))
 end
 oldSpeed=_speed
 /* The supplied acceleration is the aircraft longitudinal state authority for
    this step. Contact resistance remains separately reported evidence. */
 _speed=max(0,_speed+longitudinalAcceleration*dt)
 _distance=_distance+(oldSpeed+_speed)/2*dt
 _time=_time+dt
 return .DynamicAircraftGroundObservation~new(_time,_distance,_speed,longitudinalAcceleration,resisting,loadObs,stationObs)

::class DynamicGroundTyreObservation public
::method init
 expose _name _axle _load _tyre
 use strict arg name,axle,normalLoad,tyreObservation
 _name=name; _axle=axle; _load=normalLoad; _tyre=tyreObservation
::method name; expose _name; return _name
::method axle; expose _axle; return _axle
::method normalLoad; expose _load; return _load
::method tyre; expose _tyre; return _tyre

::class DynamicAircraftGroundObservation public
::method init
 expose _time _distance _speed _accel _resist _loads _stations
 use strict arg time,distance,groundSpeed,longitudinalAcceleration,resistingForce,loadObservation,stationObservations
 _time=time; _distance=distance; _speed=groundSpeed; _accel=longitudinalAcceleration
 _resist=resistingForce; _loads=loadObservation; _stations=stationObservations
::method time; expose _time; return _time
::method distance; expose _distance; return _distance
::method groundSpeed; expose _speed; return _speed
::method longitudinalAcceleration; expose _accel; return _accel
::method resistingForce; expose _resist; return _resist
::method loads; expose _loads; return _loads
::method stations; expose _stations; return _stations
::requires 'AircraftGroundLoadTransfer.cls'
::requires 'WheelTyreDynamics.cls'
