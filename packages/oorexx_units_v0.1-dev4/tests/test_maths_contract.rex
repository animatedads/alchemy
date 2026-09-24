numeric digits 50
failures=0

/* Contract double for Maths v0.8 vector scaling: supports vector * scalar and
   deliberately does not implement vector / scalar. */
v=.ScaleOnlyVector~new(10,20,30)
q=.UnitQuantity~new(v,.Units~metre)
t=.UnitQuantity~new(2,.Units~second)
speed=q/t
sv=speed~canonicalValue
if sv~x <> 5 | sv~y <> 10 | sv~z <> 15 then call fail 'vector quantity / scalar quantity must use reciprocal scaling'

half=q/2
hv=half~canonicalValue
if hv~x <> 5 | hv~y <> 10 | hv~z <> 15 then call fail 'vector quantity / plain scalar must use reciprocal scaling'

/* Scalar * vector-valued quantity is allowed via commutative scaling fallback. */
m=.UnitQuantity~new(2,.Units~kilogram)
a=.UnitQuantity~new(.ScaleOnlyVector~new(3,0,0),.Units~metrePerSecondSquared)
f=m*a
fv=f~canonicalValue
if fv~x <> 6 then call fail 'scalar quantity * vector quantity fallback'
if f~dimension~canonical <> .Units~newton~dimension~canonical then call fail 'vector force dimension'

if failures=0 then do; say 'PASS test_maths_contract'; exit 0; end
say 'FAIL test_maths_contract failures='failures; exit 1

fail: procedure expose failures
  use arg label
  say 'FAIL:' label
  failures+=1
  return

::class ScaleOnlyVector
::method init
  expose vx vy vz
  use strict arg vx,vy,vz
::method x; expose vx; return vx
::method y; expose vy; return vy
::method z; expose vz; return vz
::method '*'
  expose vx vy vz
  use strict arg scalar
  return .ScaleOnlyVector~new(vx*scalar,vy*scalar,vz*scalar)

::requires '../rexx/Units.cls'
