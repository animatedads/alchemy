/* ooRexx Physics World v0.1-dev10
   Deformable-body mechanics over authoritative Maths v0.8 vectors.
   Internal units are SI: m, kg, s, N, Pa and J.
   Vector scaling deliberately follows Maths v0.8: vector * scalar.
*/


::class UnitBoundary
::method canonical class
  use strict arg value,expectedDimension,label
  if value~isA(.UnitQuantity) then do
    if \value~dimension~compatible(expectedDimension) then -
      raise syntax 93.900 array(label 'has incompatible physical dimension')
    return value~canonicalValue
  end
  return value
::method scalar class
  use strict arg value,expectedDimension,label
  numeric digits 50
  v=self~canonical(value,expectedDimension,label)
  return v+0
::method areaDimension class; return .Units~squareMetre~dimension
::method densityDimension class; return .Units~kilogramPerCubicMetre~dimension
::method dampingDimension class; return (.Units~pascal*.Units~second)~dimension
::method momentumDimension class; return .Units~newtonSecond~dimension

::class MechanicalMaterial public
::method init
  expose _name _density _young _yieldStrain _fractureStrain _damping _plasticFlow
  use strict arg name,density,youngModulus,yieldStrain,fractureStrain,damping=0,plasticFlow=1
  density=.UnitBoundary~scalar(density,.UnitBoundary~densityDimension,'density')
  youngModulus=.UnitBoundary~scalar(youngModulus,.Units~pascal~dimension,'Young modulus')
  yieldStrain=.UnitBoundary~scalar(yieldStrain,.UnitDimension~dimensionless,'yield strain')
  fractureStrain=.UnitBoundary~scalar(fractureStrain,.UnitDimension~dimensionless,'fracture strain')
  damping=.UnitBoundary~scalar(damping,.UnitBoundary~dampingDimension,'axial damping')
  plasticFlow=.UnitBoundary~scalar(plasticFlow,.UnitDimension~dimensionless,'plastic flow')
  if density<=0 then raise syntax 88.900 array('positive density',density)
  if youngModulus<=0 then raise syntax 88.900 array('positive Young modulus',youngModulus)
  if yieldStrain<0 then raise syntax 88.900 array('non-negative yield strain',yieldStrain)
  if fractureStrain<=yieldStrain then raise syntax 88.900 array('fracture strain greater than yield strain',fractureStrain)
  if damping<0 then raise syntax 88.900 array('non-negative axial damping',damping)
  if plasticFlow<0 | plasticFlow>1 then raise syntax 88.900 array('plastic flow in range 0..1',plasticFlow)
  _name=name; _density=density; _young=youngModulus; _yieldStrain=yieldStrain
  _fractureStrain=fractureStrain; _damping=damping; _plasticFlow=plasticFlow
::method name; expose _name; return _name
::method density; expose _density; return _density
::method youngModulus; expose _young; return _young
::method yieldStrain; expose _yieldStrain; return _yieldStrain
::method fractureStrain; expose _fractureStrain; return _fractureStrain
::method damping; expose _damping; return _damping
::method plasticFlow; expose _plasticFlow; return _plasticFlow
::method yieldStress; return self~youngModulus*self~yieldStrain
::method densityQuantity; return .Units~q(self~density,.Units~kilogramPerCubicMetre)
::method youngModulusQuantity; return .Units~q(self~youngModulus,.Units~pascal)
::method yieldStressQuantity; return .Units~q(self~yieldStress,.Units~pascal)
::method dampingQuantity; return .Units~q(self~damping,.Units~pascal*.Units~second)
::method mildSteel class
  /* Development constitutive approximation, not a grade-specific datasheet. */
  return self~new('mild-steel-approx',7850,'200000000000','0.00125','0.18','2000000',1)
::method aluminium class
  return self~new('aluminium-approx',2700,'69000000000','0.003','0.16','1000000',1)
::method rubber class
  return self~new('rubber-approx',1100,'7000000','0.20','1.50','120000',0)

