/* ooRexx Physics World v0.1-dev14
   General shaft/rotor vibration modes and contact/friction excitation.

   Modal parameters are physical inputs/projections.  This file does not own
   manufacturing geometry, material catalogue identity or part identity.
*/

::class RotatingVibrationMode public
::method init
  expose _name _axis _mass _stiffness _damping _q _qd _force _lastInput _lastDissipation
  use strict arg name,worldAxis,modalMass,stiffness,damping=0,displacement=0,velocity=0
  _name=name; _axis=worldAxis~normalized; _mass=modalMass+0; _stiffness=stiffness+0; _damping=damping+0
  if _mass<=0 | _stiffness<0 | _damping<0 then raise syntax 88.900 array('positive modal mass and non-negative stiffness/damping')
  _q=displacement+0; _qd=velocity+0; _force=0; _lastInput=0; _lastDissipation=0
::method name; expose _name; return _name
::method axis; expose _axis; return _axis
::method modalMass; expose _mass; return _mass
::method stiffness; expose _stiffness; return _stiffness
::method damping; expose _damping; return _damping
::method displacement; expose _q; return _q
::method velocity; expose _qd; return _qd
::method naturalAngularFrequency
  expose _mass _stiffness
  if _stiffness=0 then return 0
  return RxCalcSqrt(_stiffness/_mass,30)
::method naturalFrequency
  pi=4*RxCalcArcTan(1,30,'R')
  return self~naturalAngularFrequency/(2*pi)
::method applyGeneralizedForce
  expose _force
  use strict arg force
  _force=_force+force
::method applyWorldForce
  use strict arg worldForce
  self~applyGeneralizedForce(worldForce~dot(self~axis))
::method step
  expose _mass _stiffness _damping _q _qd _force _lastInput _lastDissipation
  use strict arg dt
  numeric digits 40
  if dt<=0 then raise syntax 88.900 array('positive vibration timestep',dt)
  _lastInput=_force
  /* symplectic Euler: robust deterministic baseline for linear modal dynamics */
  a=(_force-_damping*_qd-_stiffness*_q)/_mass
  _qd=_qd+a*dt
  _q=_q+_qd*dt
  _lastDissipation=_damping*_qd*_qd
  _force=0
  return self
::method dampingDissipatedPower; expose _lastDissipation; return _lastDissipation
::method kineticEnergy; expose _mass _qd; return _mass*_qd*_qd/2
::method strainEnergy; expose _stiffness _q; return _stiffness*_q*_q/2

::class RotatingVibrationSystem public
::method init
  expose _modes _time
  use strict arg startTime=0
  _modes=.array~new; _time=startTime+0
::method addMode; expose _modes; use strict arg mode; _modes~append(mode); return mode
::method modes; expose _modes; return _modes~copy
::method time; expose _time; return _time
::method applyWorldForce
  expose _modes
  use strict arg force
  do mode over _modes; mode~applyWorldForce(force); end
::method step
  expose _modes _time
  use strict arg dt
  do mode over _modes; mode~step(dt); end
  _time=_time+dt
  return self

::class ContactFrictionExcitation public
::method init
  expose _normal _muStatic _muKinetic _lastFriction _lastPower
  use strict arg surfaceNormal,staticCoefficient,kineticCoefficient=.nil
  _normal=surfaceNormal~normalized; _muStatic=staticCoefficient+0
  if kineticCoefficient==.nil then kineticCoefficient=staticCoefficient
  _muKinetic=kineticCoefficient+0
  if _muStatic<0 | _muKinetic<0 then raise syntax 88.900 array('non-negative friction coefficients')
  _lastFriction=.MathVector3~new(0,0,0); _lastPower=0
::method frictionForce
  expose _normal _muKinetic _lastFriction _lastPower
  use strict arg normalForce,relativeVelocity
  if normalForce<0 then raise syntax 88.900 array('non-negative normal contact force',normalForce)
  tangent=relativeVelocity-_normal*(relativeVelocity~dot(_normal))
  speed=tangent~norm
  if speed<'0.000000000001' | normalForce=0 then do
    _lastFriction=tangent*0; _lastPower=0; return _lastFriction
  end
  _lastFriction=tangent*(-_muKinetic*normalForce/speed)
  _lastPower=-_lastFriction~dot(relativeVelocity)
  return _lastFriction
::method dissipatedPower; expose _lastPower; return _lastPower
::method lastFrictionForce; expose _lastFriction; return _lastFriction

::class RotorVibrationExperiment public
::method init
  expose _mode _history _time
  use strict arg mode,startTime=0
  _mode=mode; _history=.HarmonicSampleHistory~new; _time=startTime+0
::method mode; expose _mode; return _mode
::method history; expose _history; return _history
::method time; expose _time; return _time
::method step
  expose _mode _history _time
  use strict arg dt,worldForce=.nil
  if worldForce<>.nil then _mode~applyWorldForce(worldForce)
  _mode~step(dt); _time=_time+dt
  _history~append(_time,_mode~displacement)
  return _mode~displacement

::requires 'RotatingMachinery.cls'
::requires 'rxmath' LIBRARY
