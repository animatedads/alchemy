/* ooRexx Physics World v0.1-dev7
   Explicit first free-surface/slosh solver.

   This module is intentionally narrower than general CFD.  It solves the
   one-dimensional nonlinear shallow-water equations in a rectangular tank
   fixed to a vessel.  The liquid has evolving free-surface depth and
   depth-averaged longitudinal momentum.  Reflecting end walls are resolved
   by the numerical flux; there is no "slosh factor" or guessed moving centre
   of mass.

   Current validity boundary:
   - rectangular prismatic tank;
   - one resolved horizontal slosh axis;
   - incompressible Newtonian FluidMedium with constant density;
   - hydrostatic vertical pressure assumption (shallow-water model);
   - liquid remains in contact with the tank floor;
   - no dry cells, overturning/breaking waves, entrained air or spill;
   - optional linear momentum damping is explicit model input;
   - vessel coupling is explicit staggered two-way coupling.
*/

::class RectangularTankGeometry public
::method init
  expose _length _width _height _cells
  use strict arg length,width,height,cellCount=64
  length=.FluidUnitBoundary~scalar(length,.UnitDimension~length,'slosh tank length')
  width=.FluidUnitBoundary~scalar(width,.UnitDimension~length,'slosh tank width')
  height=.FluidUnitBoundary~scalar(height,.UnitDimension~length,'slosh tank height')
  cellCount=cellCount+0
  if length<=0 | width<=0 | height<=0 then raise syntax 88.900 array('positive rectangular tank dimensions',length width height)
  if cellCount<8 then raise syntax 88.900 array('slosh tank cell count >= 8',cellCount)
  _length=length; _width=width; _height=height; _cells=cellCount
::method length; expose _length; return _length
::method width; expose _width; return _width
::method height; expose _height; return _height
::method cellCount; expose _cells; return _cells
::method cellWidth; return self~length/self~cellCount
::method capacity; return self~length*self~width*self~height
::method capacityQuantity; return .Units~q(self~capacity,.Units~cubicMetre)
::method cellCentre
  use strict arg index
  if index<1 | index>self~cellCount then raise syntax 88.900 array('cell index within rectangular tank',index)
  return -self~length/2+(index-'0.5')*self~cellWidth

::class FreeSurfaceSnapshot public
::method init
  expose _time _volume _mass _minDepth _maxDepth _com _momentum _kinetic _potential _normalGravity _tangentialGravity
  use strict arg time,volume,mass,minDepth,maxDepth,centreOfMassLocal,relativeMomentum,kineticEnergy,potentialEnergy,normalGravity,tangentialGravity
  _time=time; _volume=volume; _mass=mass; _minDepth=minDepth; _maxDepth=maxDepth; _com=centreOfMassLocal
  _momentum=relativeMomentum; _kinetic=kineticEnergy; _potential=potentialEnergy
  _normalGravity=normalGravity; _tangentialGravity=tangentialGravity
::method time; expose _time; return _time
::method timeQuantity; return .Units~q(self~time,.Units~second)
::method volume; expose _volume; return _volume
::method volumeQuantity; return .Units~q(self~volume,.Units~cubicMetre)
::method mass; expose _mass; return _mass
::method massQuantity; return .Units~q(self~mass,.Units~kilogram)
::method minDepth; expose _minDepth; return _minDepth
::method minDepthQuantity; return .Units~q(self~minDepth,.Units~metre)
::method maxDepth; expose _maxDepth; return _maxDepth
::method maxDepthQuantity; return .Units~q(self~maxDepth,.Units~metre)
::method centreOfMassLocal; expose _com; return _com
::method relativeMomentum; expose _momentum; return _momentum
::method relativeMomentumQuantity; return .Units~q(self~relativeMomentum,.Units~kilogram*.Units~metrePerSecond)
::method kineticEnergy; expose _kinetic; return _kinetic
::method kineticEnergyQuantity; return .Units~q(self~kineticEnergy,.Units~joule)
::method potentialEnergy; expose _potential; return _potential
::method potentialEnergyQuantity; return .Units~q(self~potentialEnergy,.Units~joule)
::method totalEnergy; return self~kineticEnergy+self~potentialEnergy
::method totalEnergyQuantity; return .Units~q(self~totalEnergy,.Units~joule)
::method normalGravity; expose _normalGravity; return _normalGravity
::method tangentialGravity; expose _tangentialGravity; return _tangentialGravity
::method surfaceRange; return self~maxDepth-self~minDepth
::method surfaceAmplitude; return self~surfaceRange/2

