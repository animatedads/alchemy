/* ooRexx Physics World v0.1-dev7
   Classical rigid-body mechanics over the same PhysicalWorld body identity/pose
   used by geometric optics. Internal units are SI: m, kg, s, N, J and radians.
*/

::class MechanicsMassProperties public
::method init
  expose _mass _ix _iy _iz
  use strict arg massKg,ix,iy,iz
  if massKg<=0 then raise syntax 88.900 array('positive mass',massKg)
  if ix<=0 | iy<=0 | iz<=0 then raise syntax 88.900 array('positive principal inertia',ix iy iz)
  _mass=massKg; _ix=ix; _iy=iy; _iz=iz
::method mass; expose _mass; return _mass
::method ix; expose _ix; return _ix
::method iy; expose _iy; return _iy
::method iz; expose _iz; return _iz
::method pointMass class
  use strict arg massKg,radiusOfGyration='0.000001'
  i=massKg*radiusOfGyration*radiusOfGyration
  return self~new(massKg,i,i,i)
::method solidSphere class
  use strict arg massKg,radius
  i=(2*massKg*radius*radius)/5
  return self~new(massKg,i,i,i)
::method solidBox class
  use strict arg massKg,width,height,depth
  ix=massKg*(height*height+depth*depth)/12
  iy=massKg*(width*width+depth*depth)/12
  iz=massKg*(width*width+height*height)/12
  return self~new(massKg,ix,iy,iz)
::method solidCylinder class
  /* Principal axis is local Y. */
  use strict arg massKg,radius,height
  iy=massKg*radius*radius/2
  ix=massKg*(3*radius*radius+height*height)/12
  return self~new(massKg,ix,iy,ix)
::method hollowCylinder class
  /* Thick-walled cylindrical shell, principal axis local Y. */
  use strict arg massKg,innerRadius,outerRadius,height
  if innerRadius<0 | outerRadius<=innerRadius then raise syntax 88.900 array('0 <= inner radius < outer radius',innerRadius outerRadius)
  iy=massKg*(innerRadius*innerRadius+outerRadius*outerRadius)/2
  ix=massKg*(3*(innerRadius*innerRadius+outerRadius*outerRadius)+height*height)/12
  return self~new(massKg,ix,iy,ix)

::class RigidBodyState public
::method init
  expose _body _massProperties _velocity _angularVelocity _force _torque _fixed _restitution _sphereRadius _context
  use strict arg physicalBody,massProperties,velocity=.nil,angularVelocity=.nil,fixed=.false,restitution='0.2',sphereRadius=.nil
  _body=physicalBody; _massProperties=massProperties; _context=physicalBody~pose~context
  if velocity==.nil then velocity=.MathVector3~new(0,0,0,_context)
  if angularVelocity==.nil then angularVelocity=.MathVector3~new(0,0,0,_context)
  _velocity=velocity; _angularVelocity=angularVelocity
  _force=.MathVector3~new(0,0,0,_context); _torque=.MathVector3~new(0,0,0,_context)
  _fixed=fixed; _restitution=restitution; _sphereRadius=sphereRadius
::method body; expose _body; return _body
::method massProperties; expose _massProperties; return _massProperties
::method mass; return self~massProperties~mass
::method velocity; expose _velocity; return _velocity
::method 'velocity='; expose _velocity; use strict arg v; _velocity=v
::method angularVelocity; expose _angularVelocity; return _angularVelocity
::method 'angularVelocity='; expose _angularVelocity; use strict arg v; _angularVelocity=v
::method force; expose _force; return _force
::method torque; expose _torque; return _torque
::method fixed; expose _fixed; return _fixed
::method restitution; expose _restitution; return _restitution
::method sphereRadius; expose _sphereRadius; return _sphereRadius
::method position; return self~body~pose~position
::method orientation; return self~body~pose~orientation
::method momentum; return self~velocity*self~mass
::method kineticEnergy
  v2=self~velocity~dot(self~velocity)
  localOmega=self~body~pose~vectorToLocal(self~angularVelocity)
  rot=(self~massProperties~ix*localOmega~x*localOmega~x + self~massProperties~iy*localOmega~y*localOmega~y + self~massProperties~iz*localOmega~z*localOmega~z)/2
  return self~mass*v2/2 + rot
::method clearAccumulators
  expose _force _torque _context
  _force=.MathVector3~new(0,0,0,_context); _torque=.MathVector3~new(0,0,0,_context)
::method applyForce
  expose _force _torque
  use strict arg force,worldPoint=.nil
  if self~fixed then return self
  _force=_force+force
  if worldPoint<>.nil then _torque=_torque+(worldPoint-self~position)~cross(force)
  return self
