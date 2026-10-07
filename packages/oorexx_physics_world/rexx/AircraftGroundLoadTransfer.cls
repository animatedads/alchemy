/* Physics World dev21: quasi-static longitudinal landing-gear load transfer.
   Geometry and longitudinal acceleration are explicit inputs. No aircraft geometry
   or centre-of-mass position is inferred from catalogue identity. */
::class LongitudinalGearGeometry public
::method init
 expose _nose _main _height
 use strict arg noseX,mainX,centreOfMassHeight
 if mainX>=0 | noseX<=0 | centreOfMassHeight<0 then raise syntax 88.900 array('mainX<0, noseX>0 and non-negative COM height required')
 _nose=noseX+0; _main=mainX+0; _height=centreOfMassHeight+0
::method noseX; expose _nose; return _nose
::method mainX; expose _main; return _main
::method centreOfMassHeight; expose _height; return _height
::method wheelbase; expose _nose _main; return _nose-_main

::class LongitudinalLoadTransferModel public
::method init
 expose _geometry
 use strict arg geometry
 _geometry=geometry
::method resolve
 expose _geometry
 use strict arg mass,longitudinalAcceleration,gravity=9.80665
 if mass<=0 | gravity<=0 then raise syntax 88.900 array('positive mass and gravity')
 W=mass*gravity
 L=_geometry~wheelbase
 /* Moment equilibrium about the main gear. Positive acceleration is forward.
    Braking is negative, transferring normal load toward the nose gear. */
 nose=(W*(-_geometry~mainX)-mass*longitudinalAcceleration*_geometry~centreOfMassHeight)/L
 main=W-nose
 if nose<0 | main<0 then raise syntax 88.900 array('resolved gear load is negative; quasi-static contact assumption invalid')
 return .LongitudinalLoadObservation~new(nose,main,nose/W,main/W,longitudinalAcceleration)

::class LongitudinalLoadObservation public
::method init
 expose _nose _main _noseShare _mainShare _accel
 use strict arg noseLoad,mainLoad,noseShare,mainShare,longitudinalAcceleration
 _nose=noseLoad; _main=mainLoad; _noseShare=noseShare; _mainShare=mainShare; _accel=longitudinalAcceleration
::method noseLoad; expose _nose; return _nose
::method mainLoad; expose _main; return _main
::method noseShare; expose _noseShare; return _noseShare
::method mainShare; expose _mainShare; return _mainShare
::method longitudinalAcceleration; expose _accel; return _accel
