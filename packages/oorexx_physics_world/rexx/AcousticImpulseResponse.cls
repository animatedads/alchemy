/* AcousticImpulseResponse.cls
   Reusable forward acoustic oracle.  No localisation semantics live here.
   Geometry/material/atmosphere/source/receiver in; admitted physical arrivals out. */

::class AcousticBandTransfer public
::method init
 expose _frequency _reflection _transmission _diffraction
 use strict arg frequencyHz,pressureReflection,pressureTransmission,diffractionTransfer=0
 _frequency=frequencyHz+0; _reflection=pressureReflection+0; _transmission=pressureTransmission+0; _diffraction=diffractionTransfer+0
 if _frequency<=0 then raise syntax 88.900 array('positive acoustic band frequency',_frequency)
 if abs(_reflection)>1 | abs(_transmission)>1 | abs(_diffraction)>1 then raise syntax 88.900 array('acoustic pressure transfer magnitude <= 1')
::method frequencyHz; expose _frequency; return _frequency
::method pressureReflection; expose _reflection; return _reflection
::method pressureTransmission; expose _transmission; return _transmission
::method diffractionTransfer; expose _diffraction; return _diffraction

::class AcousticSpectralMaterial public
::method init
 expose _name _bands
 use strict arg name
 _name=name; _bands=.directory~new
::method name; expose _name; return _name
::method addBand
 expose _bands
 use strict arg response
 _bands[response~frequencyHz]=response
 return self
::method responseAt
 expose _bands
 use strict arg frequencyHz
 if _bands~hasIndex(frequencyHz) then return _bands[frequencyHz]
 raise syntax 93.900 array('explicit acoustic material band response',self~name frequencyHz)
::method rigid class
 use strict arg frequencies
 m=self~new('rigid')
 do f over frequencies; m~addBand(.AcousticBandTransfer~new(f,1,0,0)); end
 return m
::method transparent class
 use strict arg frequencies
 m=self~new('transparent')
 do f over frequencies; m~addBand(.AcousticBandTransfer~new(f,0,1,0)); end
 return m


/* Building-acoustics helpers.
   These are forward-model conveniences, not localisation semantics.

   The reference presets use a simple normal-incidence limp-panel mass-law
   approximation.  Surface mass is explicit evidence, so callers can replace
   the reference values with surveyed construction data without changing the
   solver.  No empirical absorption is invented: residual non-transmitted
   pressure is represented as reflection. */
::class AcousticBuildingMaterialFactory public
::method massLaw class
  use strict arg name,frequencies,surfaceMassKgM2
  surfaceMassKgM2=surfaceMassKgM2+0
  if surfaceMassKgM2<=0 then raise syntax 88.900 array('positive acoustic surface mass',surfaceMassKgM2)
  m=.AcousticSpectralMaterial~new(name)
  do f over frequencies
    f=f+0
    if f<=0 then raise syntax 88.900 array('positive acoustic band frequency',f)
    /* TL ~= 20 log10(m*f)-47 dB => pressure transfer
       10^(-TL/20) = 10^(47/20)/(m*f). */
    t='223.87211385683395'/(surfaceMassKgM2*f)
    if t>1 then t=1
    if t<0 then t=0
    r=RxCalcSqrt(1-t*t)
    m~addBand(.AcousticBandTransfer~new(f,r,t,0))
  end
  return m

::method solidWoodDoor class
  use strict arg frequencies,thicknessM='0.044',densityKgM3='650'
  /* Reference closed solid-timber door: 44 mm, 650 kg/m3.
     The assumptions are deliberately arguments, not hidden constants. */
  return self~massLaw('solid-wood-door',frequencies,(thicknessM+0)*(densityKgM3+0))

::method breezeBlockWall class
  use strict arg frequencies,thicknessM='0.100',densityKgM3='1200'
  /* Reference 100 mm medium-density aggregate/breeze block leaf.
     Plaster, cavities and secondary leaves must be modelled explicitly. */
  return self~massLaw('breeze-block-wall',frequencies,(thicknessM+0)*(densityKgM3+0))

/* Finite vertical panel specialised for floor-plan geometry.
   The panel runs from plan point A to B and from zMin to zMax.
   It implements the same segmentHit/reflectionPoint protocol consumed by
   AcousticSpectralSurface, avoiding arbitrary quaternion construction in
   building-layout clients. */
