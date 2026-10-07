/* ooRexx Physics World v0.1-dev7
   General rigid contact helpers over Mechanics.cls.

   This module extends the original sphere-plane mechanics without replacing it.
   A rigid contact hull is an explicit set of local-space support/contact points.
   Plane contact resolves normal impulse using translational + rotational effective
   mass and optional constant Coulomb friction.  It is sufficient for finite bodies
   such as boxes/cylinders to tip, rebound and tumble on a plane without inventing
   an angle/alignment factor.
*/

::class ContactUnitBoundary
::method scalar class
  use strict arg value,expectedDimension,label
  numeric digits 50
  if value~isA(.UnitQuantity) then do
    if \value~dimension~compatible(expectedDimension) then -
      raise syntax 93.900 array(label 'has incompatible physical dimension')
    return value~canonicalValue+0
  end
  return value+0

::class RigidContactHull public
::method init
  expose _name _points
  use strict arg name,localPoints
  if localPoints~items<1 then raise syntax 88.900 array('at least one rigid contact point',localPoints~items)
  _name=name; _points=localPoints~copy
::method name; expose _name; return _name
::method localPoints; expose _points; return _points~copy
::method pointCount; expose _points; return _points~items
::method box class
  use strict arg width,height,depth,context=.nil
  width=.ContactUnitBoundary~scalar(width,.UnitDimension~length,'contact box width')
  height=.ContactUnitBoundary~scalar(height,.UnitDimension~length,'contact box height')
  depth=.ContactUnitBoundary~scalar(depth,.UnitDimension~length,'contact box depth')
  if width<=0 | height<=0 | depth<=0 then raise syntax 88.900 array('positive contact box dimensions',width height depth)
  if context==.nil then context=.Maths~defaultContext
  hx=width/2; hy=height/2; hz=depth/2
  pts=.array~new
  do sx over .array~of(-1,1)
    do sy over .array~of(-1,1)
      do sz over .array~of(-1,1)
        pts~append(.MathVector3~new(sx*hx,sy*hy,sz*hz,context))
      end
    end
  end
  return self~new('box-contact-hull',pts)
::method cylinder class
  /* Cylinder axis is local Y.  Ring points are used at each end. */
  use strict arg radius,height,segments=16,context=.nil
  radius=.ContactUnitBoundary~scalar(radius,.UnitDimension~length,'contact cylinder radius')
  height=.ContactUnitBoundary~scalar(height,.UnitDimension~length,'contact cylinder height')
  segments=segments+0
  if radius<=0 | height<=0 then raise syntax 88.900 array('positive contact cylinder dimensions',radius height)
  if segments<4 then raise syntax 88.900 array('contact cylinder segments >= 4',segments)
  if context==.nil then context=.Maths~defaultContext
  pi=4*RxCalcArcTan(1,30,'R'); half=height/2
  pts=.array~new
  do i=0 to segments-1
    a=2*pi*i/segments
    x=radius*RxCalcCos(a,30,'R'); z=radius*RxCalcSin(a,30,'R')
    pts~append(.MathVector3~new(x,-half,z,context))
    pts~append(.MathVector3~new(x, half,z,context))
  end
  return self~new('cylinder-contact-hull',pts)

::class HullRigidBodyState subclass RigidBodyState public
::method init
  expose _contactHull
  use strict arg physicalBody,massProperties,contactHull,velocity=.nil,angularVelocity=.nil,fixed=.false,restitution='0.2'
  if contactHull==.nil then raise syntax 88.900 array('RigidContactHull',contactHull)
  self~init:super(physicalBody,massProperties,velocity,angularVelocity,fixed,restitution,.nil)
  _contactHull=contactHull
::method contactHull; expose _contactHull; return _contactHull

::class CollisionSurface subclass CollisionPlane public
::method init
  expose _rigidBodyState _friction
  use strict arg point,normal,restitution='0.2',rigidBodyState=.nil,frictionCoefficient='0.4'
  frictionCoefficient=.ContactUnitBoundary~scalar(frictionCoefficient,.UnitDimension~dimensionless,'collision-surface friction coefficient')
  if frictionCoefficient<0 then raise syntax 88.900 array('non-negative collision-surface friction coefficient',frictionCoefficient)
  if rigidBodyState<>.nil then if \rigidBodyState~fixed then -
    raise syntax 93.900 array('CollisionSurface attached rigid state must currently be fixed')
  self~init:super(point,normal,restitution)
  _rigidBodyState=rigidBodyState; _friction=frictionCoefficient
::method rigidBodyState; expose _rigidBodyState; return _rigidBodyState
::method frictionCoefficient; expose _friction; return _friction

