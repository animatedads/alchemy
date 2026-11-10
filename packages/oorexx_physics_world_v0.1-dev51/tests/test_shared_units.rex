numeric digits 50
failures=0

/* Physics must consume shared Units authority, not a private dimension system. */
q=.Units~q(2,.Units~centimetre)
call checkNear q~in(.Units~metre),'0.02','shared Units conversion'
if q~dimension~canonical <> .Units~metre~dimension~canonical then call fail 'shared length dimension identity'

/* Physics has one unit authority: the shared Units package.  dev5 uses the
   supplied dev3 engineering-prefix catalogue; do not depend on a stale public
   development marker string. */
call checkNear .Units~q(1,.Units~gigahertz)~in(.Units~hertz),1000000000,'Units dev3 GHz catalogue'

/* Derived dimension is provable algebraically. */
m=.Units~q(2,.Units~kilogram)
a=.Units~q(3,.Units~metrePerSecondSquared)
f=m*a
call checkNear f~in(.Units~newton),6,'kg*m/s2 = N through shared Units'

/* Conversion evidence is replayable. */
proof=.Units~proof(1,.Units~inch,.Units~millimetre)
if \proof~verifies then call fail 'conversion proof verifies'
call checkNear proof~output,'25.4','proof output'

/* Real Maths v0.8 vector payloads follow the same provable scaling contract. */
v=.MathVector3~new(2,4,6,.Maths~defaultContext)
distance=.Units~q(v,.Units~metre)
time=.Units~q(2,.Units~second)
speed=distance/time
sv=speed~canonicalValue
call checkNear sv~x,1,'MathVector3 quantity x'
call checkNear sv~y,2,'MathVector3 quantity y'
call checkNear sv~z,3,'MathVector3 quantity z'
if \speed~dimension~compatible(.Units~metrePerSecond~dimension) then call fail 'MathVector3 speed dimension'

/* Equal SI dimension is not enough when Units defines a semantic family. */
signal on syntax name expectedFamilyFailure
bad=.Units~q(1,.Units~candela)~in(.Units~lumen)
signal off syntax
call fail 'candela -> lumen must fail family compatibility'
expectedFamilyFailure:
signal off syntax

if failures=0 then do
  say 'PHYSICS SHARED UNITS: OK'
  exit 0
end
say 'FAIL test_shared_units failures='failures
exit 1

checkNear: procedure expose failures
  use arg actual,expected,label
  if abs(actual-expected) > '0.0000000000000000000000000000000000000001' then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    failures+=1
  end
  return

fail: procedure expose failures
  use arg label
  say 'FAIL:' label
  failures+=1
  return

::requires 'PhysicsWorld.cls'
