/* ooRexx Physics World v0.1-dev11
   Two-horizontal-axis free-surface/slosh solver.

   This is a conservative depth-averaged shallow-water model over a
   rectangular horizontal tank floor.  It extends the dev7 one-dimensional
   solver without replacing it.  State per cell is:

       h   liquid depth
       qx  depth-integrated velocity along local +X
       qz  depth-integrated velocity along local +Z

   Local +Y is the tank up axis.  The governing system is the two-dimensional
   nonlinear shallow-water equation with vessel-frame effective gravity and
   optional explicit linear momentum damping.  Rusanov numerical fluxes and
   reflecting walls are used in both horizontal directions.

   Honest boundary:
   - rectangular prismatic tank with flat floor;
   - hydrostatic vertical pressure assumption;
   - positive floor-normal effective gravity;
   - no dry fronts, spill, breaking waves, overturning, entrained air,
     capillarity or turbulence closure;
   - explicit CFL guard;
   - vessel coupling remains staggered/partitioned.
*/

::class RectangularTankGeometry2D public
::method init
  expose _length _width _height _nx _nz
  use strict arg length,width,height,xCells=24,zCells=16
  length=.FluidUnitBoundary~scalar(length,.UnitDimension~length,'2D slosh tank length')
  width=.FluidUnitBoundary~scalar(width,.UnitDimension~length,'2D slosh tank width')
  height=.FluidUnitBoundary~scalar(height,.UnitDimension~length,'2D slosh tank height')
  xCells=xCells+0; zCells=zCells+0
  if length<=0 | width<=0 | height<=0 then raise syntax 88.900 array('positive 2D rectangular tank dimensions',length width height)
  if xCells<4 | zCells<4 then raise syntax 88.900 array('2D slosh tank cell counts >= 4',xCells zCells)
  _length=length; _width=width; _height=height; _nx=xCells; _nz=zCells
::method length; expose _length; return _length
::method width; expose _width; return _width
::method height; expose _height; return _height
::method xCells; expose _nx; return _nx
::method zCells; expose _nz; return _nz
::method cellCount; return self~xCells*self~zCells
::method dx; return self~length/self~xCells
::method dz; return self~width/self~zCells
::method cellArea; return self~dx*self~dz
::method capacity; return self~length*self~width*self~height
::method capacityQuantity; return .Units~q(self~capacity,.Units~cubicMetre)
::method xCentre
  use strict arg i
  if i<1 | i>self~xCells then raise syntax 88.900 array('2D slosh x cell index in range',i)
  return -self~length/2+(i-'0.5')*self~dx
::method zCentre
  use strict arg j
  if j<1 | j>self~zCells then raise syntax 88.900 array('2D slosh z cell index in range',j)
  return -self~width/2+(j-'0.5')*self~dz

::class FreeSurfaceSnapshot2D public
::method init
  expose _time _volume _mass _minDepth _maxDepth _com _momentum _kinetic _potential _normalGravity _gravityX _gravityZ
  use strict arg time,volume,mass,minDepth,maxDepth,centreOfMassLocal,relativeMomentum,kineticEnergy,potentialEnergy,normalGravity,gravityX,gravityZ
  _time=time; _volume=volume; _mass=mass; _minDepth=minDepth; _maxDepth=maxDepth; _com=centreOfMassLocal
  _momentum=relativeMomentum; _kinetic=kineticEnergy; _potential=potentialEnergy
  _normalGravity=normalGravity; _gravityX=gravityX; _gravityZ=gravityZ
::method time; expose _time; return _time
::method timeQuantity; return .Units~q(self~time,.Units~second)
::method volume; expose _volume; return _volume
::method volumeQuantity; return .Units~q(self~volume,.Units~cubicMetre)
::method mass; expose _mass; return _mass
::method massQuantity; return .Units~q(self~mass,.Units~kilogram)
::method minDepth; expose _minDepth; return _minDepth
::method maxDepth; expose _maxDepth; return _maxDepth
::method minDepthQuantity; return .Units~q(self~minDepth,.Units~metre)
::method maxDepthQuantity; return .Units~q(self~maxDepth,.Units~metre)
::method surfaceRange; return self~maxDepth-self~minDepth
::method surfaceAmplitude; return self~surfaceRange/2
::method centreOfMassLocal; expose _com; return _com
::method relativeMomentum; expose _momentum; return _momentum
::method kineticEnergy; expose _kinetic; return _kinetic
::method potentialEnergy; expose _potential; return _potential
::method totalEnergy; return self~kineticEnergy+self~potentialEnergy
::method kineticEnergyQuantity; return .Units~q(self~kineticEnergy,.Units~joule)
::method potentialEnergyQuantity; return .Units~q(self~potentialEnergy,.Units~joule)
::method totalEnergyQuantity; return .Units~q(self~totalEnergy,.Units~joule)
::method normalGravity; expose _normalGravity; return _normalGravity
::method gravityX; expose _gravityX; return _gravityX
::method gravityZ; expose _gravityZ; return _gravityZ

