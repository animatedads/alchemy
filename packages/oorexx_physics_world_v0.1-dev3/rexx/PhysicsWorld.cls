/* ooRexx Physics World v0.1-dev3
   Geometric/material world substrate using ooRexx Maths v0.8 3D objects.
   Public API is deliberately object-oriented: geometry + material + pose + world.
*/

::class PhysicsDimension subclass UnitDimension public
/* Compatibility name retained for Physics callers. UnitDimension is authoritative. */

::class PhysicsUnit subclass UnitDefinition public
/* Compatibility name retained for Physics callers. UnitDefinition is authoritative. */

::class PhysicsQuantity subclass UnitQuantity public
/* Compatibility facade. Arithmetic intentionally returns UnitQuantity objects. */
::method fromSI class
  use strict arg value,dimension,displayUnit=.nil
  return .UnitQuantity~fromCanonical(value,dimension,displayUnit)

::class SI public
/* Compatibility catalogue over the independent ooRexx Units library. */
::method one class; return .Units~one
::method metre class; return .Units~metre
::method centimetre class; return .Units~centimetre
::method millimetre class; return .Units~millimetre
::method nanometre class; return .Units~nanometre
::method kilogram class; return .Units~kilogram
::method gram class; return .Units~gram
::method second class; return .Units~second
::method metrePerSecond class; return .Units~metrePerSecond
::method metrePerSecondSquared class; return .Units~metrePerSecondSquared
::method newton class; return .Units~newton
::method newtonSecond class; return .Units~newtonSecond
::method joule class; return .Units~joule
::method radian class; return .Units~radian
::method radianPerSecond class
  d=.UnitDimension~time~power(-1)
  return .UnitDefinition~new('radian per second','rad/s',1,d,0,'ANGULAR_RATE')
::method candela class; return .Units~candela
::method lumen class; return .Units~lumen
::method lux class; return .Units~lux
::method watt class; return .Units~watt
::method hertz class; return .Units~hertz
::method pascal class; return .Units~pascal
::method microPascal class
  return .UnitDefinition~new('micropascal','uPa','0.000001',.Units~pascal~dimension,0,'PRESSURE')
::method kilogramPerCubicMetre class
  d=.UnitDimension~mass/.UnitDimension~length~power(3)
  return .UnitDefinition~new('kilogram per cubic metre','kg/m^3',1,d,0,'DENSITY')
::method pascalSecondPerMetre class
  d=.UnitDimension~mass/.UnitDimension~length~power(2)/.UnitDimension~time
  return .UnitDefinition~new('pascal second per metre','Pa*s/m',1,d,0,'ACOUSTIC_IMPEDANCE')
::method wattPerSquareMetre class
  d=.UnitDimension~mass/.UnitDimension~time~power(3)
  return .UnitDefinition~new('watt per square metre','W/m^2',1,d,0,'INTENSITY')

::class PhysicalPose public
::method init
  expose _position _orientation _context
  use strict arg position=.nil,orientation=.nil,context=.nil
  if context==.nil then context=.Maths~defaultContext
  if position==.nil then position=.MathVector3~new(0,0,0,context)
  if orientation==.nil then orientation=.MathQuaternion~new(1,0,0,0,context)
  _position=position; _orientation=orientation~normalized; _context=context
::method position; expose _position; return _position
::method orientation; expose _orientation; return _orientation
::method context; expose _context; return _context
::method worldFromLocal
  return .MathTransform3D~translation(self~position~x,self~position~y,self~position~z,self~context) * -
         .MathTransform3D~rotation(self~orientation,self~context)
::method localFromWorld; return self~worldFromLocal~inverse
::method pointToWorld; use strict arg p; return self~worldFromLocal~transformPoint(p)
::method pointToLocal; use strict arg p; return self~localFromWorld~transformPoint(p)
::method vectorToWorld; use strict arg d; return self~worldFromLocal~transformDirection(d)
::method vectorToLocal; use strict arg d; return self~localFromWorld~transformDirection(d)
::method directionToWorld; use strict arg d; return self~vectorToWorld(d)~normalized
::method directionToLocal; use strict arg d; return self~vectorToLocal(d)~normalized
::method identity class
  use strict arg context=.nil
  return self~new(.nil,.nil,context)

