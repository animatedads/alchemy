numeric digits 50
q=.Units~q(2,.Units~centimetre)
call assertNear q~in(.Units~metre), 0.02, 1e-12, '2 cm in metres'
area=.Units~q(1,.Units~centimetre)*.Units~q(1,.Units~centimetre)
call assertNear area~siValue,0.0001,1e-12,'1 cm square area'
if (.Units~lux~dimension~canonical = .Units~candela~dimension~canonical) then do
  say 'FAIL lux dimension must include inverse square length'
  exit 1
end
/* dev5 consumes the supplied Units dev3 engineering catalogue rather than
   pinning the package's historical public version marker. */
call assertNear .Units~q(1,.Units~gigahertz)~in(.Units~hertz),1000000000,1e-9,'Units dev3 GHz catalogue'
say 'PHYSICS UNITS: OK'
exit 0
assertNear: procedure
  use strict arg actual,expected,tolerance,label
  if abs(actual-expected)>tolerance then do; say 'FAIL' label actual expected; exit 1; end
  return
::requires 'PhysicsWorld.cls'