::method applyTorque
  expose _torque
  use strict arg torque
  if \self~fixed then _torque=_torque+torque
  return self
::method applyImpulse
  use strict arg impulse,worldPoint=.nil
  if self~fixed then return self
  self~velocity=self~velocity+impulse*(1/self~mass)
  if worldPoint<>.nil then do
    angularImpulse=(worldPoint-self~position)~cross(impulse)
    self~angularVelocity=self~angularVelocity+self~angularAccelerationForTorque(angularImpulse)
  end
  return self
::method angularAccelerationForTorque
  use strict arg worldTorque
  localTorque=self~body~pose~vectorToLocal(worldTorque)
  localAlpha=.MathVector3~new(localTorque~x/self~massProperties~ix,localTorque~y/self~massProperties~iy,localTorque~z/self~massProperties~iz,self~body~pose~context)
  return self~body~pose~vectorToWorld(localAlpha)
::method integrate
  use strict arg dt,gravity
  if self~fixed then do; self~clearAccumulators; return; end
  accel=gravity+self~force*(1/self~mass)
  self~velocity=self~velocity+accel*dt
  p=self~position+self~velocity*dt
  alpha=self~angularAccelerationForTorque(self~torque)
  self~angularVelocity=self~angularVelocity+alpha*dt
  q=.MechanicsKinematics~advanceOrientation(self~orientation,self~angularVelocity,dt,self~body~pose~context)
  self~body~pose=.PhysicalPose~new(p,q,self~body~pose~context)
  self~clearAccumulators

::class MechanicsKinematics public
::method advanceOrientation class
  use strict arg orientation,omega,dt,context=.nil
  if context==.nil then context=omega~context
  speed=omega~norm
  if speed<'0.000000000000001' | dt=0 then return orientation
  axis=omega*(1/speed)
  half=speed*dt/2
  c=RxCalcCos(half,30,'R'); s=RxCalcSin(half,30,'R')
  dq=.MathQuaternion~new(c,axis~x*s,axis~y*s,axis~z*s,context)
  return (dq*orientation)~normalized
::method directionDegreesXY class
  use strict arg vector
  if vector~x=0 & vector~y=0 then raise syntax 88.900 array('non-zero x/y direction','zero vector')
  pi=4*RxCalcArcTan(1,30,'R'); x=vector~x; y=vector~y
  if x>0 then a=RxCalcArcTan(y/x,30,'R')
  else if x<0 & y>=0 then a=RxCalcArcTan(y/x,30,'R')+pi
  else if x<0 & y<0 then a=RxCalcArcTan(y/x,30,'R')-pi
  else if y>0 then a=pi/2
  else a=-pi/2
  return a*180/pi

::class SpringConstraint public
::method init
  expose _a _b _anchorA _anchorB _restLength _stiffness _damping
  use strict arg bodyA,bodyB,restLength,stiffness,damping=0,anchorALocal=.nil,anchorBLocal=.nil
  _a=bodyA; _b=bodyB; _restLength=restLength; _stiffness=stiffness; _damping=damping
  ctx=bodyA~body~pose~context
  if anchorALocal==.nil then anchorALocal=.MathVector3~new(0,0,0,ctx)
  if anchorBLocal==.nil then anchorBLocal=.MathVector3~new(0,0,0,ctx)
  _anchorA=anchorALocal; _anchorB=anchorBLocal
::method bodyA; expose _a; return _a
::method bodyB; expose _b; return _b
::method restLength; expose _restLength; return _restLength
::method stiffness; expose _stiffness; return _stiffness
::method damping; expose _damping; return _damping
::method anchorA; expose _anchorA; return _anchorA
::method anchorB; expose _anchorB; return _anchorB
::method apply
  a=self~bodyA; b=self~bodyB
  pa=a~body~pose~pointToWorld(self~anchorA); pb=b~body~pose~pointToWorld(self~anchorB)
  delta=pb-pa; length=delta~norm
  if length<'0.000000000001' then return
  dir=delta*(1/length)
  va=a~velocity+a~angularVelocity~cross(pa-a~position)
  vb=b~velocity+b~angularVelocity~cross(pb-b~position)
  extension=length-self~restLength
  rel=(vb-va)~dot(dir)
  magnitude=self~stiffness*extension+self~damping*rel
  f=dir*magnitude
  a~applyForce(f,pa); b~applyForce(f*(-1),pb)


