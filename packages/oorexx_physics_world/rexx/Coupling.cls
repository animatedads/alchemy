/* ooRexx Physics World v0.1-dev7
   Cross-domain physical mounting and optical probe helpers. */

::class PhysicalMount public
::method init
  expose _parent _localPose
  use strict arg parent,localPose=.nil
  if localPose==.nil then localPose=.PhysicalPose~identity(parent~pose~context)
  _parent=parent; _localPose=localPose
::method parent; expose _parent; return _parent
::method localPose; expose _localPose; return _localPose
::method context; return self~parent~pose~context
::method worldFromLocal
  return self~parent~pose~worldFromLocal * self~localPose~worldFromLocal
::method localFromWorld; return self~worldFromLocal~inverse
::method pointToWorld; use strict arg p; return self~worldFromLocal~transformPoint(p)
::method pointToLocal; use strict arg p; return self~localFromWorld~transformPoint(p)
::method vectorToWorld; use strict arg d; return self~worldFromLocal~transformDirection(d)
::method vectorToLocal; use strict arg d; return self~localFromWorld~transformDirection(d)
::method directionToWorld; use strict arg d; return self~vectorToWorld(d)~normalized
::method directionToLocal; use strict arg d; return self~vectorToLocal(d)~normalized
::method position
  ctx=self~context
  return self~pointToWorld(.MathVector3~new(0,0,0,ctx))
::method orientation
  return (self~parent~pose~orientation * self~localPose~orientation)~normalized

::class OpticalBeamReading public
::method init
  expose _transmission _trace _source _target
  use strict arg transmission,trace,sourcePoint,targetPoint
  _transmission=transmission; _trace=trace; _source=sourcePoint; _target=targetPoint
::method transmission; expose _transmission; return _transmission
::method trace; expose _trace; return _trace
::method sourcePoint; expose _source; return _source
::method targetPoint; expose _target; return _target
::method blocked; return self~transmission=0

::class OpticalBeamProbe public
::method init
  expose _world _sourcePose _sensor _wavelength _weight
  use strict arg world,sourcePose,sensorPose,width='0.01',height='0.01',wavelengthNm=555,weight=1,name='beam-sensor'
  _world=world; _sourcePose=sourcePose; _wavelength=wavelengthNm; _weight=weight
  _sensor=.OpticalSensor~new(name,.RectangleShape~new(width,height),sensorPose)
  world~addSensor(_sensor)
::method world; expose _world; return _world
::method sourcePose; expose _sourcePose; return _sourcePose
::method sensor; expose _sensor; return _sensor
::method wavelengthNm; expose _wavelength; return _wavelength
::method weight; expose _weight; return _weight
::method sample
  expose _world _sourcePose _sensor _wavelength _weight
  _sensor~reset
  source=_sourcePose~position
  target=_sensor~pose~position
  delta=target-source
  if delta~norm<'0.000000000001' then raise syntax 88.900 array('distinct beam source and sensor positions','coincident')
  ray=_world~ray(source,delta,_wavelength,_weight,source~context)
  trace=_world~trace(ray,24,'0.000000001')
  return .OpticalBeamReading~new(_sensor~received,trace,source,target)

::requires 'PhysicsWorld.cls'