::class OpticalIndexModel public
::method index
  use strict arg wavelengthNm
  raise syntax 93.900 array('OpticalIndexModel~index must be implemented')

::class ConstantIndexModel subclass OpticalIndexModel public
::method init; expose _n; use strict arg value; _n=value
::method index; expose _n; use strict arg wavelengthNm; return _n

::class CauchyIndexModel subclass OpticalIndexModel public
::method init
  expose _a _b _c
  use strict arg a,b=0,c=0
  _a=a; _b=b; _c=c
::method index
  expose _a _b _c
  use strict arg wavelengthNm
  numeric digits 40
  um=wavelengthNm/1000
  return _a + _b/(um*um) + _c/(um*um*um*um)

::class OpticalMedium public
::method init
  expose _name _indexModel
  use strict arg name,indexModel
  _name=name; _indexModel=indexModel
::method name; expose _name; return _name
::method refractiveIndex; expose _indexModel; use strict arg wavelengthNm; return _indexModel~index(wavelengthNm)
::method vacuum class; return self~new('vacuum',.ConstantIndexModel~new(1))
::method air class; return self~new('air',.ConstantIndexModel~new('1.000277'))
::method water class; return self~new('water',.ConstantIndexModel~new('1.333'))
::method bk7Approx class
  /* Development approximation for visible-light geometry, not metrology data. */
  return self~new('BK7-approx',.CauchyIndexModel~new('1.5046','0.00420',0))

::class OpticalMaterial public
::method init
  expose _name _kind _medium _reflectivity
  use strict arg name,kind,medium=.nil,reflectivity=0
  _name=name; _kind=kind~upper; _medium=medium; _reflectivity=reflectivity
::method name; expose _name; return _name
::method kind; expose _kind; return _kind
::method medium; expose _medium; return _medium
::method reflectivity; expose _reflectivity; return _reflectivity
::method dielectric class
  use strict arg name,medium
  return self~new(name,'DIELECTRIC',medium,0)
::method mirror class
  use strict arg name='ideal-mirror',reflectivity=1
  return self~new(name,'MIRROR',.nil,reflectivity)
::method absorber class
  use strict arg name='ideal-absorber'
  return self~new(name,'ABSORBER',.nil,0)

::class ShapeHit public
::method init
  expose _distance _point _normal
  use strict arg distance,point,normal
  _distance=distance; _point=point; _normal=normal~normalized
::method distance; expose _distance; return _distance
::method point; expose _point; return _point
::method normal; expose _normal; return _normal

::class PhysicalShape public
::method intersect
  use strict arg ray
  raise syntax 93.900 array('PhysicalShape~intersect must be implemented')
::method contains
  use strict arg point
  return .false

::class SphereShape subclass PhysicalShape public
::method init; expose _radius; use strict arg radius; _radius=radius
::method radius; expose _radius; return _radius
::method contains
  expose _radius
  use strict arg point
  return point~dot(point)<=_radius*_radius
::method intersect
  expose _radius
  use strict arg ray
  o=ray~origin; d=ray~direction
  b=2*(o~dot(d)); c=o~dot(o)-_radius*_radius
  disc=b*b-4*c
  if disc<0 then return .nil
  root=RxCalcSqrt(disc)
  t1=(-b-root)/2; t2=(-b+root)/2
  eps='0.000000001'
  if t1>eps then t=t1
  else if t2>eps then t=t2
  else return .nil
  p=ray~pointAt(t)
  return .ShapeHit~new(t,p,p~normalized)

::class RectangleShape subclass PhysicalShape public
::method init
  expose _width _height
  use strict arg width,height
  _width=width; _height=height