::class AcousticVerticalPanel public
::method init
  expose _a _b _zmin _zmax
  use strict arg pointA,pointB,zMin,zMax
  if zMax<=zMin then raise syntax 88.900 array('vertical acoustic panel zMax > zMin')
  dx=pointB~x-pointA~x;dy=pointB~y-pointA~y
  if RxCalcSqrt(dx*dx+dy*dy)<'0.000000001' then raise syntax 88.900 array('non-zero acoustic panel plan length')
  _a=pointA;_b=pointB;_zmin=zMin+0;_zmax=zMax+0
::method pointA; expose _a; return _a
::method pointB; expose _b; return _b
::method zMin; expose _zmin; return _zmin
::method zMax; expose _zmax; return _zmax

::method segmentHit
  expose _a _b _zmin _zmax
  use strict arg p,q
  dx=_b~x-_a~x;dy=_b~y-_a~y
  nx=-dy;ny=dx
  sx=q~x-p~x;sy=q~y-p~y;sz=q~z-p~z
  denom=nx*sx+ny*sy
  if abs(denom)<'0.000000000001' then return .nil
  t=(nx*(_a~x-p~x)+ny*(_a~y-p~y))/denom
  if t<='0.00000001' | t>='0.99999999' then return .nil
  hx=p~x+t*sx;hy=p~y+t*sy;hz=p~z+t*sz
  wallLen2=dx*dx+dy*dy
  u=((hx-_a~x)*dx+(hy-_a~y)*dy)/wallLen2
  if u<0 | u>1 | hz<_zmin | hz>_zmax then return .nil
  ctx=p~context
  hit=.MathVector3~new(hx,hy,hz,ctx)
  n=.MathVector3~new(nx,ny,0,ctx)~normalized
  distance=(hit-p)~norm
  return .ShapeHit~new(distance,hit,n)

::method reflectionPoint
  expose _a _b _zmin _zmax
  use strict arg sourcePoint,receiverPoint
  dx=_b~x-_a~x;dy=_b~y-_a~y
  len=RxCalcSqrt(dx*dx+dy*dy)
  nx=-dy/len;ny=dx/len
  signed=(sourcePoint~x-_a~x)*nx+(sourcePoint~y-_a~y)*ny
  ctx=sourcePoint~context
  image=.MathVector3~new(sourcePoint~x-2*signed*nx,sourcePoint~y-2*signed*ny,sourcePoint~z,ctx)
  lx=receiverPoint~x-image~x;ly=receiverPoint~y-image~y;lz=receiverPoint~z-image~z
  denom=nx*lx+ny*ly
  if abs(denom)<'0.000000000001' then return .nil
  t=(nx*(_a~x-image~x)+ny*(_a~y-image~y))/denom
  if t<=0 | t>=1 then return .nil
  qx=image~x+t*lx;qy=image~y+t*ly;qz=image~z+t*lz
  u=((qx-_a~x)*dx+(qy-_a~y)*dy)/(dx*dx+dy*dy)
  if u<0 | u>1 | qz<_zmin | qz>_zmax then return .nil
  return .MathVector3~new(qx,qy,qz,ctx)


/* Bounded diffuse/scattering point on a finite vertical panel.
   Unlike reflectionPoint(), this does not claim mirror/specular reflection.
   It is intended for finite rough/curved bodies such as a vehicle side where
   source and receiver may both be above the top edge.  The chosen point is the
   deterministic minimum-total-path sample on the physical panel. */
::method scatterPoint
  expose _a _b _zmin _zmax
  use strict arg sourcePoint,receiverPoint,uSamples=33,zSamples=9
  uSamples=uSamples+0;zSamples=zSamples+0
  if uSamples<2 | zSamples<2 then raise syntax 88.900 array('scatter sampling at least 2x2')
  dx=_b~x-_a~x;dy=_b~y-_a~y;ctx=sourcePoint~context
  best=.nil;bestDistance=.nil
  do ui=0 to uSamples-1
    u=ui/(uSamples-1)
    x=_a~x+u*dx;y=_a~y+u*dy
    do zi=0 to zSamples-1
      z=_zmin+(zi/(zSamples-1))*(_zmax-_zmin)
      q=.MathVector3~new(x,y,z,ctx)
      d=(q-sourcePoint)~norm+(receiverPoint-q)~norm
      if best==.nil | d<bestDistance then do;best=q;bestDistance=d;end
    end
  end
  return best