::class FreeSurfaceVesselLoadReport2D public
::method init
  expose _force _torque _left _right _near _far _com _mass _normalGravity
  use strict arg localForce,localTorque,leftWallForce,rightWallForce,nearWallForce,farWallForce,centreOfMassLocal,mass,normalGravity
  _force=localForce; _torque=localTorque; _left=leftWallForce; _right=rightWallForce
  _near=nearWallForce; _far=farWallForce; _com=centreOfMassLocal; _mass=mass; _normalGravity=normalGravity
::method localForce; expose _force; return _force
::method localTorque; expose _torque; return _torque
::method forceMagnitudeQuantity; return .Units~q(self~localForce~norm,.Units~newton)
::method torqueMagnitudeQuantity; return .Units~q(self~localTorque~norm,.Units~newton*.Units~metre)
::method leftWallForce; expose _left; return _left
::method rightWallForce; expose _right; return _right
::method nearWallForce; expose _near; return _near
::method farWallForce; expose _far; return _far
::method centreOfMassLocal; expose _com; return _com
::method mass; expose _mass; return _mass
::method normalGravity; expose _normalGravity; return _normalGravity

::class RectangularTankSlosh2D public
::method init
  expose _medium _tank _volume _mass _meanDepth _h _qx _qz _time _damping _cfl _minDepth _normalGravity _gravityX _gravityZ
  use strict arg fluidMedium,tankGeometry,fillVolume,dampingRate=0,cfl='0.35',minimumDepth='0.000001'
  numeric digits 50
  fillVolume=.FluidUnitBoundary~scalar(fillVolume,.Units~cubicMetre~dimension,'2D free-surface fill volume')
  dampingRate=.FluidUnitBoundary~scalar(dampingRate,.Units~hertz~dimension,'2D free-surface damping rate')
  minimumDepth=.FluidUnitBoundary~scalar(minimumDepth,.UnitDimension~length,'2D free-surface minimum depth')
  cfl=.FluidUnitBoundary~scalar(cfl,.UnitDimension~dimensionless,'2D free-surface CFL')
  if fillVolume<=0 then raise syntax 88.900 array('positive 2D free-surface fill volume',fillVolume)
  if fillVolume>=tankGeometry~capacity then raise syntax 88.900 array('2D fill volume below tank capacity for a free surface',fillVolume)
  if dampingRate<0 then raise syntax 88.900 array('non-negative 2D free-surface damping rate',dampingRate)
  if cfl<=0 | cfl>='0.9' then raise syntax 88.900 array('2D free-surface CFL in (0,0.9)',cfl)
  if minimumDepth<=0 then raise syntax 88.900 array('positive 2D free-surface minimum depth',minimumDepth)
  meanDepth=fillVolume/(tankGeometry~length*tankGeometry~width)
  if meanDepth<=minimumDepth then raise syntax 88.900 array('2D mean liquid depth above minimum depth',meanDepth)
  if meanDepth>=tankGeometry~height then raise syntax 88.900 array('2D mean liquid depth below tank rim',meanDepth)
  _medium=fluidMedium; _tank=tankGeometry; _volume=fillVolume; _mass=fluidMedium~density*fillVolume; _meanDepth=meanDepth
  _damping=dampingRate; _cfl=cfl; _minDepth=minimumDepth; _time=0
  _normalGravity='9.80665'; _gravityX=0; _gravityZ=0
  n=tankGeometry~cellCount
  _h=.array~new(n); _qx=.array~new(n); _qz=.array~new(n)
  do k=1 to n; _h[k]=meanDepth; _qx[k]=0; _qz[k]=0; end
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
::method gravityX; expose _gravityX; return _gravityX
::method gravityZ; expose _gravityZ; return _gravityZ
::method index private
  expose _tank
  use strict arg i,j
  if i<1 | i>_tank~xCells | j<1 | j>_tank~zCells then raise syntax 88.900 array('2D slosh cell index in range',i j)
  return (j-1)*_tank~xCells+i