::class DeformableNode public
::method init
  expose _position _reference _velocity _force _mass _fixed _context
  use strict arg position,mass,velocity=.nil,fixed=.false
  mass=.UnitBoundary~scalar(mass,.UnitDimension~mass,'node mass')
  if velocity<>.nil then velocity=.UnitBoundary~canonical(velocity,.Units~metrePerSecond~dimension,'node velocity')
  if mass<=0 then raise syntax 88.900 array('positive node mass',mass)
  _position=position; _reference=position; _mass=mass; _fixed=fixed; _context=position~context
  if velocity==.nil then velocity=.MathVector3~new(0,0,0,_context)
  _velocity=velocity; _force=.MathVector3~new(0,0,0,_context)
::method position; expose _position; return _position
::method 'position='; expose _position; use strict arg p; _position=p
::method referencePosition; expose _reference; return _reference
::method velocity; expose _velocity; return _velocity
::method 'velocity='; expose _velocity; use strict arg v; _velocity=v
::method force; expose _force; return _force
::method mass; expose _mass; return _mass
::method massQuantity; return .Units~q(self~mass,.Units~kilogram)
::method velocityQuantity; return .Units~q(self~velocity,.Units~metrePerSecond)
::method fixed; expose _fixed; return _fixed
::method 'fixed='; expose _fixed; use strict arg v; _fixed=v
::method momentum; return self~velocity*self~mass
::method momentumQuantity; return .Units~q(self~momentum,.Units~newtonSecond)
::method kineticEnergy; return self~mass*self~velocity~dot(self~velocity)/2
::method kineticEnergyQuantity; return .Units~q(self~kineticEnergy,.Units~joule)
::method applyForce
  expose _force
  use strict arg f
  if \self~fixed then _force=_force+f
::method clearForce
  expose _force _context
  _force=.MathVector3~new(0,0,0,_context)
::method integrate
  use strict arg dt,gravity
  if self~fixed then do; self~velocity=.MathVector3~new(0,0,0,self~position~context); self~clearForce; return; end
  accel=gravity+self~force*(1/self~mass)
  self~velocity=self~velocity+accel*dt
  self~position=self~position+self~velocity*dt
  self~clearForce
::method applyImpulse
  use strict arg impulse
  if \self~fixed then self~velocity=self~velocity+impulse*(1/self~mass)

::class DeformableLink public
::method init
  expose _a _b _area _material _rest _referenceRest _broken _lastStrain _lastStress _plasticWork _fractureEnergy _fractureSurfaceEnergy _unresolvedFractureEnergy _fractureLaw _fractureCriterion _fractureStress _fractureStrain
  use strict arg nodeA,nodeB,crossSectionArea,material,restLength=.nil,fractureLaw=.nil
  crossSectionArea=.UnitBoundary~scalar(crossSectionArea,.UnitBoundary~areaDimension,'link cross-section area')
  if restLength<>.nil then restLength=.UnitBoundary~scalar(restLength,.UnitDimension~length,'link rest length')
  if crossSectionArea<=0 then raise syntax 88.900 array('positive link cross-section area',crossSectionArea)
  _a=nodeA; _b=nodeB; _area=crossSectionArea; _material=material
  if restLength==.nil then restLength=(nodeB~position-nodeA~position)~norm
  if restLength<=0 then raise syntax 88.900 array('positive link rest length',restLength)
  _rest=restLength; _referenceRest=restLength; _broken=.false; _fractureLaw=fractureLaw
  _lastStrain=0; _lastStress=0; _plasticWork=0; _fractureEnergy=0; _fractureSurfaceEnergy=0; _unresolvedFractureEnergy=0
  _fractureCriterion=''; _fractureStress=0; _fractureStrain=0
