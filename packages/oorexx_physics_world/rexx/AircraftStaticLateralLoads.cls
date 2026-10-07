/* Physics World dev27: static lateral payload-offset equilibrium.
   Positive lateral offset is port/left. A centred mass contributes weight but
   no roll moment. This is distinct from acceleration-driven dev23 transfer. */
::class StaticLateralMassElement public
::method init
 expose _name _mass _offset
 use strict arg name,mass,lateralOffset
 if mass<0 then raise syntax 88.900 array('mass must be non-negative')
 _name=name;_mass=mass+0;_offset=lateralOffset+0
::method name; expose _name; return _name
::method mass; expose _mass; return _mass
::method lateralOffset; expose _offset; return _offset

::class StaticLateralOffsetLoadModel public
::method init
 expose _track
 use strict arg trackWidth
 if trackWidth<=0 then raise syntax 88.900 array('positive track width required')
 _track=trackWidth+0
::method resolve
 expose _track
 use strict arg massElements,gravity=9.80665
 if gravity<=0 | massElements~items=0 then raise syntax 88.900 array('positive gravity and at least one mass element required')
 totalMass=0; rollMoment=0
 do element over massElements
   totalMass=totalMass+element~mass
   rollMoment=rollMoment+element~mass*gravity*element~lateralOffset
 end
 totalLoad=totalMass*gravity
 port=totalLoad/2+rollMoment/_track
 starboard=totalLoad-port
 if port<0 | starboard<0 then raise syntax 88.900 array('negative gear reaction; assumed two-sided contact invalid')
 return .StaticLateralOffsetLoadObservation~new(totalMass,rollMoment,port,starboard)

::class StaticLateralOffsetLoadObservation public
::method init
 expose _mass _moment _port _starboard
 use strict arg totalMass,rollMoment,portLoad,starboardLoad
 _mass=totalMass;_moment=rollMoment;_port=portLoad;_starboard=starboardLoad
::method totalMass; expose _mass; return _mass
::method rollMoment; expose _moment; return _moment
::method portLoad; expose _port; return _port
::method starboardLoad; expose _starboard; return _starboard