::method width; expose _width; return _width
::method height; expose _height; return _height
::method intersect
  expose _width _height
  use strict arg ray
  dz=ray~direction~z
  if abs(dz)<'0.000000000001' then return .nil
  t=-ray~origin~z/dz
  if t<='0.000000001' then return .nil
  p=ray~pointAt(t)
  if abs(p~x)>_width/2 | abs(p~y)>_height/2 then return .nil
  if dz<0 then n=.MathVector3~new(0,0,1,ray~context)
  else n=.MathVector3~new(0,0,-1,ray~context)
  return .ShapeHit~new(t,p,n)

::class ParaboloidShape subclass PhysicalShape public
::method init
  expose _focalLength _apertureRadius
  use strict arg focalLength,apertureDiameter
  if focalLength<=0 | apertureDiameter<=0 then raise syntax 88.900 array('positive paraboloid focal length and aperture',focalLength'/'apertureDiameter)
  _focalLength=focalLength; _apertureRadius=apertureDiameter/2
::method focalLength; expose _focalLength; return _focalLength
::method apertureRadius; expose _apertureRadius; return _apertureRadius
::method intersect
  expose _focalLength _apertureRadius
  use strict arg ray
  o=ray~origin; d=ray~direction; f=_focalLength
  a=d~x*d~x+d~y*d~y
  b=2*(o~x*d~x+o~y*d~y)-4*f*d~z
  c=o~x*o~x+o~y*o~y-4*f*o~z
  eps='0.000000001'
  candidates=.array~new
  if abs(a)<eps then do
    if abs(b)<eps then return .nil
    t=-c/b
    if t>eps then candidates~append(t)
  end
  else do
    disc=b*b-4*a*c
    if disc<0 then return .nil
    root=RxCalcSqrt(disc)
    t1=(-b-root)/(2*a); t2=(-b+root)/(2*a)
    if t1>eps then candidates~append(t1)
    if t2>eps then candidates~append(t2)
  end
  best=.nil
  do t over candidates
    p=ray~pointAt(t)
    if p~x*p~x+p~y*p~y<=_apertureRadius*_apertureRadius then do
      if best==.nil then best=t
      else if t<best then best=t
    end
  end
  if best==.nil then return .nil
  p=ray~pointAt(best)
  n=.MathVector3~new(2*p~x,2*p~y,-4*f,ray~context)~normalized
  return .ShapeHit~new(best,p,n)

::class ConvexPlane public
::method init
  expose _normal _limit
  use strict arg normal,limit
  len=normal~norm
  _normal=normal*(1/len); _limit=limit/len
::method normal; expose _normal; return _normal
::method limit; expose _limit; return _limit

::class ConvexPolyhedronShape subclass PhysicalShape public
::method init; expose _planes; use strict arg planes; _planes=planes
::method contains
  expose _planes
  use strict arg point
  eps='0.000000001'
  do plane over _planes
    if plane~normal~dot(point)>plane~limit+eps then return .false
  end
  return .true
::method intersect
  expose _planes
  use strict arg ray
  tNear=-1e100; tFar=1e100; nearNormal=.nil; farNormal=.nil
  eps='0.000000000001'
  do plane over _planes
    n=plane~normal; denom=n~dot(ray~direction); numer=plane~limit-n~dot(ray~origin)
    if abs(denom)<eps then do
      if numer<0 then return .nil
      iterate
    end
    t=numer/denom
    if denom<0 then do
      if t>tNear then do; tNear=t; nearNormal=n; end
    end
    else do
      if t<tFar then do; tFar=t; farNormal=n; end
    end
    if tNear>tFar then return .nil
  end
  if tNear>'0.000000001' then do; t=tNear; n=nearNormal; end
  else if tFar>'0.000000001' then do; t=tFar; n=farNormal; end
  else return .nil
  return .ShapeHit~new(t,ray~pointAt(t),n)