::class FreeSurfaceVesselLoadReport public
::method init
  expose _force _torque _leftDepth _rightDepth _leftWallForce _rightWallForce _com _mass _normalGravity
  use strict arg localForce,localTorque,leftDepth,rightDepth,leftWallForce,rightWallForce,centreOfMassLocal,mass,normalGravity
  _force=localForce; _torque=localTorque; _leftDepth=leftDepth; _rightDepth=rightDepth
  _leftWallForce=leftWallForce; _rightWallForce=rightWallForce; _com=centreOfMassLocal; _mass=mass; _normalGravity=normalGravity
::method localForce; expose _force; return _force
::method localTorque; expose _torque; return _torque
::method forceMagnitudeQuantity; return .Units~q(self~localForce~norm,.Units~newton)
::method torqueMagnitudeQuantity; return .Units~q(self~localTorque~norm,.Units~newton*.Units~metre)
::method leftDepth; expose _leftDepth; return _leftDepth
::method rightDepth; expose _rightDepth; return _rightDepth
::method leftWallForce; expose _leftWallForce; return _leftWallForce
::method rightWallForce; expose _rightWallForce; return _rightWallForce
::method centreOfMassLocal; expose _com; return _com
::method mass; expose _mass; return _mass
::method normalGravity; expose _normalGravity; return _normalGravity

::class RectangularTankSlosh1D public
::method init
  expose _medium _tank _volume _mass _meanDepth _depth _discharge _time _damping _cfl _minDepth _normalGravity _tangentialGravity
  use strict arg fluidMedium,tankGeometry,fillVolume,dampingRate=0,cfl='0.45',minimumDepth='0.000001'
  numeric digits 50
  fillVolume=.FluidUnitBoundary~scalar(fillVolume,.Units~cubicMetre~dimension,'free-surface fill volume')
  dampingRate=.FluidUnitBoundary~scalar(dampingRate,.Units~hertz~dimension,'free-surface damping rate')
  minimumDepth=.FluidUnitBoundary~scalar(minimumDepth,.UnitDimension~length,'free-surface minimum depth')
  cfl=.FluidUnitBoundary~scalar(cfl,.UnitDimension~dimensionless,'free-surface CFL')
  if fillVolume<=0 then raise syntax 88.900 array('positive free-surface fill volume',fillVolume)
  if fillVolume>=tankGeometry~capacity then raise syntax 88.900 array('fill volume below tank capacity for a free surface',fillVolume)
  if dampingRate<0 then raise syntax 88.900 array('non-negative free-surface damping rate',dampingRate)
  if cfl<=0 | cfl>='0.95' then raise syntax 88.900 array('free-surface CFL in (0,0.95)',cfl)
  if minimumDepth<=0 then raise syntax 88.900 array('positive free-surface minimum depth',minimumDepth)
  meanDepth=fillVolume/(tankGeometry~length*tankGeometry~width)
  if meanDepth<=minimumDepth then raise syntax 88.900 array('mean liquid depth above minimum depth',meanDepth)
  if meanDepth>=tankGeometry~height then raise syntax 88.900 array('mean liquid depth below tank rim',meanDepth)
  _medium=fluidMedium; _tank=tankGeometry; _volume=fillVolume; _mass=fluidMedium~density*fillVolume; _meanDepth=meanDepth
  _damping=dampingRate; _cfl=cfl; _minDepth=minimumDepth; _time=0
  _normalGravity='9.80665'; _tangentialGravity=0
  _depth=.array~new(tankGeometry~cellCount); _discharge=.array~new(tankGeometry~cellCount)
  do i=1 to tankGeometry~cellCount; _depth[i]=meanDepth; _discharge[i]=0; end