::method depthAtCell
  expose _h
  use strict arg i,j
  return _h[self~index(i,j)]
::method dischargeXAtCell
  expose _qx
  use strict arg i,j
  return _qx[self~index(i,j)]
::method dischargeZAtCell
  expose _qz
  use strict arg i,j
  return _qz[self~index(i,j)]
::method velocityXAtCell
  use strict arg i,j
  return self~dischargeXAtCell(i,j)/self~depthAtCell(i,j)
::method velocityZAtCell
  use strict arg i,j
  return self~dischargeZAtCell(i,j)/self~depthAtCell(i,j)
::method resetFlat
  expose _h _qx _qz _meanDepth _tank _time _normalGravity _gravityX _gravityZ
  do k=1 to _tank~cellCount; _h[k]=_meanDepth; _qx[k]=0; _qz[k]=0; end
  _time=0; _normalGravity='9.80665'; _gravityX=0; _gravityZ=0
  return self
::method seedStandingMode
  expose _h _qx _qz _meanDepth _tank
  use strict arg amplitudeX=0,amplitudeZ=0
  numeric digits 50
  amplitudeX=.FluidUnitBoundary~scalar(amplitudeX,.UnitDimension~length,'2D x mode amplitude')
  amplitudeZ=.FluidUnitBoundary~scalar(amplitudeZ,.UnitDimension~length,'2D z mode amplitude')
  if amplitudeX<0 | amplitudeZ<0 then raise syntax 88.900 array('non-negative 2D standing mode amplitudes',amplitudeX amplitudeZ)
  pi=4*RxCalcArcTan(1,40,'R')
  candidate=.array~new(_tank~cellCount); total=0
  do j=1 to _tank~zCells
    z=_tank~zCentre(j)
    do i=1 to _tank~xCells
      x=_tank~xCentre(i); k=self~index(i,j)
      candidate[k]=_meanDepth + amplitudeX*RxCalcSin(pi*x/_tank~length,40,'R') + amplitudeZ*RxCalcSin(pi*z/_tank~width,40,'R')
      total=total+candidate[k]
    end
  end
  correction=total/_tank~cellCount-_meanDepth
  do k=1 to _tank~cellCount; candidate[k]=candidate[k]-correction; end
  self~validateDepthArray(candidate,'2D standing-mode seed')
  _h=candidate
  do k=1 to _tank~cellCount; _qx[k]=0; _qz[k]=0; end
  return self
::method minSurfaceDepth
  expose _h _tank
  m=_h[1]
  do k=2 to _tank~cellCount; if _h[k]<m then m=_h[k]; end
  return m
::method maxSurfaceDepth
  expose _h _tank
  m=_h[1]
  do k=2 to _tank~cellCount; if _h[k]>m then m=_h[k]; end
  return m
::method surfaceRange; return self~maxSurfaceDepth-self~minSurfaceDepth
::method surfaceAmplitude; return self~surfaceRange/2
::method currentVolume
  expose _h _tank
  numeric digits 50
  sum=0
  do k=1 to _tank~cellCount; sum=sum+_h[k]; end
  return sum*_tank~cellArea
::method currentMass
  expose _medium
  numeric digits 50
  return _medium~density*self~currentVolume
::method centreOfMassLocal
  expose _h _tank
  use strict arg context=.nil
  numeric digits 50
  if context==.nil then context=.Maths~defaultContext
  volume=self~currentVolume; sx=0; sy=0; sz=0; area=_tank~cellArea
  do j=1 to _tank~zCells
    z=_tank~zCentre(j)
    do i=1 to _tank~xCells
      x=_tank~xCentre(i); h=self~depthAtCell(i,j)
      dv=h*area
      sx=sx+x*dv; sz=sz+z*dv; sy=sy+(h/2)*dv
    end
  end
  return .MathVector3~new(sx/volume,sy/volume,sz/volume,context)