::class AcousticDiffuseReflector public
::method init
  expose _name _surface _efficiency _sigma
  use strict arg name,spectralSurface,scatteringCrossSectionM2,scatterEfficiency='1.0'
  _name=name;_surface=spectralSurface;_sigma=scatteringCrossSectionM2+0;_efficiency=scatterEfficiency+0
  if _sigma<=0 then raise syntax 88.900 array('positive diffuse scattering cross-section m2',_sigma)
  if _efficiency<0 | _efficiency>1 then raise syntax 88.900 array('diffuse scatter efficiency in [0,1]',_efficiency)
::method name; expose _name; return _name
::method surface; expose _surface; return _surface
::method material; expose _surface; return _surface~material
::method scatteringCrossSectionM2; expose _sigma; return _sigma
::method scatterEfficiency; expose _efficiency; return _efficiency
::method scatterPoint; expose _surface; use strict arg sourcePoint,receiverPoint; return _surface~surface~scatterPoint(sourcePoint,receiverPoint)


::class AcousticSpectralSurface public
::method init
 expose _surface _material _name
 use strict arg name,surface,spectralMaterial
 _name=name; _surface=surface; _material=spectralMaterial
::method name; expose _name; return _name
::method surface; expose _surface; return _surface
::method material; expose _material; return _material
::method segmentHit; expose _surface; use strict arg a,b; return _surface~segmentHit(a,b)
::method reflectionPoint; expose _surface; use strict arg a,b; return _surface~reflectionPoint(a,b)

::class AcousticDiffractionPoint public
::method init
 expose _name _point _material
 use strict arg name,point,spectralMaterial
 _name=name; _point=point; _material=spectralMaterial
::method name; expose _name; return _name
::method point; expose _point; return _point
::method material; expose _material; return _material

::class AcousticEmissionBand public
::method init
 expose _frequency _power _phase
 use strict arg frequencyHz,acousticPowerW,phaseRadians=0
 _frequency=frequencyHz+0; _power=acousticPowerW+0; _phase=phaseRadians+0
 if _frequency<=0 | _power<0 then raise syntax 88.900 array('valid acoustic emission band',_frequency _power)
::method frequencyHz; expose _frequency; return _frequency
::method acousticPowerW; expose _power; return _power
::method phaseRadians; expose _phase; return _phase

::class AcousticEmissionSpectrum public
::method init
 expose _bands
 _bands=.array~new
::method addBand; expose _bands; use strict arg band; _bands~append(band); return self
::method bands; expose _bands; return _bands~copy

::class AcousticPathVertex public
::method init
 expose _kind _name _point
 use strict arg kind,name,point
 _kind=kind; _name=name; _point=point
::method kind; expose _kind; return _kind
::method name; expose _name; return _name
::method point; expose _point; return _point

::class AcousticImpulseArrival public
::method init
 expose _kind _distance _delay _vertices _bands _evidence _emissionTime
 use strict arg kind,distance,delay,vertices,bandPhasors,evidence=.nil,emissionTime=0
 _kind=kind;_distance=distance;_delay=delay;_vertices=vertices~copy;_bands=bandPhasors~copy;_evidence=evidence;_emissionTime=emissionTime
::method kind; expose _kind; return _kind
::method distance; expose _distance; return _distance
::method delay; expose _delay; return _delay
::method arrivalTime; expose _delay _emissionTime; return _emissionTime+_delay
::method emissionTime; expose _emissionTime; return _emissionTime
::method vertices; expose _vertices; return _vertices~copy
::method bandPhasors; expose _bands; return _bands~copy
::method phasorAt; expose _bands; use strict arg frequencyHz; return _bands[frequencyHz]
::method evidence; expose _evidence; return _evidence
::method interactionCount
 expose _vertices
 n=0
 do v over _vertices
   if v~kind<>'SOURCE' & v~kind<>'RECEIVER' & v~kind<>'TRANSMISSION' then n=n+1
 end
 return n
::method pathSignature
 expose _vertices
 signature=''
 do v over _vertices
   token=v~kind || ':' || v~name
   if signature='' then signature=token
   else signature=signature || ' -> ' || token
 end
 return signature
::method bandEnergyProxy
 expose _bands
 sum=0
 do f over _bands~allIndexes
   p=_bands[f]~magnitude
   sum=sum+p*p
 end
 return sum

::class AcousticReceiverImpulseResponse public
::method init
 expose _name _position _arrivals
 use strict arg receiverName,receiverPosition
 _name=receiverName;_position=receiverPosition;_arrivals=.array~new
