/* ooRexx Physics World v0.1-dev3
   Acoustics solver over the same PhysicalWorld bodies, poses and medium regions.

   dev3 deliberately starts with coherent monochromatic pressure propagation,
   finite planar specular reflections and homogeneous-medium paths.  It does not
   disguise diffraction/reverberation/continuum acoustics behind alignment factors.
*/

::class AcousticAttenuationModel public
::method nepersPerMetre
  use strict arg frequencyHz
  return 0

::class ConstantAcousticAttenuationModel subclass AcousticAttenuationModel public
::method init
  expose _alpha
  use strict arg nepersPerMetre=0
  if nepersPerMetre<0 then raise syntax 88.900 array('non-negative acoustic attenuation',nepersPerMetre)
  _alpha=nepersPerMetre
::method nepersPerMetre
  expose _alpha
  use strict arg frequencyHz
  return _alpha

::class AcousticMedium public
::method init
  expose _name _density _soundSpeed _attenuation
  use strict arg name,densityKgM3,soundSpeedMps,attenuation=.nil
  if densityKgM3<=0 then raise syntax 88.900 array('positive acoustic density',densityKgM3)
  if soundSpeedMps<=0 then raise syntax 88.900 array('positive sound speed',soundSpeedMps)
  if attenuation==.nil then attenuation=.ConstantAcousticAttenuationModel~new(0)
  _name=name; _density=densityKgM3; _soundSpeed=soundSpeedMps; _attenuation=attenuation
::method name; expose _name; return _name
::method density; expose _density; return _density
::method soundSpeed; expose _soundSpeed; return _soundSpeed
::method impedance; return self~density*self~soundSpeed
::method wavelength
  use strict arg frequencyHz
  if frequencyHz<=0 then raise syntax 88.900 array('positive acoustic frequency',frequencyHz)
  return self~soundSpeed/frequencyHz
::method wavenumber
  use strict arg frequencyHz
  pi=4*RxCalcArcTan(1,30,'R')
  return 2*pi*frequencyHz/self~soundSpeed
::method propagationFactor
  expose _attenuation
  use strict arg frequencyHz,distance
  if distance<0 then raise syntax 88.900 array('non-negative acoustic distance',distance)
  alpha=_attenuation~nepersPerMetre(frequencyHz)
  if alpha=0 | distance=0 then return 1
  return RxCalcExp(-(alpha*distance),30)
::method air class
  /* Development reference state near 20 C.  Not a metrology atmosphere model. */
  return self~new('air','1.2041','343.2')
::method water class
  /* Development pure-water reference state near room temperature. */
  return self~new('water','998.2','1482')

::class AcousticInterface public
::method normalIncidence class
  use strict arg medium1,medium2
  z1=medium1~impedance; z2=medium2~impedance
  rp=(z2-z1)/(z2+z1)
  tp=2*z2/(z1+z2)
  ri=rp*rp
  ti=4*z1*z2/((z1+z2)*(z1+z2))
  d=.directory~new
  d['pressureReflection']=rp
  d['pressureTransmission']=tp
  d['intensityReflection']=ri
  d['intensityTransmission']=ti
  return d

::class AcousticPhasor public
::method init
  expose _real _imag
  use strict arg real=0,imag=0
  _real=real; _imag=imag
::method fromPolar class
  use strict arg magnitude,phaseRadians
  return self~new(magnitude*RxCalcCos(phaseRadians,30,'R'),magnitude*RxCalcSin(phaseRadians,30,'R'))
::method real; expose _real; return _real
::method imag; expose _imag; return _imag
::method '+'
  use strict arg other
  return .AcousticPhasor~new(self~real+other~real,self~imag+other~imag)
::method '-'
  use strict arg other
  return .AcousticPhasor~new(self~real-other~real,self~imag-other~imag)
::method '*'
  use strict arg scalar
  return .AcousticPhasor~new(self~real*scalar,self~imag*scalar)
::method magnitude
  return RxCalcSqrt(self~real*self~real+self~imag*self~imag)
::method phase
  x=self~real; y=self~imag
  if x=0 & y=0 then return 0
  pi=4*RxCalcArcTan(1,30,'R')
  if x>0 then return RxCalcArcTan(y/x,30,'R')
  if x<0 & y>=0 then return RxCalcArcTan(y/x,30,'R')+pi
  if x<0 & y<0 then return RxCalcArcTan(y/x,30,'R')-pi
  if y>0 then return pi/2
  return -pi/2