::method relativeMomentum
  expose _h _qx _qz _tank _medium
  use strict arg context=.nil
  numeric digits 50
  if context==.nil then context=.Maths~defaultContext
  px=0; pz=0; area=_tank~cellArea
  do k=1 to _tank~cellCount
    px=px+_medium~density*_qx[k]*area
    pz=pz+_medium~density*_qz[k]*area
  end
  return .MathVector3~new(px,0,pz,context)
::method kineticEnergy
  expose _h _qx _qz _tank _medium
  numeric digits 50
  e=0; area=_tank~cellArea
  do k=1 to _tank~cellCount
    h=_h[k]; u=_qx[k]/h; w=_qz[k]/h
    e=e+_medium~density*h*(u*u+w*w)*area/2
  end
  return e
::method potentialEnergy
  expose _h _tank _medium _normalGravity
  numeric digits 50
  e=0; area=_tank~cellArea
  do k=1 to _tank~cellCount; e=e+_medium~density*_normalGravity*_h[k]*_h[k]*area/2; end
  return e
::method kineticEnergyQuantity; return .Units~q(self~kineticEnergy,.Units~joule)
::method potentialEnergyQuantity; return .Units~q(self~potentialEnergy,.Units~joule)
::method totalMechanicalEnergy; return self~kineticEnergy+self~potentialEnergy
::method totalMechanicalEnergyQuantity; return .Units~q(self~totalMechanicalEnergy,.Units~joule)
::method relativeMomentumQuantity; return .Units~q(self~relativeMomentum,.Units~kilogram*.Units~metrePerSecond)
::method fundamentalAngularFrequencyX
  expose _normalGravity _meanDepth _tank
  numeric digits 50
  pi=4*RxCalcArcTan(1,40,'R')
  return pi*RxCalcSqrt(_normalGravity*_meanDepth,40)/_tank~length
::method fundamentalAngularFrequencyZ
  expose _normalGravity _meanDepth _tank
  numeric digits 50
  pi=4*RxCalcArcTan(1,40,'R')
  return pi*RxCalcSqrt(_normalGravity*_meanDepth,40)/_tank~width
::method fundamentalPeriodX
  numeric digits 50
  pi=4*RxCalcArcTan(1,40,'R')
  return 2*pi/self~fundamentalAngularFrequencyX
::method fundamentalPeriodZ
  numeric digits 50
  pi=4*RxCalcArcTan(1,40,'R')
  return 2*pi/self~fundamentalAngularFrequencyZ
::method fundamentalPeriodXQuantity; return .Units~q(self~fundamentalPeriodX,.Units~second)
::method fundamentalPeriodZQuantity; return .Units~q(self~fundamentalPeriodZ,.Units~second)
::method freeSurfacePointsLocal
  expose _tank
  use strict arg context=.nil
  if context==.nil then context=.Maths~defaultContext
  points=.array~new
  do j=1 to _tank~zCells
    z=_tank~zCentre(j)
    do i=1 to _tank~xCells
      points~append(.MathVector3~new(_tank~xCentre(i),self~depthAtCell(i,j),z,context))
    end
  end
  return points
::method validateDepthArray private
  expose _tank _minDepth
  use strict arg depths,label='2D free-surface state'
  minD=depths[1]; maxD=depths[1]
  do k=2 to _tank~cellCount
    if depths[k]<minD then minD=depths[k]
    if depths[k]>maxD then maxD=depths[k]
  end
  if minD<=_minDepth then raise syntax 93.900 array(label 'would create a dry/near-dry cell; dry-front physics is not implemented',minD)
  if maxD>=_tank~height then raise syntax 93.900 array(label 'reaches the tank rim; spill/overflow physics is not implemented',maxD)
  return .true
::method maxStableTimeStep
  expose _h _qx _qz _tank _cfl
  use strict arg normalGravity=.nil
  numeric digits 50
  if normalGravity==.nil then normalGravity=self~normalGravity
  normalGravity=.FluidUnitBoundary~scalar(normalGravity,.Units~metrePerSecondSquared~dimension,'2D free-surface normal gravity')
  if normalGravity<=0 then raise syntax 93.900 array('positive normal effective gravity for 2D shallow-water step',normalGravity)
  worst=0
  do k=1 to _tank~cellCount
    h=_h[k]; c=RxCalcSqrt(normalGravity*h,40); u=abs(_qx[k]/h); w=abs(_qz[k]/h)
    rate=(u+c)/_tank~dx+(w+c)/_tank~dz
    if rate>worst then worst=rate
  end
  if worst<='0.000000000000001' then return '1E99'
  return _cfl/worst