::class BoxShape subclass ConvexPolyhedronShape public
::method init
  use strict arg width,height,depth,context=.nil
  if context==.nil then context=.Maths~defaultContext
  if width<=0 | height<=0 | depth<=0 then raise syntax 88.900 array('positive box dimensions',width'/'height'/'depth)
  planes=.array~new
  planes~append(.ConvexPlane~new(.MathVector3~new(1,0,0,context),width/2))
  planes~append(.ConvexPlane~new(.MathVector3~new(-1,0,0,context),width/2))
  planes~append(.ConvexPlane~new(.MathVector3~new(0,1,0,context),height/2))
  planes~append(.ConvexPlane~new(.MathVector3~new(0,-1,0,context),height/2))
  planes~append(.ConvexPlane~new(.MathVector3~new(0,0,1,context),depth/2))
  planes~append(.ConvexPlane~new(.MathVector3~new(0,0,-1,context),depth/2))
  self~init:super(planes)

::class TriangularPrismShape subclass ConvexPolyhedronShape public
::method init
  use strict arg width,height,length,context=.nil
  if context==.nil then context=.Maths~defaultContext
  numeric digits context~workingDigits
  planes=.array~new
  planes~append(.ConvexPlane~new(.MathVector3~new(0,0,-1,context),height/3))
  planes~append(.ConvexPlane~new(.MathVector3~new(2*height/width,0,1,context),2*height/3))
  planes~append(.ConvexPlane~new(.MathVector3~new(-2*height/width,0,1,context),2*height/3))
  planes~append(.ConvexPlane~new(.MathVector3~new(0,1,0,context),length/2))
  planes~append(.ConvexPlane~new(.MathVector3~new(0,-1,0,context),length/2))
  self~init:super(planes)

::class OpticalHit public
::method init
  expose _body _distance _point _normal
  use strict arg body,distance,point,normal
  _body=body; _distance=distance; _point=point; _normal=normal~normalized
::method body; expose _body; return _body
::method distance; expose _distance; return _distance
::method point; expose _point; return _point
::method normal; expose _normal; return _normal

::class PhysicalBody public
::method init
  expose _name _shape _pose
  use strict arg name,shape,pose=.nil
  if pose==.nil then pose=.PhysicalPose~identity
  _name=name; _shape=shape; _pose=pose
::method name; expose _name; return _name
::method shape; expose _shape; return _shape
::method pose; expose _pose; return _pose
::method 'pose='; expose _pose; use strict arg value; _pose=value
::method contains
  use strict arg worldPoint
  localPoint=self~pose~pointToLocal(worldPoint)
  return self~shape~contains(localPoint)
::method intersect
  use strict arg worldRay
  return .nil

::class OpticalBody subclass PhysicalBody public
::method init
  expose _material _kind _sensor _mediumPriority
  use strict arg name,shape,material,pose=.nil,kind='BODY',sensor=.nil,mediumPriority=100
  self~init:super(name,shape,pose)
  _material=material; _kind=kind~upper; _sensor=sensor; _mediumPriority=mediumPriority
::method material; expose _material; return _material
::method kind; expose _kind; return _kind
::method sensor; expose _sensor; return _sensor
::method mediumPriority; expose _mediumPriority; return _mediumPriority
::method intersect
  use strict arg worldRay
  localOrigin=self~pose~pointToLocal(worldRay~origin)
  localDirection=self~pose~directionToLocal(worldRay~direction)
  localRay=.MathRay3D~new(localOrigin,localDirection,worldRay~context)
  h=self~shape~intersect(localRay)
  if h==.nil then return .nil
  wp=self~pose~pointToWorld(h~point)
  wn=self~pose~directionToWorld(h~normal)
  distance=(wp-worldRay~origin)~norm
  return .OpticalHit~new(self,distance,wp,wn)

::class PhysicalMediumRegion subclass OpticalBody public
::method init
  expose _opticalMedium _acousticMedium
  use strict arg name,shape,opticalMedium=.nil,acousticMedium=.nil,pose=.nil,priority=10
  if opticalMedium==.nil then mat=.nil
  else mat=.OpticalMaterial~dielectric(name||'-optical-material',opticalMedium)
  self~init:super(name,shape,mat,pose,'MEDIUM',.nil,priority)
  _opticalMedium=opticalMedium; _acousticMedium=acousticMedium