::method nodeA; expose _a; return _a
::method nodeB; expose _b; return _b
::method area; expose _area; return _area
::method material; expose _material; return _material
::method restLength; expose _rest; return _rest
::method referenceRestLength; expose _referenceRest; return _referenceRest
::method broken; expose _broken; return _broken
::method lastStrain; expose _lastStrain; return _lastStrain
::method lastStress; expose _lastStress; return _lastStress
::method lastStressQuantity; return .Units~q(self~lastStress,.Units~pascal)
::method areaQuantity; return .Units~q(self~area,.Units~squareMetre)
::method restLengthQuantity; return .Units~q(self~restLength,.Units~metre)
::method plasticWork; expose _plasticWork; return _plasticWork
::method fractureEnergy; expose _fractureEnergy; return _fractureEnergy
::method fractureEnergyQuantity; return .Units~q(self~fractureEnergy,.Units~joule)
::method fractureSurfaceEnergy; expose _fractureSurfaceEnergy; return _fractureSurfaceEnergy
::method fractureSurfaceEnergyQuantity; return .Units~q(self~fractureSurfaceEnergy,.Units~joule)
::method unresolvedFractureEnergy; expose _unresolvedFractureEnergy; return _unresolvedFractureEnergy
::method unresolvedFractureEnergyQuantity; return .Units~q(self~unresolvedFractureEnergy,.Units~joule)
::method fractureLaw; expose _fractureLaw; return _fractureLaw
::method fractureCriterion; expose _fractureCriterion; return _fractureCriterion
::method fractureStress; expose _fractureStress; return _fractureStress
::method fractureStressQuantity; return .Units~q(self~fractureStress,.Units~pascal)
::method fractureStrainAtFailure; expose _fractureStrain; return _fractureStrain
::method fracturePoint; return (self~nodeA~position+self~nodeB~position)*.5
::method fractureDirection
  delta=self~nodeB~position-self~nodeA~position
  if delta~norm<'0.000000000001' then return .MathVector3~new(1,0,0,self~nodeA~position~context)
  return delta~normalized
::method currentLength; return (self~nodeB~position-self~nodeA~position)~norm
::method elasticEnergyQuantity; return .Units~q(self~elasticEnergy,.Units~joule)
::method elasticEnergy
  if self~broken then return 0
  strain=self~lastStrain
  volume=self~area*self~restLength
  return self~material~youngModulus*strain*strain*volume/2
::method permanentStrain
  return (self~restLength-self~referenceRestLength)/self~referenceRestLength
::method apply
  expose _rest _broken _lastStrain _lastStress _plasticWork _fractureEnergy _fractureSurfaceEnergy _unresolvedFractureEnergy _fractureLaw _fractureCriterion _fractureStress _fractureStrain
  if _broken then return
  delta=self~nodeB~position-self~nodeA~position
  length=delta~norm
  if length<'0.000000000001' then return
  dir=delta*(1/length)
  trialStrain=(length-_rest)/_rest
  absTrial=abs(trialStrain)
  mat=self~material
  trialStress=mat~youngModulus*trialStrain
  trialVolume=self~area*_rest
  trialElasticEnergy=mat~youngModulus*trialStrain*trialStrain*trialVolume/2
  fractureCriterion=''
  if _fractureLaw<>.nil then fractureCriterion=_fractureLaw~failureCriterion(trialStress,trialElasticEnergy,self~area)
  if fractureCriterion=='' & absTrial>=mat~fractureStrain then fractureCriterion='STRAIN_LIMIT'
  if fractureCriterion<>'' then do
    _fractureEnergy=trialElasticEnergy
    _fractureSurfaceEnergy=0
    if _fractureLaw<>.nil then _fractureSurfaceEnergy=_fractureLaw~surfaceEnergyFor(self~area,trialElasticEnergy)
    _unresolvedFractureEnergy=trialElasticEnergy-_fractureSurfaceEnergy
    _fractureCriterion=fractureCriterion; _fractureStress=trialStress; _fractureStrain=trialStrain
    _broken=.true; _lastStrain=0; _lastStress=0
    return
  end

  /* Perfect-plastic style flow: move the natural length toward the current
     length enough to leave, at most, the configured elastic yield strain.
     plasticFlow allows deliberately partial flow; 1 is full flow. */
  if absTrial>mat~yieldStrain & mat~plasticFlow>0 then do
    sign=1; if trialStrain<0 then sign=-1
    targetRest=length/(1+sign*mat~yieldStrain)
    oldRest=_rest
    _rest=_rest+(targetRest-_rest)*mat~plasticFlow
    deltaRest=abs(_rest-oldRest)
    _plasticWork=_plasticWork+mat~yieldStress*self~area*deltaRest
  end

  strain=(length-_rest)/_rest
  strainRate=(self~nodeB~velocity-self~nodeA~velocity)~dot(dir)/_rest
  stress=mat~youngModulus*strain+mat~damping*strainRate
  force=dir*(stress*self~area)
  self~nodeA~applyForce(force)
  self~nodeB~applyForce(force*(-1))
  _lastStrain=strain; _lastStress=stress