::method fluxX private
  use strict arg hL,qxL,qzL,hR,qxR,qzR,g
  numeric digits 50
  uL=qxL/hL; uR=qxR/hR; wL=qzL/hL; wR=qzR/hR
  cL=RxCalcSqrt(g*hL,40); cR=RxCalcSqrt(g*hR,40)
  s=abs(uL)+cL; t=abs(uR)+cR; if t>s then s=t
  fh=(qxL+qxR)/2-s*(hR-hL)/2
  fqx=(qxL*uL+g*hL*hL/2 + qxR*uR+g*hR*hR/2)/2-s*(qxR-qxL)/2
  fqz=(qxL*wL+qxR*wR)/2-s*(qzR-qzL)/2
  return .array~of(fh,fqx,fqz)
::method fluxZ private
  use strict arg hL,qxL,qzL,hR,qxR,qzR,g
  numeric digits 50
  uL=qxL/hL; uR=qxR/hR; wL=qzL/hL; wR=qzR/hR
  cL=RxCalcSqrt(g*hL,40); cR=RxCalcSqrt(g*hR,40)
  s=abs(wL)+cL; t=abs(wR)+cR; if t>s then s=t
  fh=(qzL+qzR)/2-s*(hR-hL)/2
  fqx=(qzL*uL+qzR*uR)/2-s*(qxR-qxL)/2
  fqz=(qzL*wL+g*hL*hL/2 + qzR*wR+g*hR*hR/2)/2-s*(qzR-qzL)/2
  return .array~of(fh,fqx,fqz)
