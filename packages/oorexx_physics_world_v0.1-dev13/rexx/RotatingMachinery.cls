/* ooRexx Physics World v0.1-dev13
   General rotating-machinery mechanics: mass eccentricity/imbalance,
   compliant radial bearings, rotational drag and harmonic observations.

   This layer composes Mechanics; it does not own part catalogues or
   manufacturing geometry.  Harmonics are measured from force histories,
   never manufactured as arbitrary multipliers.
*/

::class RotatingUnitBoundary
::method scalar class
  use strict arg value,dimension,label
  numeric digits 50
  if value~isA(.UnitQuantity) then do
    if \value~dimension~compatible(dimension) then raise syntax 93.900 array(label 'has incompatible physical dimension')
    return value~canonicalValue+0
  end
  return value+0

::class RotorMassEccentricity public
::method init
  expose _mass _offset
  use strict arg eccentricMass,localOffset
  _mass=.RotatingUnitBoundary~scalar(eccentricMass,.UnitDimension~mass,'eccentric mass')
  if _mass<0 then raise syntax 88.900 array('non-negative eccentric mass',_mass)
  _offset=localOffset
::method mass; expose _mass; return _mass
::method localOffset; expose _offset; return _offset
::method radius; return self~localOffset~norm
::method imbalance; return self~mass*self~radius
::method centrifugalForce
  use strict arg bodyState
  omega=bodyState~body~pose~vectorToLocal(bodyState~angularVelocity)
  /* exact rigid rotation acceleration for offset r: omega x (omega x r);
     required holding force is -m*a and is transformed to world coordinates. */
  localForce=(omega~cross(omega~cross(self~localOffset)))*(-self~mass)
  return bodyState~body~pose~vectorToWorld(localForce)
::method apply
  use strict arg bodyState
  f=self~centrifugalForce(bodyState)
  p=bodyState~body~pose~position+bodyState~body~pose~vectorToWorld(self~localOffset)
  bodyState~applyForce(f,p)
  return f

::class CompliantRadialBearing public
::method init
  expose _body _anchor _axis _k _c _rotDrag _name _lastForce
  use strict arg bodyState,worldAnchor,worldAxis,radialStiffness,radialDamping=0,rotationalDrag=0,name='bearing'
  _body=bodyState; _anchor=worldAnchor; _axis=worldAxis~normalized
  _k=radialStiffness+0; _c=radialDamping+0; _rotDrag=rotationalDrag+0; _name=name
  if _k<0 | _c<0 | _rotDrag<0 then raise syntax 88.900 array('non-negative bearing stiffness damping and rotational drag')
  _lastForce=.MathVector3~new(0,0,0,bodyState~body~pose~context)
::method name; expose _name; return _name
::method body; expose _body; return _body
::method axis; expose _axis; return _axis
::method lastForce; expose _lastForce; return _lastForce
::method radialDisplacement
  expose _body _anchor _axis
  d=_body~position-_anchor
  return d-_axis*(d~dot(_axis))
::method radialVelocity
  expose _body _axis
  v=_body~velocity
  return v-_axis*(v~dot(_axis))
::method apply
  expose _body _axis _k _c _rotDrag _lastForce
  _lastForce=self~radialDisplacement*(-_k)+self~radialVelocity*(-_c)
  _body~applyForce(_lastForce)
  axialOmega=_body~angularVelocity~dot(_axis)
  if _rotDrag>0 then _body~applyTorque(_axis*(-_rotDrag*axialOmega))
  return _lastForce

::class RotationalViscousFriction public
::method init
  expose _body _axis _coefficient _lastTorque _lastPower
  use strict arg bodyState,worldAxis,coefficient
  _body=bodyState; _axis=worldAxis~normalized; _coefficient=coefficient+0
  if _coefficient<0 then raise syntax 88.900 array('non-negative rotational viscous friction coefficient',_coefficient)
  _lastTorque=0; _lastPower=0
::method apply
  expose _body _axis _coefficient _lastTorque _lastPower
  w=_body~angularVelocity~dot(_axis)
  _lastTorque=-_coefficient*w
  _lastPower=-_lastTorque*w
  _body~applyTorque(_axis*_lastTorque)
  return _axis*_lastTorque
::method dissipatedPower; expose _lastPower; return _lastPower
::method torque; expose _lastTorque; return _lastTorque

::class RotatingAssembly public
::method init
  expose _body _eccentricities _bearings _frictions _lastForces
  use strict arg bodyState
  _body=bodyState; _eccentricities=.array~new; _bearings=.array~new; _frictions=.array~new; _lastForces=.array~new
::method body; expose _body; return _body
::method addEccentricity; expose _eccentricities; use strict arg x; _eccentricities~append(x); return x
::method addBearing; expose _bearings; use strict arg x; _bearings~append(x); return x
::method addFriction; expose _frictions; use strict arg x; _frictions~append(x); return x
::method apply
  expose _body _eccentricities _bearings _frictions _lastForces
  _lastForces=.array~new
  do x over _eccentricities; _lastForces~append(x~apply(_body)); end
  do x over _bearings; _lastForces~append(x~apply); end
  do x over _frictions; x~apply; end
  return self
::method lastForces; expose _lastForces; return _lastForces~copy

::class HarmonicSampleHistory public
::method init
  expose _times _values
  _times=.array~new; _values=.array~new
::method append
  expose _times _values
  use strict arg timeSeconds,value
  _times~append(timeSeconds+0); _values~append(value+0); return self
::method count; expose _values; return _values~items
::method component
  expose _times _values
  use strict arg frequencyHz
  numeric digits 30
  n=_values~items
  if n<2 then raise syntax 93.900 array('at least two samples for harmonic observation')
  pi=4*RxCalcArcTan(1,30,'R'); c=0; s=0
  do i=1 to n
    a=2*pi*frequencyHz*_times[i]
    c=c+_values[i]*RxCalcCos(a,30,'R')
    s=s+_values[i]*RxCalcSin(a,30,'R')
  end
  amplitude=2*RxCalcSqrt(c*c+s*s,30)/n
  return .HarmonicObservation~new(frequencyHz,amplitude,c*2/n,s*2/n,n)

::class HarmonicObservation public
::method init
  expose _frequency _amplitude _cosine _sine _samples
  use strict arg frequencyHz,amplitude,cosineComponent,sineComponent,sampleCount
  _frequency=frequencyHz; _amplitude=amplitude; _cosine=cosineComponent; _sine=sineComponent; _samples=sampleCount
::method frequency; expose _frequency; return _frequency
::method amplitude; expose _amplitude; return _amplitude
::method cosineComponent; expose _cosine; return _cosine
::method sineComponent; expose _sine; return _sine
::method sampleCount; expose _samples; return _samples

::requires 'Mechanics.cls'
::requires 'rxmath' LIBRARY