::method name; expose _name; return _name
::method position; expose _position; return _position
::method addArrival
 expose _arrivals
 use strict arg arrival
 /* insertion sort keeps deterministic delay order without depending on collection sort */
 out=.array~new; inserted=.false
 do a over _arrivals
   if inserted=.false & arrival~arrivalTime<a~arrivalTime then do; out~append(arrival); inserted=.true; end
   out~append(a)
 end
 if inserted=.false then out~append(arrival)
 _arrivals=out
 return arrival
::method arrivals
 expose _arrivals
 return _arrivals~copy
::method arrivalsWithin
 expose _arrivals
 use strict arg seconds
 out=.array~new
 do a over _arrivals
   if a~delay<=seconds then out~append(a)
 end
 return out
::method firstArrival
 expose _arrivals
 if _arrivals~items=0 then return .nil
 return _arrivals[1]
::method arrivalsByKind
 expose _arrivals
 use strict arg kind
 out=.array~new
 do a over _arrivals
   if a~kind=kind then out~append(a)
 end
 return out
::method energyProxy
 expose _arrivals
 sum=0
 do a over _arrivals; sum=sum+a~bandEnergyProxy; end
 return sum

::class AcousticImpulseResponseResult public
::method init
 expose _source _responses
 use strict arg sourcePosition
 _source=sourcePosition; _responses=.directory~new
::method sourcePosition; expose _source; return _source
::method addReceiver; expose _responses; use strict arg response; _responses[response~name]=response; return response
::method receiver; expose _responses; use strict arg name; return _responses[name]
::method receiverNames; expose _responses; return _responses~allIndexes

::class AcousticTrajectorySample public
::method init
 expose _time _position _velocity
 use strict arg time,position,velocity=.nil
 _time=time+0;_position=position;_velocity=velocity
::method time; expose _time; return _time
::method position; expose _position; return _position
::method velocity; expose _velocity; return _velocity

::class AcousticTrajectory public
::method init
 expose _samples
 _samples=.array~new
::method add; expose _samples; use strict arg sample; _samples~append(sample); return self
::method samples; expose _samples; return _samples~copy

::class AcousticDelayInterval public
::method init
 expose _min _max
 use strict arg minimumSeconds,maximumSeconds
 _min=minimumSeconds;_max=maximumSeconds
::method minimum; expose _min; return _min
::method maximum; expose _max; return _max

::class AcousticImpulseResponseSolver public
::method init
 expose _world _surfaces _edges _diffuse
 use strict arg physicalWorld
 _world=physicalWorld;_surfaces=.array~new;_edges=.array~new;_diffuse=.array~new
 if _world~ambientAcoustic==.nil then _world~ambientAcoustic=.AcousticMedium~air
::method addSurface; expose _surfaces; use strict arg surface; _surfaces~append(surface); return surface
::method addDiffractionPoint; expose _edges; use strict arg edge; _edges~append(edge); return edge
::method addDiffuseReflector; expose _diffuse; use strict arg reflector; _diffuse~append(reflector); return reflector
::method surfaces; expose _surfaces; return _surfaces~copy
::method diffractionPoints; expose _edges; return _edges~copy
::method diffuseReflectors; expose _diffuse; return _diffuse~copy

::method medium
 expose _world
 use strict arg a,b
 ma=_world~acousticMediumAt(a); mb=_world~acousticMediumAt(b)
 if ma==.nil then ma=_world~ambientAcoustic
 if mb==.nil then mb=_world~ambientAcoustic
 if ma==.nil | mb==.nil | ma~name<>mb~name then raise syntax 93.900 array('single acoustic medium required for AIR path')
 return ma

::method transmission
 expose _surfaces
 use strict arg a,b,frequencyHz,exclude=.nil
 coefficient=1; names=''
 do s over _surfaces
   if exclude<>.nil then if s==exclude then iterate
   if s~segmentHit(a,b)<>.nil then do
     r=s~material~responseAt(frequencyHz)
     coefficient=coefficient*r~pressureTransmission
     if names='' then names=s~name; else names=names','s~name
   end
 end
 return coefficient

::method transmissionVertices
 expose _surfaces
 use strict arg a,b,exclude=.nil
 hits=.array~new
 do surface over _surfaces
   if exclude<>.nil then if surface==exclude then iterate
   h=surface~segmentHit(a,b)
   if h==.nil then iterate
   vertex=.AcousticPathVertex~new('TRANSMISSION',surface~name,h~point)
   /* deterministic insertion by distance from segment start */
   out=.array~new; inserted=.false
   do old over hits
     if inserted=.false & (vertex~point-a)~norm<(old~point-a)~norm then do;out~append(vertex);inserted=.true;end
     out~append(old)
   end
   if inserted=.false then out~append(vertex)
   hits=out
 end
 return hits