::class DeformableBody public
::method init
  expose _name _nodes _links
  use strict arg name
  _name=name; _nodes=.array~new; _links=.array~new
::method name; expose _name; return _name
::method nodes; expose _nodes; return _nodes~copy
::method links; expose _links; return _links~copy
::method addNode; expose _nodes; use strict arg node; _nodes~append(node); return node
::method addLink; expose _links; use strict arg link; _links~append(link); return link
::method massQuantity; return .Units~q(self~mass,.Units~kilogram)
::method mass
  expose _nodes
  total=0; do n over _nodes; total=total+n~mass; end; return total
::method momentum
  expose _nodes
  if _nodes~items=0 then return .MathVector3~new(0,0,0,.Maths~defaultContext)
  p=.MathVector3~new(0,0,0,_nodes[1]~position~context)
  do n over _nodes; if \n~fixed then p=p+n~momentum; end
  return p
::method kineticEnergyQuantity; return .Units~q(self~kineticEnergy,.Units~joule)
::method kineticEnergy
  expose _nodes
  e=0; do n over _nodes; if \n~fixed then e=e+n~kineticEnergy; end; return e
::method elasticEnergyQuantity; return .Units~q(self~elasticEnergy,.Units~joule)
::method elasticEnergy
  expose _links
  e=0; do l over _links; e=e+l~elasticEnergy; end; return e
::method plasticWork
  expose _links
  e=0; do l over _links; e=e+l~plasticWork; end; return e
::method brokenLinks
  expose _links
  n=0; do l over _links; if l~broken then n=n+1; end; return n
::method fragments; return .FractureTopology~fragments(self)
::method fragmentCount; return self~fragments~items
::method centroid
  expose _nodes
  if _nodes~items=0 then raise syntax 88.900 array('deformable body with nodes',self~name)
  c=.MathVector3~new(0,0,0,_nodes[1]~position~context); total=0
  do n over _nodes; c=c+n~position*n~mass; total=total+n~mass; end
  return c*(1/total)
::method bar class
  use strict arg name,nodeCount,length,totalMass,area,material,origin=.nil,axis=.nil,context=.nil,fractureLaw=.nil
  length=.UnitBoundary~scalar(length,.UnitDimension~length,'bar length')
  totalMass=.UnitBoundary~scalar(totalMass,.UnitDimension~mass,'bar mass')
  area=.UnitBoundary~scalar(area,.UnitBoundary~areaDimension,'bar area')
  if nodeCount<2 then raise syntax 88.900 array('bar node count >= 2',nodeCount)
  if context==.nil then context=.Maths~defaultContext
  if origin==.nil then origin=.MathVector3~new(0,0,0,context)
  if axis==.nil then axis=.MathVector3~new(1,0,0,context)
  axis=axis~normalized
  body=self~new(name); spacing=length/(nodeCount-1); nodeMass=totalMass/nodeCount
  do i=0 to nodeCount-1
    body~addNode(.DeformableNode~new(origin+axis*(spacing*i),nodeMass))
  end
  ns=body~nodes
  do i=1 to nodeCount-1
    body~addLink(.DeformableLink~new(ns[i],ns[i+1],area,material,spacing,fractureLaw))
  end
  return body
