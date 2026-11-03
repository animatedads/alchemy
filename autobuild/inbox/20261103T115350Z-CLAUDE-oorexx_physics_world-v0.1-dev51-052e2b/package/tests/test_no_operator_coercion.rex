/* dev50.1: assignment must not coerce through operator dispatch. */
world=.PhysicalWorld~new
trap=.PhysicsArithmeticTrap~new
world~simulationTime=trap
if world~simulationTime \== trap then do
  say 'FAIL: simulationTime assignment did not retain exact object'
  exit 1
end
if trap~plusMessages<>0 then do
  say 'FAIL: simulationTime assignment sent + merely to coerce'
  exit 1
end
say 'PHYSICS NO OPERATOR COERCION: OK'
exit 0

::class PhysicsArithmeticTrap public
::method init
  expose _plusMessages
  _plusMessages=0
::method plusMessages
  expose _plusMessages
  return _plusMessages
::method '+'
  expose _plusMessages
  use strict arg other
  _plusMessages=_plusMessages+1
  raise syntax 93.900 array('unexpected arithmetic coercion message',other)

::requires 'PhysicsWorld.cls'