::method pathPhasor
 use strict arg emissionBand,distance,medium,coefficient
 pi=4*RxCalcArcTan(1,30,'R')
 intensity=emissionBand~acousticPowerW/(4*pi*distance*distance)
 magnitude=RxCalcSqrt(intensity*medium~impedance)*medium~propagationFactor(emissionBand~frequencyHz,distance)
 phase=emissionBand~phaseRadians-medium~wavenumber(emissionBand~frequencyHz)*distance
 return .AcousticPhasor~fromPolar(magnitude,phase)*coefficient

/* First-order bistatic diffuse scattering.  Unlike pathPhasor(), this has
   TWO spherical-spreading legs.  sigma is an effective scattering cross-section
   in m^2, so a finite reflector cannot create energy as if the entire broken
   path were one direct spherical wave. */
::method scatterPhasor
 use strict arg emissionBand,incidentDistance,receiverDistance,medium,scatteringCrossSectionM2,coefficient
 if incidentDistance<='0.000000001' | receiverDistance<='0.000000001' then return .AcousticComplex~new(0,0)
 if scatteringCrossSectionM2<=0 then return .AcousticComplex~new(0,0)
 pi=4*RxCalcArcTan(1,30,'R')
 magnitude=RxCalcSqrt(emissionBand~acousticPowerW*medium~impedance*scatteringCrossSectionM2)/(4*pi*incidentDistance*receiverDistance)
 magnitude=magnitude*medium~propagationFactor(emissionBand~frequencyHz,incidentDistance)*medium~propagationFactor(emissionBand~frequencyHz,receiverDistance)
 phase=emissionBand~phaseRadians-medium~wavenumber(emissionBand~frequencyHz)*(incidentDistance+receiverDistance)
 return .AcousticPhasor~fromPolar(magnitude,phase)*coefficient

