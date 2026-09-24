numeric digits 30
ctx=.Maths~defaultContext
medium=.FluidMedium~water20C
velocity=.MathVector3~new(2,-1,'0.5',ctx)
field=.UniformFluidField~new(medium,velocity,.Units~q(100,.Units~kilopascal))
integrator=.FluidPathlineIntegrator~new(field)
start=.MathVector3~new(0,0,0,ctx)
samples=integrator~trace(start,.Units~q('2.5',.Units~second),.Units~q('0.25',.Units~second))
if samples~items<>11 then do; say 'FAIL sample count' samples~items; exit 1; end
last=samples[samples~items]
call near last~position~x,5,'pathline x'
call near last~position~y,'-2.5','pathline y'
call near last~position~z,'1.25','pathline z'
call near last~time,'2.5','pathline time'
call near last~pressure,100000,'pathline pressure'
say 'PHYSICS FLUID PATHLINE: OK final='last~position
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'Fluids.cls'