::method medium; expose _medium; return _medium
::method tank; expose _tank; return _tank
::method volume; expose _volume; return _volume
::method volumeQuantity; return .Units~q(self~volume,.Units~cubicMetre)
::method mass; expose _mass; return _mass
::method massQuantity; return .Units~q(self~mass,.Units~kilogram)
::method meanDepth; expose _meanDepth; return _meanDepth
::method meanDepthQuantity; return .Units~q(self~meanDepth,.Units~metre)
::method time; expose _time; return _time
::method timeQuantity; return .Units~q(self~time,.Units~second)
::method dampingRate; expose _damping; return _damping
::method cfl; expose _cfl; return _cfl
::method minimumDepth; expose _minDepth; return _minDepth
::method normalGravity; expose _normalGravity; return _normalGravity
::method tangentialGravity; expose _tangentialGravity; return _tangentialGravity
::method depths; expose _depth; return _depth~copy
::method discharges; expose _discharge; return _discharge~copy
::method depthAtCell
  expose _depth
  use strict arg index
  return _depth[index]
::method dischargeAtCell
  expose _discharge
  use strict arg index
  return _discharge[index]
::method velocityAtCell
  use strict arg index
  return self~dischargeAtCell(index)/self~depthAtCell(index)
::method resetFlat
  expose _depth _discharge _time _meanDepth _tank _normalGravity _tangentialGravity
  do i=1 to _tank~cellCount; _depth[i]=_meanDepth; _discharge[i]=0; end
  _time=0; _normalGravity='9.80665'; _tangentialGravity=0
  return self
::method seedFundamental
  expose _depth _discharge _meanDepth _tank
  use strict arg amplitude
  numeric digits 50
  amplitude=.FluidUnitBoundary~scalar(amplitude,.UnitDimension~length,'fundamental slosh amplitude')
  if amplitude<0 then raise syntax 88.900 array('non-negative fundamental slosh amplitude',amplitude)
  pi=4*RxCalcArcTan(1,40,'R')
  candidate=.array~new(_tank~cellCount); total=0
  do i=1 to _tank~cellCount
    x=_tank~cellCentre(i)
    candidate[i]=_meanDepth+amplitude*RxCalcSin(pi*x/_tank~length,40,'R')
    total=total+candidate[i]
  end
  /* Midpoint sampling is symmetric, but remove any finite-decimal residue so
     the seeded state retains the declared fill volume exactly. */
  correction=total/_tank~cellCount-_meanDepth
  do i=1 to _tank~cellCount; candidate[i]=candidate[i]-correction; end
  self~validateDepthArray(candidate,'fundamental seed')
  _depth=candidate
  do i=1 to _tank~cellCount; _discharge[i]=0; end
  return self
::method minSurfaceDepth
  expose _depth _tank
  m=_depth[1]
  do i=2 to _tank~cellCount; if _depth[i]<m then m=_depth[i]; end
  return m
::method maxSurfaceDepth
  expose _depth _tank
  m=_depth[1]
  do i=2 to _tank~cellCount; if _depth[i]>m then m=_depth[i]; end
  return m
::method surfaceRange; return self~maxSurfaceDepth-self~minSurfaceDepth
::method surfaceAmplitude; return self~surfaceRange/2
::method currentVolume
  expose _depth _tank
  numeric digits 50
  sum=0
  do i=1 to _tank~cellCount; sum=sum+_depth[i]; end
  return _tank~width*_tank~cellWidth*sum
::method currentMass; return self~medium~density*self~currentVolume
::method relativeMomentum
  expose _depth _discharge _tank _medium
  numeric digits 50
  sum=0
  do i=1 to _tank~cellCount; sum=sum+_discharge[i]; end
  return _medium~density*_tank~width*_tank~cellWidth*sum