::method step
  expose _h _qx _qz _tank _damping _time _normalGravity _gravityX _gravityZ
  use strict arg dt,effectiveGravityX=0,effectiveGravityZ=0,normalEffectiveGravity='9.80665'
  numeric digits 50
  dt=.FluidUnitBoundary~scalar(dt,.UnitDimension~time,'2D free-surface timestep')
  effectiveGravityX=.FluidUnitBoundary~scalar(effectiveGravityX,.Units~metrePerSecondSquared~dimension,'2D free-surface x effective gravity')
  effectiveGravityZ=.FluidUnitBoundary~scalar(effectiveGravityZ,.Units~metrePerSecondSquared~dimension,'2D free-surface z effective gravity')
  normalEffectiveGravity=.FluidUnitBoundary~scalar(normalEffectiveGravity,.Units~metrePerSecondSquared~dimension,'2D free-surface normal effective gravity')
  if dt<=0 then raise syntax 88.900 array('positive 2D free-surface timestep',dt)
  if normalEffectiveGravity<=0 then raise syntax 93.900 array('2D free-surface model requires liquid retained against the tank floor',normalEffectiveGravity)
  stable=self~maxStableTimeStep(normalEffectiveGravity)
  if dt>stable then raise syntax 93.900 array('2D free-surface timestep exceeds explicit CFL limit',dt stable)
  nx=_tank~xCells; nz=_tank~zCells
  /* x-face flux arrays: (nx+1)*nz */
  nfx=(nx+1)*nz; nfz=nx*(nz+1)
  fxH=.array~new(nfx); fxQx=.array~new(nfx); fxQz=.array~new(nfx)
  fzH=.array~new(nfz); fzQx=.array~new(nfz); fzQz=.array~new(nfz)
  do j=1 to nz
    do iface=1 to nx+1
      if iface=1 then do
        k=self~index(1,j); hL=_h[k]; qxL=-_qx[k]; qzL=_qz[k]; hR=_h[k]; qxR=_qx[k]; qzR=_qz[k]
      end
      else if iface=nx+1 then do
        k=self~index(nx,j); hL=_h[k]; qxL=_qx[k]; qzL=_qz[k]; hR=_h[k]; qxR=-_qx[k]; qzR=_qz[k]
      end
      else do
        kl=self~index(iface-1,j); kr=self~index(iface,j)
        hL=_h[kl]; qxL=_qx[kl]; qzL=_qz[kl]; hR=_h[kr]; qxR=_qx[kr]; qzR=_qz[kr]
      end
      f=self~fluxX(hL,qxL,qzL,hR,qxR,qzR,normalEffectiveGravity)
      fi=(j-1)*(nx+1)+iface; fxH[fi]=f[1]; fxQx[fi]=f[2]; fxQz[fi]=f[3]
    end
  end
  do jface=1 to nz+1
    do i=1 to nx
      if jface=1 then do
        k=self~index(i,1); hL=_h[k]; qxL=_qx[k]; qzL=-_qz[k]; hR=_h[k]; qxR=_qx[k]; qzR=_qz[k]
      end
      else if jface=nz+1 then do
        k=self~index(i,nz); hL=_h[k]; qxL=_qx[k]; qzL=_qz[k]; hR=_h[k]; qxR=_qx[k]; qzR=-_qz[k]
      end
      else do
        kl=self~index(i,jface-1); kr=self~index(i,jface)
        hL=_h[kl]; qxL=_qx[kl]; qzL=_qz[kl]; hR=_h[kr]; qxR=_qx[kr]; qzR=_qz[kr]
      end
      f=self~fluxZ(hL,qxL,qzL,hR,qxR,qzR,normalEffectiveGravity)
      fi=(jface-1)*nx+i; fzH[fi]=f[1]; fzQx[fi]=f[2]; fzQz[fi]=f[3]
    end
  end
  nextH=.array~new(_tank~cellCount); nextQx=.array~new(_tank~cellCount); nextQz=.array~new(_tank~cellCount)
  rx=dt/_tank~dx; rz=dt/_tank~dz
  do j=1 to nz
    do i=1 to nx
      k=self~index(i,j)
      fl=(j-1)*(nx+1)+i; fr=fl+1
      fn=(j-1)*nx+i; ff=fn+nx
      h=_h[k]; qx=_qx[k]; qz=_qz[k]
      nextH[k]=h-rx*(fxH[fr]-fxH[fl])-rz*(fzH[ff]-fzH[fn])
      sx=h*effectiveGravityX-_damping*qx
      sz=h*effectiveGravityZ-_damping*qz
      nextQx[k]=qx-rx*(fxQx[fr]-fxQx[fl])-rz*(fzQx[ff]-fzQx[fn])+dt*sx
      nextQz[k]=qz-rx*(fxQz[fr]-fxQz[fl])-rz*(fzQz[ff]-fzQz[fn])+dt*sz
    end
  end
  self~validateDepthArray(nextH,'2D free-surface step')
  _h=nextH; _qx=nextQx; _qz=nextQz; _time=_time+dt
  _normalGravity=normalEffectiveGravity; _gravityX=effectiveGravityX; _gravityZ=effectiveGravityZ
  return self
::method drainVolumeFromCell
  expose _h _qx _qz _tank _medium _volume _mass _meanDepth
  use strict arg i,j,requestedVolume
  numeric digits 50
  requestedVolume=.FluidUnitBoundary~scalar(requestedVolume,.Units~cubicMetre~dimension,'2D free-surface requested drained volume')
  if requestedVolume<0 then raise syntax 88.900 array('non-negative 2D drained volume',requestedVolume)
  if requestedVolume=0 then return 0
  k=self~index(i,j); area=_tank~cellArea
  available=(_h[k]-self~minimumDepth)*area
  if available<=0 then return 0
  removed=requestedVolume
  if removed>available then removed=available
  oldH=_h[k]; newH=oldH-removed/area
  scale=newH/oldH
  _h[k]=newH
  /* Remove the same fraction of depth-integrated momentum as liquid volume,
     preserving the velocity of the retained liquid in this cell. */
  _qx[k]=_qx[k]*scale; _qz[k]=_qz[k]*scale
  _volume=self~currentVolume; _mass=_medium~density*_volume
  _meanDepth=_volume/(_tank~length*_tank~width)
  return removed
::method drainVolumeFromCellQuantity
  use strict arg i,j,requestedVolume
  return .Units~q(self~drainVolumeFromCell(i,j,requestedVolume),.Units~cubicMetre)
::method snapshot
  expose _time _normalGravity _gravityX _gravityZ
  return .FreeSurfaceSnapshot2D~new(_time,self~currentVolume,self~currentMass,self~minSurfaceDepth,self~maxSurfaceDepth, -
    self~centreOfMassLocal,self~relativeMomentum,self~kineticEnergy,self~potentialEnergy,_normalGravity,_gravityX,_gravityZ)