::method opticalMedium; expose _opticalMedium; return _opticalMedium
::method acousticMedium; expose _acousticMedium; return _acousticMedium
::method intersect
  expose _opticalMedium
  use strict arg worldRay
  if _opticalMedium==.nil then return .nil
  return self~intersect:super(worldRay)

::class OpticalMediumRegion subclass PhysicalMediumRegion public
::method init
  use strict arg name,shape,medium,pose=.nil,priority=10
  self~init:super(name,shape,medium,.nil,pose,priority)

::class AcousticMediumRegion subclass PhysicalMediumRegion public
::method init
  use strict arg name,shape,medium,pose=.nil,priority=10
  self~init:super(name,shape,.nil,medium,pose,priority)

::class OpticalRayState public
::method init
  expose _origin _direction _wavelength _weight _medium _depth _context _history
  use strict arg origin,direction,wavelengthNm=555,weight=1,medium=.nil,depth=0,context=.nil,history=.nil
  if context==.nil then context=origin~context
  if medium==.nil then medium=.OpticalMedium~air
  if history==.nil then history=.array~new
  _origin=origin; _direction=direction~normalized; _wavelength=wavelengthNm; _weight=weight; _medium=medium; _depth=depth; _context=context; _history=history
::method origin; expose _origin; return _origin
::method direction; expose _direction; return _direction
::method wavelengthNm; expose _wavelength; return _wavelength
::method weight; expose _weight; return _weight
::method medium; expose _medium; return _medium
::method depth; expose _depth; return _depth
::method context; expose _context; return _context
::method history; expose _history; return _history
::method mathRay; return .MathRay3D~new(self~origin,self~direction,self~context)
::method branched
  use strict arg origin,direction,weight,medium,eventText
  h=self~history~copy
  h~append(eventText)
  return .OpticalRayState~new(origin,direction,self~wavelengthNm,weight,medium,self~depth+1,self~context,h)

::class GeometricOptics public
::method reflect class
  use strict arg direction,normal
  return (direction-normal*(2*direction~dot(normal)))~normalized
::method interface class
  use strict arg direction,outwardNormal,n1,n2
  d=direction~normalized
  outward=outwardNormal~normalized
  entering=(d~dot(outward)<0)
  if entering then n=outward
  else n=outward*(-1)
  cosi=-(d~dot(n))
  eta=n1/n2
  k=1-eta*eta*(1-cosi*cosi)
  out=.directory~new
  out['entering']=entering
  out['normal']=n
  out['reflected']=self~reflect(d,n)
  if k<0 then do
    out['tir']=.true
    out['reflectance']=1
    out['transmitted']=.nil
    return out
  end
  cost=RxCalcSqrt(k)
  transmitted=(d*eta+n*(eta*cosi-cost))~normalized
  rsnum=n1*cosi-n2*cost; rsden=n1*cosi+n2*cost
  rpnum=n1*cost-n2*cosi; rpden=n1*cost+n2*cosi
  rs=(rsnum/rsden)*(rsnum/rsden)
  rp=(rpnum/rpden)*(rpnum/rpden)
  r=(rs+rp)/2
  out['tir']=.false
  out['reflectance']=r
  out['transmitted']=transmitted
  return out

::class OpticalSensor public
::method init
  expose _name _shape _pose _received _byWavelength
  use strict arg name,shape,pose=.nil
  if pose==.nil then pose=.PhysicalPose~identity
  _name=name; _shape=shape; _pose=pose; _received=0; _byWavelength=.directory~new
::method name; expose _name; return _name
::method shape; expose _shape; return _shape
::method pose; expose _pose; return _pose
::method received; expose _received; return _received
::method body
  return .OpticalBody~new(self~name,self~shape,.nil,self~pose,'SENSOR',self)
::method receive
  expose _received _byWavelength
  use strict arg ray,hit
  _received=_received+ray~weight
  key=ray~wavelengthNm
  if _byWavelength~hasIndex(key) then _byWavelength[key]=_byWavelength[key]+ray~weight
  else _byWavelength[key]=ray~weight