::method centreOfMassLocal
  expose _depth _tank
  use strict arg context=.nil
  numeric digits 50
  if context==.nil then context=.Maths~defaultContext
  sumH=0; sumXH=0; sumHH=0
  do i=1 to _tank~cellCount
    h=_depth[i]; x=_tank~cellCentre(i)
    sumH=sumH+h; sumXH=sumXH+x*h; sumHH=sumHH+h*h
  end
  if sumH<=0 then raise syntax 93.900 array('positive resolved free-surface volume')
  xCom=sumXH/sumH
  yCom=sumHH/(2*sumH)
  return .MathVector3~new(xCom,yCom,0,context)
::method freeSurfacePointsLocal
  expose _depth _tank
  use strict arg context=.nil
  if context==.nil then context=.Maths~defaultContext
  points=.array~new
  do i=1 to _tank~cellCount
    points~append(.MathVector3~new(_tank~cellCentre(i),_depth[i],0,context))
  end
  return points
::method kineticEnergy
  expose _depth _discharge _tank _medium
  numeric digits 50
  sum=0
  do i=1 to _tank~cellCount
    h=_depth[i]; q=_discharge[i]
    sum=sum+q*q/h
  end
  return _medium~density*_tank~width*_tank~cellWidth*sum/2
::method kineticEnergyQuantity; return .Units~q(self~kineticEnergy,.Units~joule)
::method potentialEnergy
  expose _depth _tank _medium _normalGravity
  numeric digits 50
  sum=0
  do i=1 to _tank~cellCount; sum=sum+_depth[i]*_depth[i]; end
  return _medium~density*_normalGravity*_tank~width*_tank~cellWidth*sum/2
::method potentialEnergyQuantity; return .Units~q(self~potentialEnergy,.Units~joule)
::method totalMechanicalEnergy; return self~kineticEnergy+self~potentialEnergy
::method totalMechanicalEnergyQuantity; return .Units~q(self~totalMechanicalEnergy,.Units~joule)
::method fundamentalAngularFrequency
  expose _normalGravity _meanDepth _tank
  numeric digits 50
  if _normalGravity<=0 then raise syntax 93.900 array('positive normal effective gravity for shallow-water natural frequency')
  pi=4*RxCalcArcTan(1,40,'R')
  return pi*RxCalcSqrt(_normalGravity*_meanDepth,40)/_tank~length
::method fundamentalPeriod
  numeric digits 50
  pi=4*RxCalcArcTan(1,40,'R')
  return 2*pi/self~fundamentalAngularFrequency
::method fundamentalPeriodQuantity; return .Units~q(self~fundamentalPeriod,.Units~second)
::method maxStableTimeStep
  expose _depth _discharge _tank _cfl
  use strict arg normalGravity=.nil
  numeric digits 50
  if normalGravity==.nil then normalGravity=self~normalGravity
  normalGravity=.FluidUnitBoundary~scalar(normalGravity,.Units~metrePerSecondSquared~dimension,'free-surface normal gravity')
  if normalGravity<=0 then raise syntax 93.900 array('positive normal effective gravity for shallow-water step',normalGravity)
  maxSpeed=0
  do i=1 to _tank~cellCount
    h=_depth[i]; u=abs(_discharge[i]/h); c=RxCalcSqrt(normalGravity*h,40)
    s=u+c
    if s>maxSpeed then maxSpeed=s
  end
  if maxSpeed<='0.000000000000001' then return '1E99'
  return _cfl*_tank~cellWidth/maxSpeed
::method validateDepthArray private
  expose _tank _minDepth
  use strict arg depths,label='free-surface state'
  minD=depths[1]; maxD=depths[1]
  do i=2 to _tank~cellCount
    if depths[i]<minD then minD=depths[i]
    if depths[i]>maxD then maxD=depths[i]
  end
  if minD<=_minDepth then raise syntax 93.900 array(label 'would create a dry/near-dry cell; dry-front physics is not implemented',minD)
  if maxD>=_tank~height then raise syntax 93.900 array(label 'reaches the tank rim; spill/overflow physics is not implemented',maxD)
  return .true
