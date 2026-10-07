/* Physics World dev19: reduced-order landing-gear vertical energy and tyre coupling. */
::class LandingStrutModel public
::method force; use strict arg compression,compressionRate; raise syntax 93.900 array('LandingStrutModel~force must be implemented')
::method dampingPower; use strict arg compression,compressionRate; return 0
::class LinearLandingStrut subclass LandingStrutModel public
::method init
 expose _k _c _max
 use strict arg stiffness,damping,maxCompression
 if stiffness<0 | damping<0 | maxCompression<=0 then raise syntax 88.900 array('valid landing strut parameters')
 _k=stiffness+0; _c=damping+0; _max=maxCompression+0
::method force
 expose _k _c _max
 use strict arg compression,compressionRate
 if compression<0 then compression=0
 if compression>_max then compression=_max
 f=_k*compression+_c*compressionRate
 if f<0 then return 0
 return f
::method dampingPower
 expose _c
 use strict arg compression,compressionRate
 return _c*compressionRate*compressionRate
::method maxCompression; expose _max; return _max

::class LandingGearState public
::method init
 expose _mass _strut _tyre _compression _verticalVelocity _time _dampingEnergy _peakLoad
 use strict arg supportedMass,strutModel,tyreState,verticalVelocity,initialCompression=0,startTime=0
 if supportedMass<=0 | initialCompression<0 then raise syntax 88.900 array('positive supported mass and non-negative compression')
 _mass=supportedMass+0; _strut=strutModel; _tyre=tyreState; _compression=initialCompression+0; _verticalVelocity=verticalVelocity+0; _time=startTime+0; _dampingEnergy=0; _peakLoad=0
::method verticalKineticEnergy
 expose _mass _verticalVelocity
 return _mass*_verticalVelocity*_verticalVelocity/2
::method compression; expose _compression; return _compression
::method verticalVelocity; expose _verticalVelocity; return _verticalVelocity
::method peakLoad; expose _peakLoad; return _peakLoad
::method dampingEnergy; expose _dampingEnergy; return _dampingEnergy
::method step
 expose _mass _strut _tyre _compression _verticalVelocity _time _dampingEnergy _peakLoad
 use strict arg dt,groundSpeed,frictionCoefficient,gravity=9.80665
 if dt<=0 then raise syntax 88.900 array('positive landing timestep')
 /* Positive vertical velocity means downward compression velocity. */
 load=_strut~force(_compression,_verticalVelocity)
 if load>_peakLoad then _peakLoad=load
 accel=gravity-load/_mass
 oldV=_verticalVelocity
 _verticalVelocity=_verticalVelocity+accel*dt
 _compression=_compression+_verticalVelocity*dt
 if _compression<0 then _compression=0
 if _compression>_strut~maxCompression then _compression=_strut~maxCompression
 dampingPower=_strut~dampingPower(_compression,oldV)
 work=dampingPower*dt
 if work>0 then _dampingEnergy=_dampingEnergy+work
 tyreObs=_tyre~step(dt,groundSpeed,load,frictionCoefficient)
 _time=_time+dt
 return .LandingGearObservation~new(_time,_compression,_verticalVelocity,load,_peakLoad,work,_dampingEnergy,tyreObs)
::class LandingGearObservation public
::method init
 expose _time _compression _velocity _load _peak _work _energy _tyre
 use strict arg time,compression,verticalVelocity,normalLoad,peakLoad,strutWork,totalStrutWork,tyreObservation
 _time=time; _compression=compression; _velocity=verticalVelocity; _load=normalLoad; _peak=peakLoad; _work=strutWork; _energy=totalStrutWork; _tyre=tyreObservation
::method time; expose _time; return _time
::method compression; expose _compression; return _compression
::method verticalVelocity; expose _velocity; return _velocity
::method normalLoad; expose _load; return _load
::method peakLoad; expose _peak; return _peak
::method strutWork; expose _work; return _work
::method totalStrutWork; expose _energy; return _energy
::method tyre; expose _tyre; return _tyre
::requires 'WheelTyreDynamics.cls'