::method boxLattice class
  use strict arg name,nx,ny,nz,spacing,totalMass,area,material,origin=.nil,context=.nil,fractureLaw=.nil
  spacing=.UnitBoundary~scalar(spacing,.UnitDimension~length,'lattice spacing')
  totalMass=.UnitBoundary~scalar(totalMass,.UnitDimension~mass,'lattice mass')
  area=.UnitBoundary~scalar(area,.UnitBoundary~areaDimension,'lattice link area')
  if nx<2 | ny<2 | nz<2 then raise syntax 88.900 array('box lattice dimensions >= 2',nx ny nz)
  if context==.nil then context=.Maths~defaultContext
  if origin==.nil then origin=.MathVector3~new(0,0,0,context)
  body=self~new(name); count=nx*ny*nz; nodeMass=totalMass/count
  grid=.array~new(count); index=0
  do k=0 to nz-1
    do j=0 to ny-1
      do i=0 to nx-1
        index=index+1
        p=origin+.MathVector3~new(i*spacing,j*spacing,k*spacing,context)
        n=.DeformableNode~new(p,nodeMass); body~addNode(n); grid[index]=n
      end
    end
  end
  do k=0 to nz-1
    do j=0 to ny-1
      do i=0 to nx-1
        here=1+i+nx*j+nx*ny*k
        if i<nx-1 then body~addLink(.DeformableLink~new(grid[here],grid[here+1],area,material,spacing,fractureLaw))
        if j<ny-1 then body~addLink(.DeformableLink~new(grid[here],grid[here+nx],area,material,spacing,fractureLaw))
        if k<nz-1 then body~addLink(.DeformableLink~new(grid[here],grid[here+nx*ny],area,material,spacing,fractureLaw))
      end
    end
  end
  return body


::class DeformableContactEvent public
::method init
  expose _body _node _plane _point _normal _impulse _preNormalVelocity _postNormalVelocity _dissipatedEnergy _time
  use strict arg body,node,plane,point,normal,impulseOnNode,preNormalVelocity,postNormalVelocity,dissipatedEnergy,timeSeconds
  _body=body; _node=node; _plane=plane; _point=point; _normal=normal~normalized; _impulse=impulseOnNode
  _preNormalVelocity=preNormalVelocity; _postNormalVelocity=postNormalVelocity; _dissipatedEnergy=dissipatedEnergy; _time=timeSeconds
::method kind; return 'DEFORMABLE_PLANE'
::method body; expose _body; return _body
::method node; expose _node; return _node
::method plane; expose _plane; return _plane
::method point; expose _point; return _point
::method normal; expose _normal; return _normal
::method impulseOnNode; expose _impulse; return _impulse
::method impulseFor
  use strict arg target
  if target==self~node then return self~impulseOnNode
  return .nil
::method impulseQuantity; return .Units~q(self~impulseOnNode,.Units~newtonSecond)
::method impulseMagnitude; return self~impulseOnNode~norm
::method impulseMagnitudeQuantity; return .Units~q(self~impulseMagnitude,.Units~newtonSecond)
::method preNormalVelocity; expose _preNormalVelocity; return _preNormalVelocity
::method postNormalVelocity; expose _postNormalVelocity; return _postNormalVelocity
::method dissipatedEnergy; expose _dissipatedEnergy; return _dissipatedEnergy
::method dissipatedEnergyQuantity; return .Units~q(self~dissipatedEnergy,.Units~joule)
::method time; expose _time; return _time
::method timeQuantity; return .Units~q(self~time,.Units~second)

::class DeformableContactPlane public
::method init
  expose _point _normal _restitution
  use strict arg point,normal,restitution=0
  _point=point; _normal=normal~normalized; _restitution=restitution
::method point; expose _point; return _point
::method normal; expose _normal; return _normal
::method restitution; expose _restitution; return _restitution

::class DeformationEnergyLedger public
::method init
  expose _kinetic _elastic _plastic _fracture _surfaceCreation _unresolvedFracture
  _kinetic=0; _elastic=0; _plastic=0; _fracture=0; _surfaceCreation=0; _unresolvedFracture=0
