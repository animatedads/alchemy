/* AcousticMovingVehicle.cls
   Moving-source / moving-reflector acoustic primitives for Physics World.
   No F11-specific localisation semantics live in this package. */

::class AcousticLevelMath public
::method referencePressure class; return '0.00002'
::method pressureForSpl class
  use strict arg dbSpl
  return self~referencePressure * RxCalcExp(((dbSpl+0)/20)*RxCalcLog(10,30),30)
::method splForPressure class
  use strict arg pressurePa
  if pressurePa<=0 then return .nil
  return 20*RxCalcLog10(pressurePa/self~referencePressure,30)
::method acousticPowerForSplAt1m class
  use strict arg dbSpl,medium
  p=self~pressureForSpl(dbSpl)
  pi=4*RxCalcArcTan(1,30,'R')
  return 4*pi*p*p/medium~impedance
::method componentSpl class
  use strict arg totalDb,powerFraction
  if powerFraction<=0 | powerFraction>1 then raise syntax 88.900 array('vehicle acoustic power fraction in (0,1]',powerFraction)
  return totalDb + 10*RxCalcLog10(powerFraction,30)
::method energeticTotalDb class
  use strict arg dbValues
  sum=0
  do d over dbValues
    if d<>.nil then sum=sum+RxCalcExp(((d+0)/10)*RxCalcLog(10,30),30)
  end
  if sum<=0 then return .nil
  return 10*RxCalcLog10(sum,30)

::class AcousticVehicleNoiseComponent public
::method init
  expose _name _frequency _fraction _spl
  use strict arg name,frequencyHz,powerFraction,totalSplDb
  _name=name;_frequency=frequencyHz+0;_fraction=powerFraction+0
  _spl=.AcousticLevelMath~componentSpl(totalSplDb,_fraction)
::method name; expose _name; return _name
::method frequencyHz; expose _frequency; return _frequency
::method powerFraction; expose _fraction; return _fraction
::method sourceSplDb; expose _spl; return _spl

::class AcousticVehicleNoiseSpectrum public
::method init
  expose _total _components
  use strict arg totalSplDb='78'
  _total=totalSplDb+0;_components=.array~new
  _components~append(.AcousticVehicleNoiseComponent~new('LOW',125,'0.30',_total))
  _components~append(.AcousticVehicleNoiseComponent~new('MID',1000,'0.60',_total))
  _components~append(.AcousticVehicleNoiseComponent~new('HIGH',4000,'0.10',_total))
::method totalSplDb; expose _total; return _total
::method components; expose _components; return _components~copy
::method emissionSpectrum
  expose _components
  use strict arg medium
  e=.AcousticEmissionSpectrum~new
  do c over _components
    w=.AcousticLevelMath~acousticPowerForSplAt1m(c~sourceSplDb,medium)
    e~addBand(.AcousticEmissionBand~new(c~frequencyHz,w))
  end
  return e
::method validate
  expose _components _total
  fraction=0; levels=.array~new
  do c over _components;fraction=fraction+c~powerFraction;levels~append(c~sourceSplDb);end
  if abs(fraction-1)>'0.000000001' then return .false
  return abs(.AcousticLevelMath~energeticTotalDb(levels)-_total)<'0.000001'

::class AcousticMovingVehicle public
::method init
  expose _origin _velocity _length _height _sourceHeight _ctx _name
  use strict arg name,origin,velocity,lengthM='4',heightM='1.5',sourceHeightM='0.5'
  _name=name;_origin=origin;_velocity=velocity;_length=lengthM+0;_height=heightM+0;_sourceHeight=sourceHeightM+0;_ctx=origin~context
  if _length<=0 | _height<=0 | _sourceHeight<0 | _sourceHeight>_height then raise syntax 88.900 array('valid moving vehicle dimensions')
::method name; expose _name; return _name
::method origin; expose _origin; return _origin
::method velocity; expose _velocity; return _velocity
::method speed; expose _velocity; return _velocity~norm
::method length; expose _length; return _length
::method height; expose _height; return _height
::method sourceHeight; expose _sourceHeight; return _sourceHeight
::method centerAt
  expose _origin _velocity
  use strict arg timeSeconds
  return _origin + (_velocity*(timeSeconds+0))