::method requireResolvedState private
  expose _depth
  use strict arg label='free-surface state'
  self~validateDepthArray(_depth,label)
  return self
::method interfaceFlux private
  use strict arg hLeft,qLeft,hRight,qRight,normalGravity
  numeric digits 50
  uLeft=qLeft/hLeft; uRight=qRight/hRight
  fMomentumLeft=qLeft*uLeft+normalGravity*hLeft*hLeft/2
  fMomentumRight=qRight*uRight+normalGravity*hRight*hRight/2
  sLeft=abs(uLeft)+RxCalcSqrt(normalGravity*hLeft,40)
  sRight=abs(uRight)+RxCalcSqrt(normalGravity*hRight,40)
  sMax=sLeft; if sRight>sMax then sMax=sRight
  fluxDepth=(qLeft+qRight)/2-sMax*(hRight-hLeft)/2
  fluxMomentum=(fMomentumLeft+fMomentumRight)/2-sMax*(qRight-qLeft)/2
  return .array~of(fluxDepth,fluxMomentum)
::method step
  expose _depth _discharge _tank _damping _time _normalGravity _tangentialGravity
  use strict arg dt,tangentialEffectiveGravity=0,normalEffectiveGravity='9.80665'
  numeric digits 50
  dt=.FluidUnitBoundary~scalar(dt,.UnitDimension~time,'free-surface timestep')
  tangentialEffectiveGravity=.FluidUnitBoundary~scalar(tangentialEffectiveGravity,.Units~metrePerSecondSquared~dimension,'free-surface tangential effective gravity')
  normalEffectiveGravity=.FluidUnitBoundary~scalar(normalEffectiveGravity,.Units~metrePerSecondSquared~dimension,'free-surface normal effective gravity')
  if dt<=0 then raise syntax 88.900 array('positive free-surface timestep',dt)
  if normalEffectiveGravity<=0 then raise syntax 93.900 array('free-surface model requires liquid retained against the tank floor; effective normal gravity must be positive',normalEffectiveGravity)
  stable=self~maxStableTimeStep(normalEffectiveGravity)
  if dt>stable then raise syntax 93.900 array('free-surface timestep exceeds explicit CFL limit',dt stable)
  n=_tank~cellCount; dx=_tank~cellWidth
  fluxH=.array~new(n+1); fluxQ=.array~new(n+1)
  do iface=1 to n+1
    if iface=1 then do
      hL=_depth[1]; qL=-_discharge[1]; hR=_depth[1]; qR=_discharge[1]
    end
    else if iface=n+1 then do
      hL=_depth[n]; qL=_discharge[n]; hR=_depth[n]; qR=-_discharge[n]
    end
    else do
      hL=_depth[iface-1]; qL=_discharge[iface-1]
      hR=_depth[iface]; qR=_discharge[iface]
    end
    f=self~interfaceFlux(hL,qL,hR,qR,normalEffectiveGravity)
    fluxH[iface]=f[1]; fluxQ[iface]=f[2]
  end
  nextH=.array~new(n); nextQ=.array~new(n)
  ratio=dt/dx
  do i=1 to n
    h=_depth[i]; q=_discharge[i]
    nextH[i]=h-ratio*(fluxH[i+1]-fluxH[i])
    source=h*tangentialEffectiveGravity-_damping*q
    nextQ[i]=q-ratio*(fluxQ[i+1]-fluxQ[i])+dt*source
  end
  self~validateDepthArray(nextH,'free-surface step')
  _depth=nextH; _discharge=nextQ
  _normalGravity=normalEffectiveGravity; _tangentialGravity=tangentialEffectiveGravity; _time=_time+dt
  return self
::method snapshot
  expose _time _normalGravity _tangentialGravity
  return .FreeSurfaceSnapshot~new(_time,self~currentVolume,self~currentMass,self~minSurfaceDepth,self~maxSurfaceDepth, -
    self~centreOfMassLocal,self~relativeMomentum,self~kineticEnergy,self~potentialEnergy,_normalGravity,_tangentialGravity)