::class GeneralContactMechanicsSolver subclass MechanicsSolver public
::method solvePlanes
  /* Preserve the original sphere/plane path, then resolve hull contacts. */
  self~solvePlanes:super
  bodies=self~bodies; planes=self~planes; now=self~time
  do b over bodies
    if b~fixed | \b~isA(.HullRigidBodyState) then iterate
    do p over planes
      hull=b~contactHull
      deepest=0; deepestLocal=.nil
      do lp over hull~localPoints
        wp=b~orientation~rotate(lp)+b~position
        signed=(wp-p~point)~dot(p~normal)
        if deepestLocal==.nil | signed<deepest then do
          deepest=signed; deepestLocal=lp
        end
      end
      if deepestLocal==.nil | deepest>=0 then iterate

      /* Non-penetration positional correction. */
      correctedPosition=b~position-p~normal*deepest
      b~body~pose=.PhysicalPose~new(correctedPosition,b~orientation,b~body~pose~context)
      contactPoint=b~orientation~rotate(deepestLocal)+b~position
      r=contactPoint-b~position
      contactVelocity=b~velocity+b~angularVelocity~cross(r)
      preVn=contactVelocity~dot(p~normal)
      if preVn>=0 then iterate

      preEnergy=b~kineticEnergy
      e=b~restitution; if p~restitution<e then e=p~restitution
      rxn=r~cross(p~normal)
      invIrxn=b~angularAccelerationForTorque(rxn)
      rotationalTerm=invIrxn~cross(r)~dot(p~normal)
      denom=1/b~mass+rotationalTerm
      if denom<='0.000000000000001' then raise syntax 93.900 array('positive rigid contact effective inverse mass',denom)
      jn=-(1+e)*preVn/denom
      normalImpulse=p~normal*jn
      b~applyImpulse(normalImpulse,contactPoint)
      totalImpulse=normalImpulse

      /* Constant-Coulomb tangential impulse.  The coefficient is explicit on the
         surface; no material/friction guess is manufactured by the solver. */
      mu=0
      if p~isA(.CollisionSurface) then mu=p~frictionCoefficient
      if mu>0 then do
        r=contactPoint-b~position
        cv=b~velocity+b~angularVelocity~cross(r)
        tangent=cv-p~normal*(cv~dot(p~normal))
        ts=tangent~norm
        if ts>'0.000000000001' then do
          tdir=tangent*(1/ts)
          rxt=r~cross(tdir)
          invIrxt=b~angularAccelerationForTorque(rxt)
          denomT=1/b~mass+invIrxt~cross(r)~dot(tdir)
          if denomT>'0.000000000000001' then do
            jt=-ts/denomT
            limit=mu*abs(jn)
            if jt>limit then jt=limit
            if jt< -limit then jt=-limit
            tangentialImpulse=tdir*jt
            b~applyImpulse(tangentialImpulse,contactPoint)
            totalImpulse=totalImpulse+tangentialImpulse
          end
        end
      end

      postVelocity=b~velocity+b~angularVelocity~cross(contactPoint-b~position)
      postVn=postVelocity~dot(p~normal)
      postEnergy=b~kineticEnergy
      dissipated=preEnergy-postEnergy
      if dissipated<0 & abs(dissipated)<'0.000000001' then dissipated=0
      if dissipated<0 then dissipated=0

      target=p; impulseB=totalImpulse*(-1)
      if p~isA(.CollisionSurface) then do
        if p~rigidBodyState<>.nil then target=p~rigidBodyState
      end
      self~recordContactEvent(.MechanicsContactEvent~new('HULL_PLANE',b,target,contactPoint,p~normal,totalImpulse,impulseB,preVn,postVn,dissipated,now))
    end
  end

::class RigidTumbleTracker public
::method init
  expose _state _angle _peakOmega _samples _contacts
  use strict arg rigidBodyState
  _state=rigidBodyState; _angle=0; _peakOmega=0; _samples=0; _contacts=0
::method rigidBodyState; expose _state; return _state
::method observe
  expose _state _angle _peakOmega _samples
  use strict arg dt
  dt=.ContactUnitBoundary~scalar(dt,.UnitDimension~time,'tumble tracker timestep')
  if dt<0 then raise syntax 88.900 array('non-negative tumble tracker timestep',dt)
  omega=_state~angularVelocity~norm
  _angle=_angle+omega*dt
  if omega>_peakOmega then _peakOmega=omega
  _samples=_samples+1
  return self
::method observeContacts
  expose _contacts
  use strict arg events
  _contacts=_contacts+events~items
  return self
::method observeStep
  use strict arg mechanicsSolver,dt
  self~observe(dt)
  self~observeContacts(mechanicsSolver~contactEvents)
  return self
::method cumulativeAngleRadians; expose _angle; return _angle
::method cumulativeAngleQuantity; return .Units~q(self~cumulativeAngleRadians,.Units~radian)
::method turns
  pi=4*RxCalcArcTan(1,30,'R')
  return self~cumulativeAngleRadians/(2*pi)
::method fullTurns; return self~turns~trunc
::method peakAngularSpeed; expose _peakOmega; return _peakOmega
::method peakAngularSpeedQuantity; return .Units~q(self~peakAngularSpeed,.Units~radian/.Units~second)
::method sampleCount; expose _samples; return _samples
::method contactCount; expose _contacts; return _contacts

::requires 'Mechanics.cls'
::requires 'rxmath' LIBRARY