::method solve
 expose _surfaces _edges _diffuse
 use strict arg sourcePosition,emissionSpectrum,receivers,maxSeconds='0.150',emissionTime=0
 responseSet=.AcousticImpulseResponseResult~new(sourcePosition)
 do receiverName over receivers~allIndexes
   receiverPoint=receivers[receiverName]
   rr=.AcousticReceiverImpulseResponse~new(receiverName,receiverPoint)
   responseSet~addReceiver(rr)
   medium=self~medium(sourcePosition,receiverPoint)

   /* Direct / finite-wall transmission path. */
   distance=(receiverPoint-sourcePosition)~norm
   delay=distance/medium~soundSpeed
   if delay<=maxSeconds then do
     ph=.directory~new; admitted=.false
     do band over emissionSpectrum~bands
       c=self~transmission(sourcePosition,receiverPoint,band~frequencyHz)
       if c<>0 then admitted=.true
       ph[band~frequencyHz]=self~pathPhasor(band,distance,medium,c)
     end
     if admitted then do
       v=.array~new;v~append(.AcousticPathVertex~new('SOURCE','source',sourcePosition));do tv over self~transmissionVertices(sourcePosition,receiverPoint);v~append(tv);end;v~append(.AcousticPathVertex~new('RECEIVER',receiverName,receiverPoint))
       rr~addArrival(.AcousticImpulseArrival~new('DIRECT_OR_TRANSMITTED',distance,delay,v,ph,.nil,emissionTime))
     end
   end

   /* First-order finite specular reflection. */
   do surface over _surfaces
     q=surface~reflectionPoint(sourcePosition,receiverPoint)
     if q==.nil then iterate
     m1=self~medium(sourcePosition,q); m2=self~medium(q,receiverPoint)
     if m1~name<>m2~name then iterate
     distance=(q-sourcePosition)~norm+(receiverPoint-q)~norm
     delay=distance/m1~soundSpeed
     if delay>maxSeconds then iterate
     ph=.directory~new; admitted=.false
     do band over emissionSpectrum~bands
       r=surface~material~responseAt(band~frequencyHz)
       c=r~pressureReflection*self~transmission(sourcePosition,q,band~frequencyHz,surface)*self~transmission(q,receiverPoint,band~frequencyHz,surface)
       if c<>0 then admitted=.true
       ph[band~frequencyHz]=self~pathPhasor(band,distance,m1,c)
     end
     if admitted then do
       v=.array~new;v~append(.AcousticPathVertex~new('SOURCE','source',sourcePosition));v~append(.AcousticPathVertex~new('REFLECTION',surface~name,q));v~append(.AcousticPathVertex~new('RECEIVER',receiverName,receiverPoint))
       rr~addArrival(.AcousticImpulseArrival~new('REFLECTION',distance,delay,v,ph,surface~name,emissionTime))
     end
   end

   /* Bounded first-order diffuse/scattered reflection.  This is separate from
      mirror/specular reflection and is opt-in: ordinary building surfaces are
      not silently promoted to diffuse reflectors.  It is used by finite moving
      bodies such as the F11 test vehicle. */
   do reflector over _diffuse
     q=reflector~scatterPoint(sourcePosition,receiverPoint)
     if q==.nil then iterate
     m1=self~medium(sourcePosition,q);m2=self~medium(q,receiverPoint)
     if m1~name<>m2~name then iterate
     incidentDistance=(q-sourcePosition)~norm;receiverDistance=(receiverPoint-q)~norm
     distance=incidentDistance+receiverDistance
     delay=distance/m1~soundSpeed
     if delay>maxSeconds then iterate
     ph=.directory~new;admitted=.false
     do band over emissionSpectrum~bands
       r=reflector~material~responseAt(band~frequencyHz)
       baseSurface=reflector~surface
       c=r~pressureReflection*reflector~scatterEfficiency*self~transmission(sourcePosition,q,band~frequencyHz,baseSurface)*self~transmission(q,receiverPoint,band~frequencyHz,baseSurface)
       if c<>0 then admitted=.true
       ph[band~frequencyHz]=self~scatterPhasor(band,incidentDistance,receiverDistance,m1,reflector~scatteringCrossSectionM2,c)
     end
     if admitted then do
       v=.array~new;v~append(.AcousticPathVertex~new('SOURCE','source',sourcePosition));v~append(.AcousticPathVertex~new('MOVING_REFLECTION',reflector~name,q));v~append(.AcousticPathVertex~new('RECEIVER',receiverName,receiverPoint))
       rr~addArrival(.AcousticImpulseArrival~new('DIFFUSE_REFLECTION',distance,delay,v,ph,reflector~name,emissionTime))
     end
   end

   /* Bounded first-order edge/door/corner diffraction.
      The geometry and excess path are solved here.  The spectral diffraction
      transfer is explicit material/model evidence; Physics does not invent it. */
   do edge over _edges
     q=edge~point
     m1=self~medium(sourcePosition,q);m2=self~medium(q,receiverPoint)
     if m1~name<>m2~name then iterate
     distance=(q-sourcePosition)~norm+(receiverPoint-q)~norm
     delay=distance/m1~soundSpeed
     if delay>maxSeconds then iterate
     ph=.directory~new; admitted=.false
     do band over emissionSpectrum~bands
       d=edge~material~responseAt(band~frequencyHz)~diffractionTransfer
       c=d*self~transmission(sourcePosition,q,band~frequencyHz)*self~transmission(q,receiverPoint,band~frequencyHz)
       if c<>0 then admitted=.true
       ph[band~frequencyHz]=self~pathPhasor(band,distance,m1,c)
     end
     if admitted then do
       v=.array~new;v~append(.AcousticPathVertex~new('SOURCE','source',sourcePosition));v~append(.AcousticPathVertex~new('DIFFRACTION',edge~name,q));v~append(.AcousticPathVertex~new('RECEIVER',receiverName,receiverPoint))
       rr~addArrival(.AcousticImpulseArrival~new('DIFFRACTION',distance,delay,v,ph,edge~name,emissionTime))
     end
   end
 end
 return responseSet


/* Bounded second-order early-path expansion.
   This deliberately does not turn solve() into an unbounded ray tracer.
   Supported order-2 families are:
     diffraction -> diffraction
     reflection  -> diffraction
     diffraction -> reflection
   Fixed diffraction points make those legs geometrically exact for the
   supplied edge model; the one-reflection leg is solved by the surface's
   finite reflectionPoint protocol. */