::method reactionReport
  expose _tank _medium
  use strict arg normalEffectiveGravity=.nil,context=.nil
  numeric digits 50
  if normalEffectiveGravity==.nil then normalEffectiveGravity=self~normalGravity
  normalEffectiveGravity=.FluidUnitBoundary~scalar(normalEffectiveGravity,.Units~metrePerSecondSquared~dimension,'2D free-surface reaction normal gravity')
  if normalEffectiveGravity<=0 then raise syntax 93.900 array('positive normal effective gravity for 2D free-surface reaction',normalEffectiveGravity)
  if context==.nil then context=.Maths~defaultContext
  rho=_medium~density; dx=_tank~dx; dz=_tank~dz; nx=_tank~xCells; nz=_tank~zCells
  left=0; right=0; near=0; far=0
  torque=.MathVector3~new(0,0,0,context)
  do j=1 to nz
    z=_tank~zCentre(j)
    h=self~depthAtCell(1,j); f=rho*normalEffectiveGravity*h*h*dz/2; left=left+f
    point=.MathVector3~new(-_tank~length/2,h/3,z,context); force=.MathVector3~new(-f,0,0,context); torque=torque+point~cross(force)
    h=self~depthAtCell(nx,j); f=rho*normalEffectiveGravity*h*h*dz/2; right=right+f
    point=.MathVector3~new(_tank~length/2,h/3,z,context); force=.MathVector3~new(f,0,0,context); torque=torque+point~cross(force)
  end
  do i=1 to nx
    x=_tank~xCentre(i)
    h=self~depthAtCell(i,1); f=rho*normalEffectiveGravity*h*h*dx/2; near=near+f
    point=.MathVector3~new(x,h/3,-_tank~width/2,context); force=.MathVector3~new(0,0,-f,context); torque=torque+point~cross(force)
    h=self~depthAtCell(i,nz); f=rho*normalEffectiveGravity*h*h*dx/2; far=far+f
    point=.MathVector3~new(x,h/3,_tank~width/2,context); force=.MathVector3~new(0,0,f,context); torque=torque+point~cross(force)
  end
  mass=self~currentMass; fy=-mass*normalEffectiveGravity; com=self~centreOfMassLocal(context)
  floorPoint=.MathVector3~new(com~x,0,com~z,context); floorForce=.MathVector3~new(0,fy,0,context)
  torque=torque+floorPoint~cross(floorForce)
  force=.MathVector3~new(right-left,fy,far-near,context)
  return .FreeSurfaceVesselLoadReport2D~new(force,torque,left,right,near,far,com,mass,normalEffectiveGravity)

::class FreeSurfaceVesselCoupling2D public
::method init
  expose _slosh _body _localX _localZ _localUp _origin _previousVelocity _lastAcceleration _lastEffectiveGravity _lastReport
  use strict arg sloshModel,rigidBodyState,localLongitudinalAxis=.nil,localLateralAxis=.nil,localUpAxis=.nil,tankOriginLocal=.nil
  ctx=rigidBodyState~body~pose~context
  if localLongitudinalAxis==.nil then localLongitudinalAxis=.MathVector3~new(1,0,0,ctx)
  if localLateralAxis==.nil then localLateralAxis=.MathVector3~new(0,0,1,ctx)
  if localUpAxis==.nil then localUpAxis=.MathVector3~new(0,1,0,ctx)
  if tankOriginLocal==.nil then tankOriginLocal=.MathVector3~new(0,0,0,ctx)
  _localX=localLongitudinalAxis~normalized; _localZ=localLateralAxis~normalized; _localUp=localUpAxis~normalized; _origin=tankOriginLocal
  if abs(_localX~dot(_localZ))>'0.000001' | abs(_localX~dot(_localUp))>'0.000001' | abs(_localZ~dot(_localUp))>'0.000001' then -
    raise syntax 93.900 array('2D free-surface vessel axes must be mutually orthogonal')
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
  pose=_body~body~pose; local=_slosh~freeSurfacePointsLocal(pose~context); world=.array~new
  do p over local; world~append(pose~pointToWorld(_origin+p)); end
  return world
