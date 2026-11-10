/* Physics World dev23: quasi-static left/right axle load transfer.
   y is positive aircraft-right. Positive lateral acceleration is rightward;
   inertial transfer increases left-side normal load. */
::class LateralAxleGeometry public
::method init
 expose _track _height
 use strict arg trackWidth,centreOfMassHeight
 if trackWidth<=0 | centreOfMassHeight<0 then raise syntax 88.900 array('positive track width and non-negative COM height')
 _track=trackWidth+0; _height=centreOfMassHeight+0
::method trackWidth; expose _track; return _track
::method centreOfMassHeight; expose _height; return _height

::class LateralAxleLoadTransferModel public
::method init
 expose _geometry
 use strict arg geometry
 _geometry=geometry
::method resolve
 expose _geometry
 use strict arg axleNormalLoad,lateralAcceleration,gravity=9.80665
 if axleNormalLoad<0 | gravity<=0 then raise syntax 88.900 array('non-negative axle load and positive gravity')
 supportedMass=axleNormalLoad/gravity
 transfer=supportedMass*lateralAcceleration*_geometry~centreOfMassHeight/_geometry~trackWidth
 left=axleNormalLoad/2+transfer; right=axleNormalLoad/2-transfer
 if left<0 | right<0 then raise syntax 88.900 array('resolved lateral tyre load is negative; quasi-static contact assumption invalid')
 return .LateralAxleLoadObservation~new(left,right,transfer,lateralAcceleration)

::class LateralAxleLoadObservation public
::method init
 expose _left _right _transfer _accel
 use strict arg leftLoad,rightLoad,loadTransfer,lateralAcceleration
 _left=leftLoad; _right=rightLoad; _transfer=loadTransfer; _accel=lateralAcceleration
::method leftLoad; expose _left; return _left
::method rightLoad; expose _right; return _right
::method loadTransfer; expose _transfer; return _transfer
::method lateralAcceleration; expose _accel; return _accel