::class AcousticToneSource public
::method init
  expose _name _frequency _power _phase _pose _body _localPoint _mount _context
  use strict arg name,frequencyHz,acousticPowerW,pose=.nil,phaseRadians=0,body=.nil,localPoint=.nil,mount=.nil
  if frequencyHz<=0 then raise syntax 88.900 array('positive acoustic source frequency',frequencyHz)
  if acousticPowerW<0 then raise syntax 88.900 array('non-negative acoustic source power',acousticPowerW)
  if mount<>.nil then _context=mount~context
  else if body==.nil then do
    if pose==.nil then pose=.PhysicalPose~identity
    _context=pose~context
  end
  else do
    _context=body~pose~context
    if localPoint==.nil then localPoint=.MathVector3~new(0,0,0,_context)
  end
  _name=name; _frequency=frequencyHz; _power=acousticPowerW; _phase=phaseRadians
  _pose=pose; _body=body; _localPoint=localPoint; _mount=mount
::method onBody class
  use strict arg name,physicalBody,localPoint,frequencyHz,acousticPowerW,phaseRadians=0
  return self~new(name,frequencyHz,acousticPowerW,.nil,phaseRadians,physicalBody,localPoint)
::method onMount class
  use strict arg name,mount,frequencyHz,acousticPowerW,phaseRadians=0
  return self~new(name,frequencyHz,acousticPowerW,.nil,phaseRadians,.nil,.nil,mount)
::method name; expose _name; return _name
::method frequencyHz; expose _frequency; return _frequency
::method acousticPowerW; expose _power; return _power
::method phaseRadians; expose _phase; return _phase
::method body; expose _body; return _body
::method mount; expose _mount; return _mount
::method position
  expose _mount _body _localPoint _pose
  if _mount<>.nil then return _mount~position
  if _body==.nil then return _pose~position
  return _body~pose~pointToWorld(_localPoint)

::class AcousticMicrophone public
::method init
  expose _name _pose _body _localPoint _mount _referencePressure _readings _context
  use strict arg name,pose=.nil,referencePressurePa='0.00002',body=.nil,localPoint=.nil,mount=.nil
  if referencePressurePa<=0 then raise syntax 88.900 array('positive acoustic reference pressure',referencePressurePa)
  if mount<>.nil then _context=mount~context
  else if body==.nil then do
    if pose==.nil then pose=.PhysicalPose~identity
    _context=pose~context
  end
  else do
    _context=body~pose~context
    if localPoint==.nil then localPoint=.MathVector3~new(0,0,0,_context)
  end
  _name=name; _pose=pose; _body=body; _localPoint=localPoint; _mount=mount; _referencePressure=referencePressurePa
  _readings=.directory~new
::method onBody class
  use strict arg name,physicalBody,localPoint,referencePressurePa='0.00002'
  return self~new(name,.nil,referencePressurePa,physicalBody,localPoint)
::method onMount class
  use strict arg name,mount,referencePressurePa='0.00002'
  return self~new(name,.nil,referencePressurePa,.nil,.nil,mount)
::method name; expose _name; return _name
::method referencePressure; expose _referencePressure; return _referencePressure
::method mount; expose _mount; return _mount
::method position
  expose _mount _body _localPoint _pose
  if _mount<>.nil then return _mount~position
  if _body==.nil then return _pose~position
  return _body~pose~pointToWorld(_localPoint)
::method observe
  expose _readings
  use strict arg frequencyHz,phasor,contributions
  r=.AcousticReading~new(frequencyHz,phasor,self~referencePressure,contributions)
  _readings[frequencyHz]=r
  return r
::method readingAt
  expose _readings
  use strict arg frequencyHz
  if _readings~hasIndex(frequencyHz) then return _readings[frequencyHz]
  return .nil
::method reset; expose _readings; _readings=.directory~new

::class AcousticPathContribution public
::method init
  expose _source _kind _distance _delay _medium _phasor _point
  use strict arg source,kind,distance,delay,medium,phasor,interactionPoint=.nil
  _source=source; _kind=kind~upper; _distance=distance; _delay=delay; _medium=medium; _phasor=phasor; _point=interactionPoint