::class MechanicsContactEvent public
::method init
  expose _kind _bodyA _bodyB _point _normal _impulseA _impulseB _preNormalVelocity _postNormalVelocity _dissipatedEnergy _time
  use strict arg kind,bodyA,bodyB,point,normal,impulseOnA,impulseOnB,preNormalVelocity,postNormalVelocity,dissipatedEnergy,timeSeconds
  _kind=kind~upper; _bodyA=bodyA; _bodyB=bodyB; _point=point; _normal=normal~normalized
  _impulseA=impulseOnA; _impulseB=impulseOnB
  _preNormalVelocity=preNormalVelocity; _postNormalVelocity=postNormalVelocity
  _dissipatedEnergy=dissipatedEnergy; _time=timeSeconds
::method kind; expose _kind; return _kind
::method bodyA; expose _bodyA; return _bodyA
::method bodyB; expose _bodyB; return _bodyB
::method point; expose _point; return _point
::method normal; expose _normal; return _normal
::method impulseOnA; expose _impulseA; return _impulseA
::method impulseOnB; expose _impulseB; return _impulseB
::method impulseOnAQuantity; return .Units~q(self~impulseOnA,.Units~newtonSecond)
::method impulseOnBQuantity
  if self~impulseOnB==.nil then return .nil
  return .Units~q(self~impulseOnB,.Units~newtonSecond)
::method impulseFor
  use strict arg rigidBodyState
  if rigidBodyState==self~bodyA then return self~impulseOnA
  if rigidBodyState==self~bodyB then return self~impulseOnB
  return .nil
::method impulseQuantityFor
  use strict arg rigidBodyState
  v=self~impulseFor(rigidBodyState)
  if v==.nil then return .nil
  return .Units~q(v,.Units~newtonSecond)
::method impulseMagnitude
  return self~impulseOnA~norm
::method impulseMagnitudeQuantity; return .Units~q(self~impulseMagnitude,.Units~newtonSecond)
::method preNormalVelocity; expose _preNormalVelocity; return _preNormalVelocity
::method preNormalVelocityQuantity; return .Units~q(self~preNormalVelocity,.Units~metrePerSecond)
::method postNormalVelocity; expose _postNormalVelocity; return _postNormalVelocity
::method postNormalVelocityQuantity; return .Units~q(self~postNormalVelocity,.Units~metrePerSecond)
::method dissipatedEnergy; expose _dissipatedEnergy; return _dissipatedEnergy
::method dissipatedEnergyQuantity; return .Units~q(self~dissipatedEnergy,.Units~joule)
::method time; expose _time; return _time
::method 'time='
  expose _time
  use strict arg value
  if value~isA(.UnitQuantity) then do
    if \value~dimension~compatible(.UnitDimension~time) then raise syntax 93.900 array('mechanics time has incompatible physical dimension')
    value=value~canonicalValue
  end
  if value<0 then raise syntax 88.900 array('non-negative mechanics time',value)
  _time=value
::method timeQuantity; return .Units~q(self~time,.Units~second)

::class CollisionPlane public
::method init
  expose _point _normal _restitution
  use strict arg point,normal,restitution='0.2'
  _point=point; _normal=normal~normalized; _restitution=restitution
::method point; expose _point; return _point
::method normal; expose _normal; return _normal
::method restitution; expose _restitution; return _restitution

::class MechanicsSolver public
::method init
  expose _world _bodies _springs _planes _gravity _iterations _time _contactEvents
  use strict arg physicalWorld,gravity=.nil,collisionIterations=4,startTime=0
  if startTime~isA(.UnitQuantity) then do
    if \startTime~dimension~compatible(.UnitDimension~time) then raise syntax 93.900 array('mechanics start time has incompatible physical dimension')
    startTime=startTime~canonicalValue
  end
  if startTime<0 then raise syntax 88.900 array('non-negative mechanics start time',startTime)
  _world=physicalWorld; _bodies=.array~new; _springs=.array~new; _planes=.array~new; _iterations=collisionIterations
  _time=startTime; _contactEvents=.array~new
  if gravity==.nil then gravity=.MathVector3~new(0,'-9.80665',0,.Maths~defaultContext)
  _gravity=gravity
::method world; expose _world; return _world
::method gravity; expose _gravity; return _gravity
::method 'gravity='; expose _gravity; use strict arg g; _gravity=g
::method bodies; expose _bodies; return _bodies~copy
::method addBody; expose _bodies; use strict arg body; _bodies~append(body); return body
::method addSpring; expose _springs; use strict arg spring; _springs~append(spring); return spring
::method addPlane; expose _planes; use strict arg plane; _planes~append(plane); return plane
::method planes; expose _planes; return _planes~copy
::method recordContactEvent
  expose _contactEvents
  use strict arg event
  _contactEvents~append(event)
  return event
