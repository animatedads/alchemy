numeric digits 30
ctx=.Maths~defaultContext
water=.FluidMedium~water20C
field=.RigidRotationFluidField~new( -
  water, -
  .MathVector3~new(0,0,0,ctx), -
  .MathVector3~new(0,0,10,ctx), -
  .Units~q(101325,.Units~pascal))
p=.MathVector3~new('0.1',0,0,ctx)
s=field~stateAt(p)
call near s~velocity~x,0,'rotating flow vx'
call near s~velocity~y,1,'rotating flow vy'
call near s~velocity~z,0,'rotating flow vz'
call near s~pressure,'101824.1','forced-vortex radial pressure','0.000001'
call near s~dynamicPressure, '499.1','local dynamic pressure','0.000001'
say 'PHYSICS FLUID RIGID ROTATION FIELD: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'Fluids.cls'
