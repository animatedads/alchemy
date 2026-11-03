/* Physics World dev25: composition of longitudinal and lateral quasi-static
   ground-load solvers. Lateral geometry remains explicit per axle. */
::class AircraftCombinedGroundLoadModel public
::method init
 expose _long _noseLat _mainLat
 use strict arg longitudinalModel,noseLateralModel,mainLateralModel
 _long=longitudinalModel; _noseLat=noseLateralModel; _mainLat=mainLateralModel
::method resolve
 expose _long _noseLat _mainLat
 use strict arg mass,longitudinalAcceleration,lateralAcceleration,gravity=9.80665
 longitudinal=_long~resolve(mass,longitudinalAcceleration,gravity)
 nose=_noseLat~resolve(longitudinal~noseLoad,lateralAcceleration,gravity)
 main=_mainLat~resolve(longitudinal~mainLoad,lateralAcceleration,gravity)
 return .AircraftCombinedGroundLoadObservation~new(longitudinal,nose,main)
::class AircraftCombinedGroundLoadObservation public
::method init
 expose _long _nose _main
 use strict arg longitudinal,noseAxle,mainAxle
 _long=longitudinal; _nose=noseAxle; _main=mainAxle
::method longitudinal; expose _long; return _long
::method noseLeft; expose _nose; return _nose~leftLoad
::method noseRight; expose _nose; return _nose~rightLoad
::method mainLeft; expose _main; return _main~leftLoad
::method mainRight; expose _main; return _main~rightLoad
::method totalLoad
 expose _nose _main
 return _nose~leftLoad+_nose~rightLoad+_main~leftLoad+_main~rightLoad
::requires 'AircraftGroundLoadTransfer.cls'
::requires 'AircraftLateralLoadTransfer.cls'