::method source; expose _source; return _source
::method kind; expose _kind; return _kind
::method distance; expose _distance; return _distance
::method delay; expose _delay; return _delay
::method medium; expose _medium; return _medium
::method phasor; expose _phasor; return _phasor
::method interactionPoint; expose _point; return _point

::class AcousticReading public
::method init
  expose _frequency _phasor _referencePressure _contributions
  use strict arg frequencyHz,phasor,referencePressure,contributions=.nil
  if contributions==.nil then contributions=.array~new
  _frequency=frequencyHz; _phasor=phasor; _referencePressure=referencePressure; _contributions=contributions
::method frequencyHz; expose _frequency; return _frequency
::method phasor; expose _phasor; return _phasor
::method pressureRms; return self~phasor~magnitude
::method referencePressure; expose _referencePressure; return _referencePressure
::method contributions; expose _contributions; return _contributions~copy
::method splDb
  p=self~pressureRms
  if p<=0 then return .nil
  return 20*RxCalcLog10(p/self~referencePressure,30)

::class AcousticSurfaceMaterial public
::method init
  expose _name _reflection _transmission
  use strict arg name,pressureReflection=0,pressureTransmission=0
  if abs(pressureReflection)>1 then raise syntax 88.900 array('acoustic pressure reflection amplitude in [-1,1]',pressureReflection)
  _name=name; _reflection=pressureReflection; _transmission=pressureTransmission
::method name; expose _name; return _name
::method pressureReflection; expose _reflection; return _reflection
::method pressureTransmission; expose _transmission; return _transmission
::method rigid class; return self~new('rigid',1,0)
::method pressureRelease class; return self~new('pressure-release',-1,0)
::method anechoic class; return self~new('anechoic',0,0)
::method transparent class; return self~new('transparent',0,1)

::class AcousticSurface public
::method init
  expose _body _material
  use strict arg physicalBody,material
  _body=physicalBody; _material=material
::method body; expose _body; return _body
::method material; expose _material; return _material
::method planePoint
  ctx=self~body~pose~context
  return self~body~pose~pointToWorld(.MathVector3~new(0,0,0,ctx))
::method planeNormal
  ctx=self~body~pose~context
  return self~body~pose~directionToWorld(.MathVector3~new(0,0,1,ctx))
::method segmentHit
  use strict arg a,b
  delta=b-a; length=delta~norm
  if length<'0.000000000001' then return .nil
  direction=delta*(1/length)
  body=self~body
  localOrigin=body~pose~pointToLocal(a)
  localDirection=body~pose~directionToLocal(direction)
  ray=.MathRay3D~new(localOrigin,localDirection,a~context)
  h=body~shape~intersect(ray)
  if h==.nil then return .nil
  wp=body~pose~pointToWorld(h~point)
  distance=(wp-a)~norm
  if distance>='0.00000001' & distance<length-'0.00000001' then return .ShapeHit~new(distance,wp,body~pose~directionToWorld(h~normal))
  return .nil
::method reflectionPoint
  use strict arg sourcePoint,receiverPoint
  body=self~body
  shape=body~shape
  isRectangle=shape~isA(.RectangleShape)
  if isRectangle=.false then return .nil
  p0=self~planePoint; n=self~planeNormal
  image=sourcePoint-n*(2*(sourcePoint-p0)~dot(n))
  line=receiverPoint-image
  denom=line~dot(n)
  if abs(denom)<'0.000000000001' then return .nil
  t=(p0-image)~dot(n)/denom
  if t<=0 | t>=1 then return .nil
  q=image+line*t
  lp=body~pose~pointToLocal(q)
  if abs(lp~x)>shape~width/2 | abs(lp~y)>shape~height/2 then return .nil
  return q

::class AcousticSolver public
::method init
  expose _world _sources _microphones _surfaces
  use strict arg physicalWorld
  _world=physicalWorld; _sources=.array~new; _microphones=.array~new; _surfaces=.array~new
  if _world~ambientAcoustic==.nil then _world~ambientAcoustic=.AcousticMedium~air