::method reactionReport
  expose _tank _medium
  use strict arg normalEffectiveGravity=.nil,context=.nil
  numeric digits 50
  if normalEffectiveGravity==.nil then normalEffectiveGravity=self~normalGravity
  normalEffectiveGravity=.FluidUnitBoundary~scalar(normalEffectiveGravity,.Units~metrePerSecondSquared~dimension,'free-surface reaction normal gravity')
  if normalEffectiveGravity<=0 then raise syntax 93.900 array('positive normal effective gravity for free-surface reaction',normalEffectiveGravity)
  if context==.nil then context=.Maths~defaultContext
  hLeft=self~depthAtCell(1); hRight=self~depthAtCell(_tank~cellCount)
  leftForce=_medium~density*normalEffectiveGravity*_tank~width*hLeft*hLeft/2
  rightForce=_medium~density*normalEffectiveGravity*_tank~width*hRight*hRight/2
  fx=rightForce-leftForce
  mass=self~currentMass
  fy=-mass*normalEffectiveGravity
  com=self~centreOfMassLocal(context)
  /* Wall pressure resultants act one third of the local depth above the floor.
     The floor normal reaction is represented at the instantaneous liquid COM. */
  torqueZ=leftForce*hLeft/3-rightForce*hRight/3+com~x*fy
  force=.MathVector3~new(fx,fy,0,context)
  torque=.MathVector3~new(0,0,torqueZ,context)
  return .FreeSurfaceVesselLoadReport~new(force,torque,hLeft,hRight,leftForce,rightForce,com,mass,normalEffectiveGravity)

::class FreeSurfaceVesselCoupling public
::method init
  expose _slosh _body _localX _localUp _origin _previousVelocity _lastAcceleration _lastEffectiveGravity _lastReport
  use strict arg sloshModel,rigidBodyState,localLongitudinalAxis=.nil,localUpAxis=.nil,tankOriginLocal=.nil
  ctx=rigidBodyState~body~pose~context
  if localLongitudinalAxis==.nil then localLongitudinalAxis=.MathVector3~new(1,0,0,ctx)
  if localUpAxis==.nil then localUpAxis=.MathVector3~new(0,1,0,ctx)
  if tankOriginLocal==.nil then tankOriginLocal=.MathVector3~new(0,0,0,ctx)
  _localX=localLongitudinalAxis~normalized; _localUp=localUpAxis~normalized; _origin=tankOriginLocal
  if abs(_localX~dot(_localUp))>'0.000001' then raise syntax 93.900 array('free-surface vessel axes must be orthogonal')
  _slosh=sloshModel; _body=rigidBodyState; _previousVelocity=rigidBodyState~velocity
  _lastAcceleration=.MathVector3~new(0,0,0,ctx); _lastEffectiveGravity=.nil; _lastReport=.nil
::method sloshModel; expose _slosh; return _slosh
::method bodyState; expose _body; return _body
::method tankOriginLocal; expose _origin; return _origin
::method lastBodyAcceleration; expose _lastAcceleration; return _lastAcceleration
::method lastEffectiveGravityLocal; expose _lastEffectiveGravity; return _lastEffectiveGravity
::method lastLoadReport; expose _lastReport; return _lastReport
::method centreOfMassWorld
  expose _slosh _body _origin
  pose=_body~body~pose
  return pose~pointToWorld(_origin+_slosh~centreOfMassLocal(pose~context))
::method freeSurfacePointsWorld
  expose _slosh _body _origin
  pose=_body~body~pose
  local=_slosh~freeSurfacePointsLocal(pose~context)
  world=.array~new
  do p over local; world~append(pose~pointToWorld(_origin+p)); end
  return world
::method effectiveGravityLocal private
  expose _body _lastAcceleration
  use strict arg mechanicsSolver
  pose=_body~body~pose
  gravityLocal=pose~vectorToLocal(mechanicsSolver~gravity)
  accelLocal=pose~vectorToLocal(_lastAcceleration)
  return gravityLocal-accelLocal