::method time; expose _time; return _time
::method timeQuantity; return .Units~q(self~time,.Units~second)
::method contactEvents; expose _contactEvents; return _contactEvents~copy
::method totalMomentum
  expose _bodies
  if _bodies~items=0 then return .MathVector3~new(0,0,0,.Maths~defaultContext)
  total=.MathVector3~new(0,0,0,_bodies[1]~body~pose~context)
  do b over _bodies; if \b~fixed then total=total+b~momentum; end
  return total
::method totalKineticEnergy
  expose _bodies
  e=0; do b over _bodies; if \b~fixed then e=e+b~kineticEnergy; end; return e
::method step
  expose _bodies _springs _gravity _iterations _time _contactEvents
  use strict arg dt
  if dt~isA(.UnitQuantity) then do
    if \dt~dimension~compatible(.UnitDimension~time) then raise syntax 93.900 array('mechanics timestep has incompatible physical dimension')
    dt=dt~canonicalValue
  end
  if dt<=0 then raise syntax 88.900 array('positive mechanics timestep',dt)
  _contactEvents=.array~new
  do spring over _springs; spring~apply; end
  do b over _bodies; b~integrate(dt,_gravity); end
  _time=_time+dt
  do i=1 to _iterations
    self~solvePlanes
    self~solveSpheres
  end
::method solvePlanes
  expose _bodies _planes _contactEvents _time
  do b over _bodies
    if b~fixed | b~sphereRadius==.nil then iterate
    do p over _planes
      signed=(b~position-p~point)~dot(p~normal)-b~sphereRadius
      if signed<0 then do
        b~body~pose=.PhysicalPose~new(b~position-p~normal*signed,b~orientation,b~body~pose~context)
        vn=b~velocity~dot(p~normal)
        if vn<0 then do
          e=b~restitution; if p~restitution<e then e=p~restitution
          preVn=vn
          jmag=-(1+e)*vn*b~mass
          impulse=p~normal*jmag
          contactPoint=b~position-p~normal*b~sphereRadius
          b~velocity=b~velocity+impulse*(1/b~mass)
          postVn=b~velocity~dot(p~normal)
          dissipated=b~mass*preVn*preVn*(1-e*e)/2
          zero=.MathVector3~new(0,0,0,b~body~pose~context)
          _contactEvents~append(.MechanicsContactEvent~new('PLANE',b,p,contactPoint,p~normal,impulse,zero,preVn,postVn,dissipated,_time))
        end
      end
    end
  end
::method solveSpheres
  expose _bodies _contactEvents _time
  n=_bodies~items
  do i=1 to n-1
    a=_bodies[i]
    if a~sphereRadius==.nil then iterate
    do j=i+1 to n
      b=_bodies[j]
      if b~sphereRadius==.nil | (a~fixed & b~fixed) then iterate
      delta=b~position-a~position; dist=delta~norm; minDist=a~sphereRadius+b~sphereRadius
      if dist>=minDist then iterate
      if dist<'0.000000000001' then nrm=.MathVector3~new(1,0,0,a~body~pose~context)
      else nrm=delta*(1/dist)
      penetration=minDist-dist; invA=0; invB=0
      if \a~fixed then invA=1/a~mass
      if \b~fixed then invB=1/b~mass
      invSum=invA+invB
      if invSum=0 then iterate
      if \a~fixed then a~body~pose=.PhysicalPose~new(a~position-nrm*(penetration*invA/invSum),a~orientation,a~body~pose~context)
      if \b~fixed then b~body~pose=.PhysicalPose~new(b~position+nrm*(penetration*invB/invSum),b~orientation,b~body~pose~context)
      rv=(b~velocity-a~velocity)~dot(nrm)
      if rv>=0 then iterate
      e=a~restitution; if b~restitution<e then e=b~restitution
      preRv=rv
      jimp=-(1+e)*rv/invSum; impulse=nrm*jimp
      impulseA=impulse*(-1); impulseB=impulse
      if \a~fixed then a~velocity=a~velocity+impulseA*invA
      if \b~fixed then b~velocity=b~velocity+impulseB*invB
      postRv=(b~velocity-a~velocity)~dot(nrm)
      reducedMass=1/invSum
      dissipated=reducedMass*preRv*preRv*(1-e*e)/2
      contactPoint=a~position+nrm*a~sphereRadius
      _contactEvents~append(.MechanicsContactEvent~new('SPHERE_SPHERE',a,b,contactPoint,nrm,impulseA,impulseB,preRv,postRv,dissipated,_time))
    end
  end

::requires 'PhysicsWorld.cls'
::requires 'rxmath' LIBRARY
