/* Physics World v0.1-dev41
 * Reduced-order reciprocal string <-> body boundary.
 * Models conservative modal coupling plus explicit damping.  It does not own
 * pickup/circuit state and does not invent an Audio observation.
 */
numeric digits 30

::class GuitarCoupledOscillator public
::method init
  expose _name _mass _frequency _damping _x _v _kind _evidence _omega _stiffness _dampingCoeff
  use strict arg name,massKg,frequencyHz,dampingRatio,initialDisplacementM=0,initialVelocityMps=0,kind='MODE',evidence=.nil
  if massKg<=0 | frequencyHz<=0 | dampingRatio<0 then raise syntax 88.900 array('valid coupled oscillator parameters')
  _name=name;_mass=massKg+0;_frequency=frequencyHz+0;_damping=dampingRatio+0
  _x=initialDisplacementM+0;_v=initialVelocityMps+0;_kind=kind;_evidence=evidence
  pi=.Maths~pi(.Maths~defaultContext);_omega=2*pi*_frequency;_stiffness=_mass*_omega*_omega;_dampingCoeff=2*_damping*_mass*_omega
::method name; expose _name; return _name
::method mass; expose _mass; return _mass
::method frequencyHz; expose _frequency; return _frequency
::method dampingRatio; expose _damping; return _damping
::method displacement; expose _x; return _x
::method velocity; expose _v; return _v
::method kind; expose _kind; return _kind
::method evidence; expose _evidence; return _evidence
::method omega; expose _omega; return _omega
::method stiffness; expose _stiffness; return _stiffness
::method dampingCoefficient; expose _dampingCoeff; return _dampingCoeff
::method mechanicalEnergy
  return self~mass*self~velocity*self~velocity/2+self~stiffness*self~displacement*self~displacement/2
::method setState
  expose _x _v
  use strict arg displacementM,velocityMps
  _x=displacementM+0;_v=velocityMps+0; return self

::class GuitarCoupledBoundary public
::method init
  expose _stringModes _bodyModes _coupling _time _ledger
  use strict arg stringModes,bodyModes,couplingStiffnessNPerM,startTimeSeconds=0
  if couplingStiffnessNPerM<0 then raise syntax 88.900 array('non-negative string/body coupling stiffness')
  _stringModes=stringModes~copy;_bodyModes=bodyModes~copy;_coupling=couplingStiffnessNPerM+0;_time=startTimeSeconds+0
  _ledger=.array~new
::method stringModes; expose _stringModes; return _stringModes~copy
::method bodyModes; expose _bodyModes; return _bodyModes~copy
::method couplingStiffness; expose _coupling; return _coupling
::method time; expose _time; return _time
::method ledger; expose _ledger; return _ledger~copy
::method totalMechanicalEnergy
  expose _stringModes _bodyModes _coupling
  e=0
  do q over _stringModes; e+=q~mechanicalEnergy; end
  do q over _bodyModes; e+=q~mechanicalEnergy; end
  if _stringModes~items>0 & _bodyModes~items>0 then do
    xs=0; do q over _stringModes; xs+=q~displacement; end
    xb=0; do q over _bodyModes; xb+=q~displacement; end
    e+=_coupling*(xs-xb)*(xs-xb)/2
  end
  return e
::method step
  expose _stringModes _bodyModes _coupling _time _ledger
  use strict arg dtSeconds
  if dtSeconds<=0 then raise syntax 88.900 array('positive coupled-boundary time step',dtSeconds)
  before=self~totalMechanicalEnergy
  xs=0; do q over _stringModes; xs+=q~displacement; end
  xb=0; do q over _bodyModes; xb+=q~displacement; end
  couplingForce=-_coupling*(xs-xb)
  /* Symplectic Euler: equal/opposite boundary force preserves reciprocity;
     each mode additionally has its own spring and viscous damping. */
  do q over _stringModes
    f=-q~stiffness*q~displacement-q~dampingCoefficient*q~velocity+couplingForce
    v=q~velocity+dtSeconds*f/q~mass
    x=q~displacement+dtSeconds*v
    q~setState(x,v)
  end
  do q over _bodyModes
    f=-q~stiffness*q~displacement-q~dampingCoefficient*q~velocity-couplingForce
    v=q~velocity+dtSeconds*f/q~mass
    x=q~displacement+dtSeconds*v
    q~setState(x,v)
  end
  _time+=dtSeconds
  after=self~totalMechanicalEnergy
  ev=.directory~new;ev['TIME']=_time;ev['ENERGY_BEFORE_J']=before;ev['ENERGY_AFTER_J']=after;ev['COUPLING_FORCE_N']=couplingForce
  _ledger~append(ev)
  return ev

::class GuitarCoupledBoundaryFactory public
::method fromStringAndBody class
  use strict arg stringModel,fret,pluckDisplacementM,pluckFraction,bodyModes,couplingStiffnessNPerM
  strings=.array~new;pi=.Maths~pi(.Maths~defaultContext)
  do n=1 to stringModel~modeCount
    amp=stringModel~modalAmplitude(n,pluckFraction,pluckDisplacementM)
    freq=stringModel~modalAngularFrequency(fret,n)/(2*pi)
    mass=stringModel~modalEffectiveMass(fret,n)
    /* Convert exponential modal decay rate to viscous damping ratio. */
    z=stringModel~modalDamping(n,'PICK')/stringModel~modalAngularFrequency(fret,n)
    strings~append(.GuitarCoupledOscillator~new('string-'n,mass,freq,z,amp,0,'STRING_MODE',stringModel))
  end
  bodies=.array~new
  do b over bodyModes
    bodies~append(.GuitarCoupledOscillator~new(b~name,b~effectiveMass,b~frequencyHz,b~dampingRatio,0,0,'BODY_MODE',b))
  end
  return .GuitarCoupledBoundary~new(strings,bodies,couplingStiffnessNPerM)

::requires 'rxmath' LIBRARY
::requires 'GuitarStringMagnetics.cls'
::requires 'GuitarStructuralCoupling.cls'
::requires 'MathsBootstrap.cls'
