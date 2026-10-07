::class LongitudinalGroundAeroGeometry public
::method init
 expose _noseX _mainX
 use strict arg noseX,mainX
 if mainX>=0 | noseX<=0 | noseX<=mainX then raise syntax 88.900 array('main x < 0 < nose x required')
 _noseX=noseX+0; _mainX=mainX+0
::method noseX; expose _noseX; return _noseX
::method mainX; expose _mainX; return _mainX
::method wheelbase; expose _noseX _mainX; return _noseX-_mainX

::class LongitudinalGroundAerodynamicLoadModel public
::method init
 expose _geometry
 use strict arg geometry
 _geometry=geometry
::method resolve
 expose _geometry
 use strict arg mass,longitudinalAcceleration,upwardAerodynamicForce,pitchMoment,centreOfMassHeight,gravity=9.80665
 if mass<=0 | gravity<=0 | centreOfMassHeight<0 then raise syntax 88.900 array('valid mass, gravity and COM height required')
 total=mass*gravity-upwardAerodynamicForce
 if total<0 then raise syntax 88.900 array('aerodynamic lift exceeds weight; all-wheel ground equilibrium invalid')
 L=_geometry~wheelbase
 nose=(-_geometry~mainX*total - mass*longitudinalAcceleration*centreOfMassHeight - pitchMoment)/L
 main=total-nose
 if nose<0 | main<0 then raise syntax 88.900 array('resolved axle contact load negative; ground equilibrium invalid')
 return .LongitudinalGroundAerodynamicLoadObservation~new(nose,main,total,upwardAerodynamicForce,pitchMoment)
::class LongitudinalGroundAerodynamicLoadObservation public
::method init
 expose _nose _main _total _lift _moment
 use strict arg noseLoad,mainLoad,totalGroundLoad,upwardAerodynamicForce,pitchMoment
 _nose=noseLoad;_main=mainLoad;_total=totalGroundLoad;_lift=upwardAerodynamicForce;_moment=pitchMoment
::method noseLoad; expose _nose; return _nose
::method mainLoad; expose _main; return _main
::method totalGroundLoad; expose _total; return _total
::method upwardAerodynamicForce; expose _lift; return _lift
::method pitchMoment; expose _moment; return _moment