::method advanceKinematics
  expose _slosh _body _localX _localZ _localUp _lastAcceleration _lastEffectiveGravity
  use strict arg dt,bodyAccelerationWorld,gravityWorld
  dt=.FluidUnitBoundary~scalar(dt,.UnitDimension~time,'2D free-surface vessel kinematic timestep')
  if dt<=0 then raise syntax 88.900 array('positive 2D free-surface vessel kinematic timestep',dt)
  pose=_body~body~pose; accelLocal=pose~vectorToLocal(bodyAccelerationWorld); gravityLocal=pose~vectorToLocal(gravityWorld)
  geff=gravityLocal-accelLocal; gx=geff~dot(_localX); gz=geff~dot(_localZ); normal=-geff~dot(_localUp)
  if normal<=0 then raise syntax 93.900 array('2D free-surface vessel coupling lost bottom contact; ballistic/inverted free surface is not implemented',normal)
  _slosh~step(dt,gx,gz,normal); _lastAcceleration=bodyAccelerationWorld; _lastEffectiveGravity=geff
  return _slosh~snapshot
::method applyCurrentLoad
  expose _slosh _body _origin _lastEffectiveGravity _localUp _lastReport
  use strict arg normalEffectiveGravity=.nil
  pose=_body~body~pose
  if normalEffectiveGravity==.nil then do
    if _lastEffectiveGravity==.nil then raise syntax 93.900 array('2D free-surface coupling requires effective gravity before applying load')
    normalEffectiveGravity=-_lastEffectiveGravity~dot(_localUp)
  end
  report=_slosh~reactionReport(normalEffectiveGravity,pose~context)
  localTorqueAtBody=report~localTorque+_origin~cross(report~localForce)
  _body~applyForce(pose~vectorToWorld(report~localForce),_body~position)
  _body~applyTorque(pose~vectorToWorld(localTorqueAtBody))
  _lastReport=report
  return report
::method effectiveGravityLocal private
  expose _body _lastAcceleration
  use strict arg mechanicsSolver
  pose=_body~body~pose
  return pose~vectorToLocal(mechanicsSolver~gravity)-pose~vectorToLocal(_lastAcceleration)
::method beforeMechanicsStep
  expose _slosh _body _localUp _origin _lastEffectiveGravity _lastReport
  use strict arg mechanicsSolver,dt
  dt=.FluidUnitBoundary~scalar(dt,.UnitDimension~time,'2D free-surface vessel coupling timestep')
  if dt<=0 then raise syntax 88.900 array('positive 2D free-surface vessel coupling timestep',dt)
  pose=_body~body~pose; geff=self~effectiveGravityLocal(mechanicsSolver); normal=-geff~dot(_localUp)
  if normal<=0 then raise syntax 93.900 array('2D free-surface vessel coupling lost bottom contact; ballistic/inverted free surface is not implemented',normal)
  report=_slosh~reactionReport(normal,pose~context)
  _body~applyForce(pose~vectorToWorld(report~localForce),_body~position)
  _body~applyTorque(pose~vectorToWorld(report~localTorque+_origin~cross(report~localForce)))
  _lastEffectiveGravity=geff; _lastReport=report
  return report
::method afterMechanicsStep
  expose _slosh _body _localX _localZ _localUp _previousVelocity _lastAcceleration _lastEffectiveGravity
  use strict arg mechanicsSolver,dt
  dt=.FluidUnitBoundary~scalar(dt,.UnitDimension~time,'2D free-surface vessel coupling timestep')
  if dt<=0 then raise syntax 88.900 array('positive 2D free-surface vessel coupling timestep',dt)
  currentVelocity=_body~velocity; _lastAcceleration=(currentVelocity-_previousVelocity)*(1/dt); _previousVelocity=currentVelocity
  pose=_body~body~pose; geff=pose~vectorToLocal(mechanicsSolver~gravity)-pose~vectorToLocal(_lastAcceleration)
  gx=geff~dot(_localX); gz=geff~dot(_localZ); normal=-geff~dot(_localUp)
  if normal<=0 then raise syntax 93.900 array('2D free-surface vessel coupling lost bottom contact; ballistic/inverted free surface is not implemented',normal)
  _slosh~step(dt,gx,gz,normal); _lastEffectiveGravity=geff
  return _slosh~snapshot

::requires 'FreeSurfaceFluids.cls'
::requires 'rxmath' LIBRARY