::method kinetic; expose _kinetic; return _kinetic
::method kineticQuantity; return .Units~q(self~kinetic,.Units~joule)
::method elastic; expose _elastic; return _elastic
::method elasticQuantity; return .Units~q(self~elastic,.Units~joule)
::method plastic; expose _plastic; return _plastic
::method plasticQuantity; return .Units~q(self~plastic,.Units~joule)
::method fracture; expose _fracture; return _fracture
::method fractureQuantity; return .Units~q(self~fracture,.Units~joule)
::method surfaceCreation; expose _surfaceCreation; return _surfaceCreation
::method surfaceCreationQuantity; return .Units~q(self~surfaceCreation,.Units~joule)
::method unresolvedFractureRelease; expose _unresolvedFracture; return _unresolvedFracture
::method unresolvedFractureReleaseQuantity; return .Units~q(self~unresolvedFractureRelease,.Units~joule)
::method total; return self~kinetic+self~elastic+self~plastic+self~fracture
::method totalQuantity; return .Units~q(self~total,.Units~joule)
::method capture
  expose _kinetic _elastic _plastic _fracture _surfaceCreation _unresolvedFracture
  use strict arg bodies
  _kinetic=0; _elastic=0; _plastic=0; _fracture=0; _surfaceCreation=0; _unresolvedFracture=0
  do body over bodies
    _kinetic=_kinetic+body~kineticEnergy; _elastic=_elastic+body~elasticEnergy; _plastic=_plastic+body~plasticWork
    do link over body~links
      _fracture=_fracture+link~fractureEnergy
      _surfaceCreation=_surfaceCreation+link~fractureSurfaceEnergy
      _unresolvedFracture=_unresolvedFracture+link~unresolvedFractureEnergy
    end
  end
  return self

::class DeformableSolver public
::method init
  expose _bodies _planes _gravity _iterations _time _contactEvents _fractureEvents
  use strict arg gravity=.nil,contactIterations=2
  _bodies=.array~new; _planes=.array~new; _iterations=contactIterations
  _time=0; _contactEvents=.array~new; _fractureEvents=.array~new
  if gravity==.nil then gravity=.MathVector3~new(0,'-9.80665',0,.Maths~defaultContext)
  else gravity=.UnitBoundary~canonical(gravity,.Units~metrePerSecondSquared~dimension,'gravity')
  _gravity=gravity
::method gravity; expose _gravity; return _gravity
::method 'gravity='; expose _gravity; use strict arg g; _gravity=.UnitBoundary~canonical(g,.Units~metrePerSecondSquared~dimension,'gravity')
::method bodies; expose _bodies; return _bodies~copy
::method addBody; expose _bodies; use strict arg b; _bodies~append(b); return b
::method addPlane; expose _planes; use strict arg p; _planes~append(p); return p
::method time; expose _time; return _time
::method timeQuantity; return .Units~q(self~time,.Units~second)
::method contactEvents; expose _contactEvents; return _contactEvents~copy
::method fractureEvents; expose _fractureEvents; return _fractureEvents~copy
::method step
  expose _bodies _planes _gravity _iterations _time _contactEvents _fractureEvents
  use strict arg dt
  dt=.UnitBoundary~scalar(dt,.UnitDimension~time,'deformable timestep')
  if dt<=0 then raise syntax 88.900 array('positive deformable timestep',dt)
  _contactEvents=.array~new; _fractureEvents=.array~new
  do body over _bodies
    do link over body~links
      wasBroken=link~broken
      link~apply
      if \wasBroken & link~broken then _fractureEvents~append(.FractureEvent~new(body,link,_time))
    end
  end
  do body over _bodies
    do node over body~nodes; node~integrate(dt,_gravity); end
  end
  _time=_time+dt
  do i=1 to _iterations
    do body over _bodies
      do node over body~nodes
        if node~fixed then iterate
        do plane over _planes
          signed=(node~position-plane~point)~dot(plane~normal)
          if signed<0 then do
            node~position=node~position-plane~normal*signed
            vn=node~velocity~dot(plane~normal)
            if vn<0 then do
              preVn=vn; oldVelocity=node~velocity
              node~velocity=node~velocity-plane~normal*((1+plane~restitution)*vn)
              impulse=(node~velocity-oldVelocity)*node~mass
              postVn=node~velocity~dot(plane~normal)
              dissipated=node~mass*preVn*preVn*(1-plane~restitution*plane~restitution)/2
              _contactEvents~append(.DeformableContactEvent~new(body,node,plane,node~position,plane~normal,impulse,preVn,postVn,dissipated,_time))
            end
          end
        end
      end
    end
  end
::method energyLedger
  ledger=.DeformationEnergyLedger~new
  return ledger~capture(self~bodies)

::requires 'Mechanics.cls'
::requires 'Fracture.cls'