::method sourcePositionAt
  expose _sourceHeight _ctx
  use strict arg timeSeconds
  c=self~centerAt(timeSeconds)
  return .MathVector3~new(c~x,c~y,_sourceHeight,_ctx)
::method timeAtX
  expose _origin _velocity
  use strict arg x
  if abs(_velocity~x)<'0.000000001' then raise syntax 88.900 array('vehicle trajectory requires non-zero X velocity')
  return ((x+0)-_origin~x)/_velocity~x
::method timeAtCenter
  expose _origin _velocity
  use strict arg point
  vv=_velocity~dot(_velocity)
  if vv<'0.000000000001' then raise syntax 88.900 array('vehicle trajectory requires non-zero velocity')
  return (point-_origin)~dot(_velocity)/vv
::method centerExtentAt
  expose _length _ctx
  use strict arg timeSeconds
  c=self~centerAt(timeSeconds);v=self~velocity
  if v~norm<'0.000000001' then u=.MathVector3~new(1,0,0,_ctx);else u=v~normalized
  half=_length/2
  d=.directory~new
  d['CENTER']=c;d['FRONT']=c+(u*half);d['REAR']=c-(u*half)
  return d
::method roadSidePanelAt
  expose _length _height _ctx
  use strict arg timeSeconds
  c=self~centerAt(timeSeconds);v=self~velocity
  if v~norm<'0.000000001' then do
    ux=1;uy=0
  end
  else do
    u=v~normalized;ux=u~x;uy=u~y
  end
  half=_length/2
  a=.MathVector3~new(c~x-half*ux,c~y-half*uy,0,_ctx)
  b=.MathVector3~new(c~x+half*ux,c~y+half*uy,0,_ctx)
  return .AcousticVerticalPanel~new(a,b,0,_height)

::class AcousticDoppler public
/* radial velocity is positive when source/reflector moves toward receiver */
::method movingSourceObserved class
  use strict arg emittedHz,soundSpeed,sourceVelocity,sourcePoint,receiverPoint
  ray=receiverPoint-sourcePoint
  if ray~norm<'0.000000001' then return emittedHz
  radial=sourceVelocity~dot(ray~normalized)
  if abs(radial)>=soundSpeed then raise syntax 88.900 array('subsonic acoustic source radial velocity',radial)
  return emittedHz*soundSpeed/(soundSpeed-radial)
::method movingReflectionObserved class
  use strict arg emittedHz,soundSpeed,reflectorVelocity,sourcePoint,reflectionPoint,receiverPoint
  incoming=reflectionPoint-sourcePoint;outgoing=receiverPoint-reflectionPoint
  if incoming~norm<'0.000000001' | outgoing~norm<'0.000000001' then return emittedHz
  /* Moving receiver (reflector) on incident leg, then moving source on outgoing leg. */
  vin=reflectorVelocity~dot(incoming~normalized)
  vout=reflectorVelocity~dot(outgoing~normalized)
  if abs(vin)>=soundSpeed | abs(vout)>=soundSpeed then raise syntax 88.900 array('subsonic moving reflector radial velocity')
  inFrame=emittedHz*(soundSpeed-vin)/soundSpeed
  return inFrame*soundSpeed/(soundSpeed-vout)

::class AcousticObservationMath public
::method arrivalBandSpl class
  use strict arg arrival,frequencyHz
  p=arrival~phasorAt(frequencyHz)~magnitude
  return .AcousticLevelMath~splForPressure(p)
::method receiverBandPressure class
  use strict arg response,frequencyHz
  /* Energy-style RMS aggregation is intentional for separately delayed arrivals. */
  sum=0
  do a over response~arrivals
    p=a~phasorAt(frequencyHz)~magnitude
    sum=sum+p*p
  end
  return RxCalcSqrt(sum)
::method receiverBandSpl class
  use strict arg response,frequencyHz
  return .AcousticLevelMath~splForPressure(self~receiverBandPressure(response,frequencyHz))
::method receiverTotalSpl class
  use strict arg response,frequencies
  levels=.array~new
  do f over frequencies;levels~append(self~receiverBandSpl(response,f));end
  return .AcousticLevelMath~energeticTotalDb(levels)

::requires 'AcousticImpulseResponse.cls'