::method addSecondOrderEarlyPaths
 expose _surfaces _edges
 use strict arg sourcePosition,emissionSpectrum,receiverName,receiverPoint,rr,maxSeconds,emissionTime=0

 /* Two explicit diffraction interactions. */
 do edge1 over _edges
   q1=edge1~point
   do edge2 over _edges
     if edge2==edge1 then iterate
     q2=edge2~point
     m=self~medium(sourcePosition,q1)
     if self~medium(q1,q2)~name<>m~name | self~medium(q2,receiverPoint)~name<>m~name then iterate
     distance=(q1-sourcePosition)~norm+(q2-q1)~norm+(receiverPoint-q2)~norm
     delay=distance/m~soundSpeed
     if delay>maxSeconds then iterate
     ph=.directory~new;admitted=.false
     do band over emissionSpectrum~bands
       d1=edge1~material~responseAt(band~frequencyHz)~diffractionTransfer
       d2=edge2~material~responseAt(band~frequencyHz)~diffractionTransfer
       c=d1*d2*self~transmission(sourcePosition,q1,band~frequencyHz)*self~transmission(q1,q2,band~frequencyHz)*self~transmission(q2,receiverPoint,band~frequencyHz)
       if c<>0 then admitted=.true
       ph[band~frequencyHz]=self~pathPhasor(band,distance,m,c)
     end
     if admitted then do
       v=.array~new;v~append(.AcousticPathVertex~new('SOURCE','source',sourcePosition))
       do tv over self~transmissionVertices(sourcePosition,q1);v~append(tv);end
       v~append(.AcousticPathVertex~new('DIFFRACTION',edge1~name,q1))
       do tv over self~transmissionVertices(q1,q2);v~append(tv);end
       v~append(.AcousticPathVertex~new('DIFFRACTION',edge2~name,q2))
       do tv over self~transmissionVertices(q2,receiverPoint);v~append(tv);end
       v~append(.AcousticPathVertex~new('RECEIVER',receiverName,receiverPoint))
       rr~addArrival(.AcousticImpulseArrival~new('DIFFRACTION_DIFFRACTION',distance,delay,v,ph,edge1~name '->' edge2~name,emissionTime))
     end
   end
 end

 /* Finite reflection followed by explicit diffraction. */
 do surface over _surfaces
   do edge over _edges
     qe=edge~point
     qr=surface~reflectionPoint(sourcePosition,qe)
     if qr==.nil then iterate
     m=self~medium(sourcePosition,qr)
     if self~medium(qr,qe)~name<>m~name | self~medium(qe,receiverPoint)~name<>m~name then iterate
     distance=(qr-sourcePosition)~norm+(qe-qr)~norm+(receiverPoint-qe)~norm
     delay=distance/m~soundSpeed
     if delay>maxSeconds then iterate
     ph=.directory~new;admitted=.false
     do band over emissionSpectrum~bands
       r=surface~material~responseAt(band~frequencyHz)~pressureReflection
       d=edge~material~responseAt(band~frequencyHz)~diffractionTransfer
       c=r*d*self~transmission(sourcePosition,qr,band~frequencyHz,surface)*self~transmission(qr,qe,band~frequencyHz,surface)*self~transmission(qe,receiverPoint,band~frequencyHz)
       if c<>0 then admitted=.true
       ph[band~frequencyHz]=self~pathPhasor(band,distance,m,c)
     end
     if admitted then do
       v=.array~new;v~append(.AcousticPathVertex~new('SOURCE','source',sourcePosition))
       v~append(.AcousticPathVertex~new('REFLECTION',surface~name,qr))
       v~append(.AcousticPathVertex~new('DIFFRACTION',edge~name,qe))
       v~append(.AcousticPathVertex~new('RECEIVER',receiverName,receiverPoint))
       rr~addArrival(.AcousticImpulseArrival~new('REFLECTION_DIFFRACTION',distance,delay,v,ph,surface~name '->' edge~name,emissionTime))
     end
   end
 end

 /* Explicit diffraction followed by finite reflection. */
 do edge over _edges
   qe=edge~point
   do surface over _surfaces
     qr=surface~reflectionPoint(qe,receiverPoint)
     if qr==.nil then iterate
     m=self~medium(sourcePosition,qe)
     if self~medium(qe,qr)~name<>m~name | self~medium(qr,receiverPoint)~name<>m~name then iterate
     distance=(qe-sourcePosition)~norm+(qr-qe)~norm+(receiverPoint-qr)~norm
     delay=distance/m~soundSpeed
     if delay>maxSeconds then iterate
     ph=.directory~new;admitted=.false
     do band over emissionSpectrum~bands
       d=edge~material~responseAt(band~frequencyHz)~diffractionTransfer
       r=surface~material~responseAt(band~frequencyHz)~pressureReflection
       c=d*r*self~transmission(sourcePosition,qe,band~frequencyHz)*self~transmission(qe,qr,band~frequencyHz,surface)*self~transmission(qr,receiverPoint,band~frequencyHz,surface)
       if c<>0 then admitted=.true
       ph[band~frequencyHz]=self~pathPhasor(band,distance,m,c)
     end
     if admitted then do
       v=.array~new;v~append(.AcousticPathVertex~new('SOURCE','source',sourcePosition))
       v~append(.AcousticPathVertex~new('DIFFRACTION',edge~name,qe))
       v~append(.AcousticPathVertex~new('REFLECTION',surface~name,qr))
       v~append(.AcousticPathVertex~new('RECEIVER',receiverName,receiverPoint))
       rr~addArrival(.AcousticImpulseArrival~new('DIFFRACTION_REFLECTION',distance,delay,v,ph,edge~name '->' surface~name,emissionTime))
     end
   end
 end
 return rr