::method receivedAt
  expose _byWavelength
  use strict arg wavelengthNm
  if _byWavelength~hasIndex(wavelengthNm) then return _byWavelength[wavelengthNm]
  return 0
::method reset
  expose _received _byWavelength
  _received=0; _byWavelength=.directory~new

::class OpticalTraceResult public
::method init
  expose _escaped _absorbed _sensorHits _branches
  _escaped=0; _absorbed=0; _sensorHits=0; _branches=0
::method escaped; expose _escaped; return _escaped
::method absorbed; expose _absorbed; return _absorbed
::method sensorHits; expose _sensorHits; return _sensorHits
::method branches; expose _branches; return _branches
::method addEscaped; expose _escaped; use strict arg w; _escaped=_escaped+w
::method addAbsorbed; expose _absorbed; use strict arg w; _absorbed=_absorbed+w
::method addSensorHit; expose _sensorHits; _sensorHits=_sensorHits+1
::method addBranch; expose _branches; _branches=_branches+1

::class PhysicalWorld public
::method init
  expose _ambient _ambientAcoustic _bodies _epsilon
  use strict arg ambient=.nil,acousticAmbient=.nil
  if ambient==.nil then ambient=.OpticalMedium~air
  _ambient=ambient; _ambientAcoustic=acousticAmbient; _bodies=.array~new; _epsilon='0.00000001'
::method ambient; expose _ambient; return _ambient
::method 'ambient='; expose _ambient; use strict arg value; _ambient=value
::method ambientAcoustic; expose _ambientAcoustic; return _ambientAcoustic
::method 'ambientAcoustic='; expose _ambientAcoustic; use strict arg value; _ambientAcoustic=value
::method bodies; expose _bodies; return _bodies~copy
::method addBody; expose _bodies; use strict arg body; _bodies~append(body); return body
::method addSensor
  use strict arg sensor
  return self~addBody(sensor~body)
::method addMediumRegion
  use strict arg region
  if \region~isA(.PhysicalMediumRegion) then raise syntax 88.900 array('PhysicalMediumRegion',region~class~id)
  return self~addBody(region)
::method mediumAt
  expose _ambient _bodies
  use strict arg point
  selected=_ambient
  selectedPriority=-1000000000
  selectedName=_ambient~name
  do body over _bodies
    candidate=.nil
    if body~isA(.PhysicalMediumRegion) then candidate=body~opticalMedium
    else if body~isA(.OpticalBody) then do
      mat=body~material
      if mat<>.nil then if mat~kind='DIELECTRIC' then candidate=mat~medium
    end
    if candidate==.nil then iterate
    if \body~contains(point) then iterate
    pri=body~mediumPriority
    if pri>selectedPriority then do
      selected=candidate
      selectedPriority=pri
      selectedName=candidate~name
    end
    else if pri=selectedPriority & candidate~name<>selectedName then do
      raise syntax 88.900 array('unambiguous optical medium at point',candidate~name' conflicts with 'selectedName)
    end
  end
  return selected
::method acousticMediumAt
  expose _ambientAcoustic _bodies
  use strict arg point
  selected=_ambientAcoustic
  selectedPriority=-1000000000
  selectedName=''
  if selected<>.nil then selectedName=selected~name
  do body over _bodies
    if \body~isA(.PhysicalMediumRegion) then iterate
    candidate=body~acousticMedium
    if candidate==.nil then iterate
    if \body~contains(point) then iterate
    pri=body~mediumPriority
    if pri>selectedPriority then do
      selected=candidate
      selectedPriority=pri
      selectedName=candidate~name
    end
    else if pri=selectedPriority & candidate~name<>selectedName then do
      raise syntax 88.900 array('unambiguous acoustic medium at point',candidate~name' conflicts with 'selectedName)
    end
  end
  return selected
::method ray
  use strict arg origin,direction,wavelengthNm=555,weight=1,context=.nil
  if context==.nil then context=origin~context
  return .OpticalRayState~new(origin,direction,wavelengthNm,weight,self~mediumAt(origin),0,context)