::method world; expose _world; return _world
::method sources; expose _sources; return _sources~copy
::method microphones; expose _microphones; return _microphones~copy
::method surfaces; expose _surfaces; return _surfaces~copy
::method addSource; expose _sources; use strict arg source; _sources~append(source); return source
::method addMicrophone; expose _microphones; use strict arg microphone; _microphones~append(microphone); return microphone
::method addSurface; expose _surfaces; use strict arg surface; _surfaces~append(surface); return surface
::method mediumForPath
  use strict arg a,b
  ma=self~world~acousticMediumAt(a); mb=self~world~acousticMediumAt(b)
  if ma==.nil then ma=self~world~ambientAcoustic
  if mb==.nil then mb=self~world~ambientAcoustic
  if ma==.nil | mb==.nil then raise syntax 88.900 array('acoustic medium for path','none')
  if ma~name<>mb~name then raise syntax 93.900 array('dev3 acoustic propagation across a medium boundary is not yet implemented')
  /* Fail closed if the segment geometrically crosses a differently-valued acoustic region. */
  do body over self~world~bodies
    isRegion=body~isA(.PhysicalMediumRegion)
    if isRegion=.false then iterate
    candidate=body~acousticMedium
    if candidate==.nil | candidate~name=ma~name then iterate
    delta=b-a; length=delta~norm
    if length<'0.000000000001' then iterate
    localOrigin=body~pose~pointToLocal(a)
    localDirection=body~pose~directionToLocal(delta*(1/length))
    h=body~shape~intersect(.MathRay3D~new(localOrigin,localDirection,a~context))
    if h<>.nil then do
      wp=body~pose~pointToWorld(h~point)
      d=(wp-a)~norm
      if d<length-'0.00000001' then raise syntax 93.900 array('dev3 acoustic propagation through mixed media is not yet implemented')
    end
  end
  return ma
::method pathSurfaceTransmission
  expose _surfaces
  use strict arg a,b,excludeSurface=.nil
  coefficient=1
  do surface over _surfaces
    if excludeSurface<>.nil then if surface==excludeSurface then iterate
    if surface~segmentHit(a,b)<>.nil then coefficient=coefficient*surface~material~pressureTransmission
  end
  return coefficient
::method pressureForPath
  use strict arg source,distance,medium,coefficient=1
  if distance<='0.000000000001' then raise syntax 88.900 array('non-zero source/listener separation',distance)
  pi=4*RxCalcArcTan(1,30,'R')
  intensity=source~acousticPowerW/(4*pi*distance*distance)
  magnitude=RxCalcSqrt(intensity*medium~impedance)*medium~propagationFactor(source~frequencyHz,distance)
  phase=source~phaseRadians-medium~wavenumber(source~frequencyHz)*distance
  return .AcousticPhasor~fromPolar(magnitude,phase)*coefficient
::method solveTone
  expose _sources _microphones _surfaces
  use strict arg frequencyHz
  do microphone over _microphones
    total=.AcousticPhasor~new(0,0)
    contributions=.array~new
    do source over _sources
      if source~frequencyHz<>frequencyHz then iterate
      a=source~position; b=microphone~position
      medium=self~mediumForPath(a,b)
      directDistance=(b-a)~norm
      directCoeff=self~pathSurfaceTransmission(a,b)
      if directCoeff<>0 then do
        p=self~pressureForPath(source,directDistance,medium,directCoeff)
        total=total+p
        contributions~append(.AcousticPathContribution~new(source,'DIRECT',directDistance,directDistance/medium~soundSpeed,medium,p))
      end
      do surface over _surfaces
        rc=surface~material~pressureReflection
        if rc=0 then iterate
        q=surface~reflectionPoint(a,b)
        if q==.nil then iterate
        medium1=self~mediumForPath(a,q)
        medium2=self~mediumForPath(q,b)
        if medium1~name<>medium2~name then raise syntax 93.900 array('dev3 reflected acoustic path across unlike media is not yet implemented')
        coeff=rc*self~pathSurfaceTransmission(a,q,surface)*self~pathSurfaceTransmission(q,b,surface)
        if coeff=0 then iterate
        distance=(q-a)~norm+(b-q)~norm
        p=self~pressureForPath(source,distance,medium1,coeff)
        total=total+p
        contributions~append(.AcousticPathContribution~new(source,'REFLECTION',distance,distance/medium1~soundSpeed,medium1,p,q))
      end
    end
    microphone~observe(frequencyHz,total,contributions)
  end
::method solve
  expose _sources
  frequencies=.directory~new
  do source over _sources; frequencies[source~frequencyHz]=.true; end
  do frequency over frequencies~allIndexes; self~solveTone(frequency); end

::requires 'Coupling.cls'
::requires 'rxmath' LIBRARY