::method solveEarly
 use strict arg sourcePosition,emissionSpectrum,receivers,maxSeconds='0.150',maxInteractions=2,emissionTime=0
 if maxInteractions<1 | maxInteractions>2 then raise syntax 88.900 array('supported early acoustic interaction order 1 or 2',maxInteractions)
 responseSet=self~solve(sourcePosition,emissionSpectrum,receivers,maxSeconds,emissionTime)
 if maxInteractions=1 then return responseSet
 do receiverName over responseSet~receiverNames
   ignore=self~addSecondOrderEarlyPaths(sourcePosition,emissionSpectrum,receiverName,receivers[receiverName],responseSet~receiver(receiverName),maxSeconds,emissionTime)
 end
 return responseSet

::method solveTrajectory
 use strict arg trajectory,emissionSpectrum,receivers,maxSeconds='0.150'
 out=.array~new
 do sample over trajectory~samples
   out~append(self~solve(sample~position,emissionSpectrum,receivers,maxSeconds,sample~time))
 end
 return out

::method firstArrivalUncertainty
 use strict arg sourceMin,sourceMax,emissionSpectrum,receivers,soundSpeedMin,soundSpeedMax,maxSeconds='0.150'
 /* Topology-aware corner sampling: rerun the actual solver at all 8 source-box
    corners. Sound-speed bounds are then applied to admitted path lengths. */
 mins=.directory~new; maxs=.directory~new
 xs=.array~of(sourceMin~x,sourceMax~x);ys=.array~of(sourceMin~y,sourceMax~y);zs=.array~of(sourceMin~z,sourceMax~z)
 do x over xs
   do y over ys
     do z over zs
       p=.MathVector3~new(x,y,z,sourceMin~context)
       r=self~solve(p,emissionSpectrum,receivers,maxSeconds)
       do name over r~receiverNames
         a=r~receiver(name)~firstArrival
         if a==.nil then iterate
         lo=a~distance/soundSpeedMax; hi=a~distance/soundSpeedMin
         if \mins~hasIndex(name) | lo<mins[name] then mins[name]=lo
         if \maxs~hasIndex(name) | hi>maxs[name] then maxs[name]=hi
       end
     end
   end
 end
 out=.directory~new
 do name over mins~allIndexes; out[name]=.AcousticDelayInterval~new(mins[name],maxs[name]); end
 return out

::class AcousticCandidatePrediction public
::method init
 expose _position _response
 use strict arg position,response
 _position=position;_response=response
::method position; expose _position; return _position
::method response; expose _response; return _response
::method firstArrivalDifference
 expose _response
 use strict arg receiverB,receiverA
 b=_response~receiver(receiverB)~firstArrival;a=_response~receiver(receiverA)~firstArrival
 if a==.nil | b==.nil then return .nil
 return b~delay-a~delay
::method energyRatio
 expose _response
 use strict arg numeratorReceiver,denominatorReceiver
 n=_response~receiver(numeratorReceiver)~energyProxy;d=_response~receiver(denominatorReceiver)~energyProxy
 if d=0 then return .nil
 return n/d

::class AcousticForwardOracle public
::method init
 expose _solver
 use strict arg impulseResponseSolver
 _solver=impulseResponseSolver
::method predict
 expose _solver
 use strict arg candidatePoints,emissionSpectrum,receivers,maxSeconds='0.150'
 out=.array~new
 do p over candidatePoints
   out~append(.AcousticCandidatePrediction~new(p,_solver~solve(p,emissionSpectrum,receivers,maxSeconds)))
 end
 return out

::method predictEarly
 expose _solver
 use strict arg candidatePoints,emissionSpectrum,receivers,maxSeconds='0.150',maxInteractions=2
 out=.array~new
 do p over candidatePoints
   out~append(.AcousticCandidatePrediction~new(p,_solver~solveEarly(p,emissionSpectrum,receivers,maxSeconds,maxInteractions)))
 end
 return out

::requires 'Acoustics.cls'