::method nearestHit
  expose _bodies
  use strict arg ray
  best=.nil
  mray=ray~mathRay
  do body over _bodies
    h=body~intersect(mray)
    if h<>.nil then do
      if best==.nil then best=h
      else if h~distance<best~distance then best=h
    end
  end
  return best
::method trace
  expose _epsilon
  use strict arg initialRay,maxInteractions=12,minWeight='0.000000001'
  q=.queue~new; q~queue(initialRay)
  trace=.OpticalTraceResult~new
  do while q~items>0
    ray=q~pull
    trace~addBranch
    if ray~weight<minWeight then do; trace~addAbsorbed(ray~weight); iterate; end
    if ray~depth>=maxInteractions then do; trace~addAbsorbed(ray~weight); iterate; end
    hit=self~nearestHit(ray)
    if hit==.nil then do; trace~addEscaped(ray~weight); iterate; end
    body=hit~body
    if body~kind='SENSOR' then do
      body~sensor~receive(ray,hit)
      trace~addSensorHit
      iterate
    end
    mat=body~material
    if mat==.nil then do; trace~addAbsorbed(ray~weight); iterate; end
    if mat~kind='MIRROR' then do
      rd=.GeometricOptics~reflect(ray~direction,hit~normal)
      ro=hit~point+rd*_epsilon
      rw=ray~weight*mat~reflectivity
      if rw>0 then q~queue(ray~branched(ro,rd,rw,ray~medium,'mirror:'body~name))
      if rw<ray~weight then trace~addAbsorbed(ray~weight-rw)
      iterate
    end
    if mat~kind='DIELECTRIC' then do
      nCurrent=ray~medium~refractiveIndex(ray~wavelengthNm)
      entering=(ray~direction~dot(hit~normal)<0)
      if entering then probeDirection=hit~normal*(-1)
      else probeDirection=hit~normal
      probe=hit~point+probeDirection*_epsilon
      nextMedium=self~mediumAt(probe)
      nNext=nextMedium~refractiveIndex(ray~wavelengthNm)
      split=.GeometricOptics~interface(ray~direction,hit~normal,nCurrent,nNext)
      r=split['reflectance']
      rd=split['reflected']
      ro=hit~point+rd*_epsilon
      if ray~weight*r>minWeight then q~queue(ray~branched(ro,rd,ray~weight*r,ray~medium,'fresnel-reflect:'body~name))
      td=split['transmitted']
      if td<>.nil then do
        to=hit~point+td*_epsilon
        if ray~weight*(1-r)>minWeight then q~queue(ray~branched(to,td,ray~weight*(1-r),nextMedium,'refract:'body~name))
      end
      iterate
    end
    trace~addAbsorbed(ray~weight)
  end
  return trace

::class Photometry public
::method rectangleSolidAngle class
  use strict arg width,height,distance
  a=width/2; b=height/2; d=distance
  denom=d*RxCalcSqrt(d*d+a*a+b*b)
  return 4*RxCalcArcTan((a*b)/denom,16,'R')
::method isotropicRectangleFlux class
  use strict arg intensityCandela,width,height,distance
  return intensityCandela*self~rectangleSolidAngle(width,height,distance)
::method isotropicRectangleAverageIlluminance class
  use strict arg intensityCandela,width,height,distance
  flux=self~isotropicRectangleFlux(intensityCandela,width,height,distance)
  return flux/(width*height)
::method inverseSquareIlluminance class
  use strict arg intensityCandela,distance
  return intensityCandela/(distance*distance)

::class PhysicsMaterials public
::method air class; return .OpticalMaterial~dielectric('air',.OpticalMedium~air)
::method water class; return .OpticalMaterial~dielectric('water',.OpticalMedium~water)
::method bk7Approx class; return .OpticalMaterial~dielectric('BK7-approx',.OpticalMedium~bk7Approx)
::method idealMirror class; return .OpticalMaterial~mirror('ideal-mirror',1)
::method blackAbsorber class; return .OpticalMaterial~absorber('black-absorber')

::requires 'Units.cls'
::requires 'MathsBootstrap.cls'
::requires 'rxmath' LIBRARY