::method advanceKinematics
  expose _slosh _body _localX _localUp _lastAcceleration _lastEffectiveGravity
  use strict arg dt,bodyAccelerationWorld,gravityWorld
  dt=.FluidUnitBoundary~scalar(dt,.UnitDimension~time,'free-surface vessel kinematic timestep')
  if dt<=0 then raise syntax 88.900 array('positive free-surface vessel kinematic timestep',dt)
  pose=_body~body~pose
  accelLocal=pose~vectorToLocal(bodyAccelerationWorld)
  gravityLocal=pose~vectorToLocal(gravityWorld)
  geff=gravityLocal-accelLocal
  tangential=geff~dot(_localX)
  normal=-geff~dot(_localUp)
  if normal<=0 then raise syntax 93.900 array('free-surface vessel coupling lost bottom contact; ballistic/inverted free surface is not implemented',normal)
  _slosh~step(dt,tangential,normal)
  _lastAcceleration=bodyAccelerationWorld; _lastEffectiveGravity=geff
  return _slosh~snapshot
::method applyCurrentLoad
  expose _slosh _body _localUp _origin _lastEffectiveGravity _lastReport
  use strict arg normalEffectiveGravity=.nil
  pose=_body~body~pose
  if normalEffectiveGravity==.nil then do
    if _lastEffectiveGravity==.nil then raise syntax 93.900 array('free-surface coupling requires effective gravity before applying load')
    normalEffectiveGravity=-_lastEffectiveGravity~dot(_localUp)
  end
  report=_slosh~reactionReport(normalEffectiveGravity,pose~context)
  localTorqueAtBody=report~localTorque+_origin~cross(report~localForce)
  _body~applyForce(pose~vectorToWorld(report~localForce),_body~position)
  _body~applyTorque(pose~vectorToWorld(localTorqueAtBody))
  _lastReport=report
  return report
::method beforeMechanicsStep
  expose _slosh _body _localX _localUp _origin _lastEffectiveGravity _lastReport
  use strict arg mechanicsSolver,dt
  dt=.FluidUnitBoundary~scalar(dt,.UnitDimension~time,'free-surface vessel coupling timestep')
  if dt<=0 then raise syntax 88.900 array('positive free-surface vessel coupling timestep',dt)
  pose=_body~body~pose
  geff=self~effectiveGravityLocal(mechanicsSolver)
  normal=-geff~dot(_localUp)
  if normal<=0 then raise syntax 93.900 array('free-surface vessel coupling lost bottom contact; ballistic/inverted free surface is not implemented',normal)
  report=_slosh~reactionReport(normal,pose~context)
  worldForce=pose~vectorToWorld(report~localForce)
  worldTorque=pose~vectorToWorld(report~localTorque+_origin~cross(report~localForce))
  _body~applyForce(worldForce,_body~position)
  _body~applyTorque(worldTorque)
  _lastEffectiveGravity=geff; _lastReport=report
  return report
::method afterMechanicsStep
  expose _slosh _body _localX _localUp _previousVelocity _lastAcceleration _lastEffectiveGravity
  use strict arg mechanicsSolver,dt
  dt=.FluidUnitBoundary~scalar(dt,.UnitDimension~time,'free-surface vessel coupling timestep')
  if dt<=0 then raise syntax 88.900 array('positive free-surface vessel coupling timestep',dt)
  currentVelocity=_body~velocity
  _lastAcceleration=(currentVelocity-_previousVelocity)*(1/dt)
  _previousVelocity=currentVelocity
  pose=_body~body~pose
  gravityLocal=pose~vectorToLocal(mechanicsSolver~gravity)
  accelLocal=pose~vectorToLocal(_lastAcceleration)
  geff=gravityLocal-accelLocal
  tangential=geff~dot(_localX)
  normal=-geff~dot(_localUp)
  if normal<=0 then raise syntax 93.900 array('free-surface vessel coupling lost bottom contact; ballistic/inverted free surface is not implemented',normal)
  _slosh~step(dt,tangential,normal)
  _lastEffectiveGravity=geff
  return _slosh~snapshot

::requires 'Fluids.cls'
::requires 'rxmath' LIBRARY
