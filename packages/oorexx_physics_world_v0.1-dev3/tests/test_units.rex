q=.PhysicsQuantity~new(2,.SI~centimetre)
call assertNear q~in(.SI~metre), 0.02, 1e-12, '2 cm in metres'
area=.PhysicsQuantity~new(1,.SI~centimetre)*.PhysicsQuantity~new(1,.SI~centimetre)
call assertNear area~siValue,0.0001,1e-12,'1 cm square area'
if (.SI~lux~dimension~canonical = .SI~candela~dimension~canonical) then do
  say 'FAIL lux dimension must include inverse square length'
  exit 1
end
say 'PHYSICS UNITS: OK'
exit 0
assertNear: procedure
  use strict arg actual,expected,tolerance,label
  if abs(actual-expected)>tolerance then do; say 'FAIL' label actual expected; exit 1; end
  return
::requires 'PhysicsWorld.cls'
